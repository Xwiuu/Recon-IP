#!/bin/bash
# geo.sh - Geolocalização usando ipinfo.io com fallback ip-api.com

geo_lookup() {
    local ip=$1
    local pasta=$2
    local geo_file="${pasta}/geo.json"

    log_info "Buscando geolocalização para $ip via ipinfo.io..."

    curl -s "https://ipinfo.io/${ip}/json" -o "$geo_file"

    if [ ! -s "$geo_file" ]; then
        log_error "Falha no ipinfo.io. Tentando ip-api.com..."
        curl -s "http://ip-api.com/json/${ip}?fields=status,message,country,regionName,city,lat,lon,isp,org,timezone,as" -o "$geo_file"
        if [ ! -s "$geo_file" ]; then
            log_error "Falha completa na geolocalização."
            return 1
        fi
    fi

    LAT=$(jq -r '.loc | split(",")[0] // (.lat | tostring) // "N/A"' "$geo_file" 2>/dev/null)
    LON=$(jq -r '.loc | split(",")[1] // (.lon | tostring) // "N/A"' "$geo_file" 2>/dev/null)
    CITY=$(jq -r '.city // "N/A"' "$geo_file")
    REGION=$(jq -r '.region // .regionName // "N/A"' "$geo_file")
    COUNTRY=$(jq -r '.country // "N/A"' "$geo_file")
    ISP=$(jq -r '.org // .isp // "N/A"' "$geo_file")
    TIMEZONE=$(jq -r '.timezone // "N/A"' "$geo_file")
    HOSTNAME=$(jq -r '.hostname // "N/A"' "$geo_file")
    ASN=$(jq -r '.asn.name // .asn.asn // .as // "N/A"' "$geo_file")

    export LAT LON CITY REGION COUNTRY ISP TIMEZONE HOSTNAME ASN

    log_success "Geo: $CITY, $REGION - $COUNTRY ($LAT, $LON)"
    log_success "ISP: $ISP"
    return 0
}
