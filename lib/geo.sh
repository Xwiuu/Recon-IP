#!/bin/bash
# geo.sh - Geolocalizacao com fallback: ipinfo.io -> ip-api.com -> geoiplookup -> N/A

_extrair_geo() {
    local file=$1
    LAT=$(jq -r '.loc | split(",")[0] // (.lat | tostring) // "N/A"' "$file" 2>/dev/null)
    LON=$(jq -r '.loc | split(",")[1] // (.lon | tostring) // "N/A"' "$file" 2>/dev/null)
    CITY=$(jq -r '.city // "N/A"' "$file" 2>/dev/null)
    REGION=$(jq -r '.region // .regionName // "N/A"' "$file" 2>/dev/null)
    COUNTRY=$(jq -r '.country // "N/A"' "$file" 2>/dev/null)
    ISP=$(jq -r '.org // .isp // "N/A"' "$file" 2>/dev/null)
    TIMEZONE=$(jq -r '.timezone // "N/A"' "$file" 2>/dev/null)
    HOSTNAME=$(jq -r '.hostname // "N/A"' "$file" 2>/dev/null)
    ASN=$(jq -r '.asn.name // .asn.asn // .as // "N/A"' "$file" 2>/dev/null)
    export LAT LON CITY REGION COUNTRY ISP TIMEZONE HOSTNAME ASN
}

geo_lookup() {
    local ip=$1
    local pasta=$2
    local geo_file="${pasta}/geo.json"

    log_info "Buscando geolocalizacao para $ip..."

    # ---- 1. TENTA ONLINE: ipinfo.io ----
    if curl -s -m 5 "https://ipinfo.io/${ip}/json" -o "$geo_file" 2>/dev/null; then
        if [ -s "$geo_file" ] && [ "$(jq -r '.status // .bogon // "ok"' "$geo_file" 2>/dev/null)" != "error" ]; then
            log_success "Geo obtida via ipinfo.io."
            _extrair_geo "$geo_file"
            return 0
        fi
    fi

    # ---- 2. FALLBACK ONLINE: ip-api.com (sem chave, 45 req/min) ----
    log_warning "ipinfo.io falhou. Tentando ip-api.com..."
    if curl -s -m 5 "http://ip-api.com/json/${ip}?fields=status,message,country,regionName,city,lat,lon,isp,org,timezone,as" -o "$geo_file" 2>/dev/null; then
        if [ -s "$geo_file" ] && [ "$(jq -r '.status' "$geo_file" 2>/dev/null)" = "success" ]; then
            log_success "Geo obtida via ip-api.com."
            _extrair_geo "$geo_file"
            return 0
        fi
    fi

    # ---- 3. FALLBACK LOCAL: geoiplookup (pacote geoip-bin) ----
    log_warning "APIs online falharam. Tentando fallback local (geoiplookup)..."
    if command -v geoiplookup &>/dev/null; then
        local geo_local
        geo_local=$(geoiplookup "$ip" 2>/dev/null)
        if [ -n "$geo_local" ] && ! echo "$geo_local" | grep -qiE "cannot find|not found|IP Address not found"; then
            local pais cidade regiao lat lon
            pais=$(echo "$geo_local" | grep -oE ', [A-Z]{2},' | head -1 | sed 's/, //g')
            regiao=$(echo "$geo_local" | cut -d',' -f3 | xargs)
            cidade=$(echo "$geo_local" | cut -d',' -f4 | xargs)
            lat=$(echo "$geo_local" | grep -oE '[-0-9.]+,' | head -1 | tr -d ',')
            lon=$(echo "$geo_local" | grep -oE ', [-0-9.]+' | head -1 | tr -d ', ')

            export CITY="${cidade:-N/A}" REGION="${regiao:-N/A}" COUNTRY="${pais:-N/A}"
            export LAT="${lat:-N/A}" LON="${lon:-N/A}"
            export ISP="N/A" TIMEZONE="N/A" HOSTNAME="N/A"

            jq -n --arg ip "$ip" --arg city "$CITY" --arg region "$REGION" --arg country "$COUNTRY" --arg lat "$LAT" --arg lon "$LON" \
                '{ip: $ip, city: $city, region: $region, country: $country, loc: ($lat+","+$lon)}' > "$geo_file" 2>/dev/null

            log_success "Geo obtida via geoiplookup (local)."
            return 0
        fi
    fi

    # ---- 4. FALHA TOTAL ----
    log_error "Todas as fontes de geolocalizacao falharam."
    export CITY="N/A" REGION="N/A" COUNTRY="N/A" LAT="N/A" LON="N/A"
    export ISP="N/A" TIMEZONE="N/A" HOSTNAME="N/A" ASN="N/A"
    echo '{"ip": "'$ip'", "error": "Indisponivel"}' > "$geo_file"
    return 1
}
