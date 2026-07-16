#!/bin/bash
# weather.sh - Previsao do tempo com fallback: wttr.in -> N/A

get_weather() {
    local lat=$1
    local lon=$2
    local pasta=$3
    local weather_file="${pasta}/weather.txt"

    CLIMA="N/A"

    if [ -z "$lat" ] || [ -z "$lon" ] || [ "$lat" = "null" ] || [ "$lon" = "null" ] || [ "$lat" = "N/A" ]; then
        log_warning "Coordenadas invalidas. Clima indisponivel."
        echo "Clima: Indisponivel (sem coordenadas)" > "$weather_file"
        export CLIMA
        return 1
    fi

    log_info "Buscando clima para coordenadas ${lat},${lon}..."

    # ---- 1. TENTA wttr.in POR COORDENADAS ----
    if tem_internet; then
        if curl -s -m 5 "wttr.in/${lat},${lon}?format=%t+%w+%m" -o "$weather_file" 2>/dev/null && [ -s "$weather_file" ]; then
            CLIMA=$(cat "$weather_file")
            log_success "Clima: $CLIMA"
            export CLIMA
            return 0
        fi

        # ---- 2. FALLBACK: wttr.in POR CIDADE ----
        if [ -n "$CITY" ] && [ "$CITY" != "N/A" ] && [ "$CITY" != "null" ]; then
            log_warning "Clima por coordenadas falhou. Tentando por cidade ${CITY}..."
            if curl -s -m 5 "wttr.in/${CITY}?format=%t+%w+%m" -o "$weather_file" 2>/dev/null && [ -s "$weather_file" ]; then
                CLIMA=$(cat "$weather_file")
                log_success "Clima: $CLIMA"
                export CLIMA
                return 0
            fi
        fi
    else
        log_warning "Sem internet. Clima indisponivel."
    fi

    # ---- 3. FALHA TOTAL ----
    echo "Clima: N/A (API indisponivel)" > "$weather_file"
    export CLIMA
    log_warning "Clima indisponivel."
    return 1
}
