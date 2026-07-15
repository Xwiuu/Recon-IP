#!/bin/bash
# geo.sh - Geolocalização via ip-api.com

geo_lookup() {
    local ip=$1
    local pasta=$2
    local geo_file="${pasta}/geo.json"

    log_info "Buscando geolocalização para $ip..."

    curl -s "http://ip-api.com/json/${ip}?fields=status,message,country,regionName,city,lat,lon,isp,org,timezone,as" -o "$geo_file"

    local status=$(jq -r '.status' "$geo_file" 2>/dev/null)
    if [ "$status" != "success" ]; then
        log_error "Falha no ip-api.com. Tentando fallback ipinfo.io..."
        curl -s "https://ipinfo.io/${ip}/json" -o "$geo_file"
        if [ ! -s "$geo_file" ]; then
            log_error "Falha completa na geolocalização."
            return 1
        fi
    fi

    LAT=$(jq -r '(.lat | tostring) // (.loc | split(",")[0])' "$geo_file" 2>/dev/null)
    LON=$(jq -r '(.lon | tostring) // (.loc | split(",")[1])' "$geo_file" 2>/dev/null)
    CITY=$(jq -r '.city // "N/A"' "$geo_file")
    REGION=$(jq -r '.regionName // .region // "N/A"' "$geo_file")
    COUNTRY=$(jq -r '.country // "N/A"' "$geo_file")
    ISP=$(jq -r '.isp // .org // "N/A"' "$geo_file")
    TIMEZONE=$(jq -r '.timezone // "N/A"' "$geo_file")

    log_success "Geo: $CITY, $REGION - $COUNTRY ($LAT, $LON)"
    log_success "ISP: $ISP"

    export LAT LON CITY REGION COUNTRY ISP TIMEZONE
    return 0
}
