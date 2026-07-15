#!/bin/bash
# weather.sh - Previsão do tempo usando wttr.in

get_weather() {
    local lat=$1
    local lon=$2
    local pasta=$3
    local weather_file="${pasta}/weather.txt"

    if [ -z "$lat" ] || [ -z "$lon" ] || [ "$lat" = "null" ] || [ "$lon" = "null" ]; then
        log_error "Coordenadas inválidas para clima."
        echo "Clima: Indisponível" > "$weather_file"
        CLIMA="N/A"
        export CLIMA
        return 1
    fi

    log_info "Buscando clima para coordenadas ${lat},${lon}..."

    curl -s "wttr.in/${lat},${lon}?format=%t+%w+%m" -o "$weather_file" 2>/dev/null

    if [ ! -s "$weather_file" ]; then
        if [ -n "$CITY" ] && [ "$CITY" != "N/A" ]; then
            curl -s "wttr.in/${CITY}?format=%t+%w+%m" -o "$weather_file" 2>/dev/null
        fi
    fi

    if [ ! -s "$weather_file" ]; then
        echo "Clima: Indisponível" > "$weather_file"
        CLIMA="N/A"
    else
        CLIMA=$(cat "$weather_file")
    fi

    export CLIMA
    log_success "Clima: $CLIMA"
    return 0
}
