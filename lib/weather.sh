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

    log_info "Buscando clima (3 dias) para coordenadas ${lat},${lon}..."

    # ---- 1. TENTA wttr.in POR COORDENADAS (JSON) ----
    if tem_internet; then
        local json_data
        json_data=$(curl -s -m 8 "wttr.in/${lat},${lon}?format=j1" 2>/dev/null)

        if [ -n "$json_data" ] && echo "$json_data" | jq -e '.current_condition[0]' &>/dev/null; then
            echo "$json_data" > "${pasta}/weather_raw.json"

            local temp_now wind_now desc_now humidity_now
            temp_now=$(echo "$json_data" | jq -r '.current_condition[0].temp_C // "N/A"')
            wind_now=$(echo "$json_data" | jq -r '.current_condition[0].windspeedKmph // "N/A"')
            desc_now=$(echo "$json_data" | jq -r '.current_condition[0].weatherDesc[0].value // "N/A"')
            humidity_now=$(echo "$json_data" | jq -r '.current_condition[0].humidity // "N/A"')

            CLIMA="${temp_now}°C ${desc_now} Vento:${wind_now}km/h Umidade:${humidity_now}%"

            CLIMA_DIA1="N/A"
            CLIMA_DIA2="N/A"
            CLIMA_DIA3="N/A"

            for i in 0 1 2; do
                local date max min desc_cond
                date=$(echo "$json_data" | jq -r ".weather[$i].date // \"N/A\"" 2>/dev/null)
                max=$(echo "$json_data" | jq -r ".weather[$i].maxtempC // \"N/A\"" 2>/dev/null)
                min=$(echo "$json_data" | jq -r ".weather[$i].mintempC // \"N/A\"" 2>/dev/null)
                desc_cond=$(echo "$json_data" | jq -r ".weather[$i].hourly[0].weatherDesc[0].value // \"N/A\"" 2>/dev/null)

                local day_label="Dia $((i+1))"
                [ "$i" -eq 0 ] && day_label="Hoje"
                [ "$i" -eq 1 ] && day_label="Amanha"
                local day_text="${day_label} (${date}): ${min}°C~${max}°C ${desc_cond}"

                case $i in
                    0) CLIMA_DIA1="$day_text" ;;
                    1) CLIMA_DIA2="$day_text" ;;
                    2) CLIMA_DIA3="$day_text" ;;
                esac
            done

            export CLIMA CLIMA_DIA1 CLIMA_DIA2 CLIMA_DIA3

            cat > "$weather_file" <<EOF
Clima Atual: ${CLIMA}
---
${CLIMA_DIA1}
${CLIMA_DIA2}
${CLIMA_DIA3}
EOF

            log_success "Clima atual: $CLIMA"
            log_success "Previsao: $CLIMA_DIA1 | $CLIMA_DIA2 | $CLIMA_DIA3"
            return 0
        fi

        # ---- 2. FALLBACK: formato simples (se JSON falhar) ----
        if curl -s -m 5 "wttr.in/${lat},${lon}?format=%t+%w+%m" -o "$weather_file" 2>/dev/null && [ -s "$weather_file" ]; then
            CLIMA=$(cat "$weather_file")
            CLIMA_DIA1="N/A"
            CLIMA_DIA2="N/A"
            CLIMA_DIA3="N/A"
            export CLIMA CLIMA_DIA1 CLIMA_DIA2 CLIMA_DIA3
            log_success "Clima (fallback): $CLIMA"
            return 0
        fi

        # ---- 3. FALLBACK: wttr.in POR CIDADE ----
        parse_forecast() {
            local data=$1
            CLIMA_DIA1="N/A"; CLIMA_DIA2="N/A"; CLIMA_DIA3="N/A"
            for i in 0 1 2; do
                local date max min desc_cond
                date=$(echo "$data" | jq -r ".weather[$i].date // \"N/A\"" 2>/dev/null)
                max=$(echo "$data" | jq -r ".weather[$i].maxtempC // \"N/A\"" 2>/dev/null)
                min=$(echo "$data" | jq -r ".weather[$i].mintempC // \"N/A\"" 2>/dev/null)
                desc_cond=$(echo "$data" | jq -r ".weather[$i].hourly[0].weatherDesc[0].value // \"N/A\"" 2>/dev/null)
                local day_label="Dia $((i+1))"
                [ "$i" -eq 0 ] && day_label="Hoje"
                [ "$i" -eq 1 ] && day_label="Amanha"
                local day_text="${day_label} (${date}): ${min}°C~${max}°C ${desc_cond}"
                case $i in
                    0) CLIMA_DIA1="$day_text" ;;
                    1) CLIMA_DIA2="$day_text" ;;
                    2) CLIMA_DIA3="$day_text" ;;
                esac
            done
        }

        if [ -n "$CITY" ] && [ "$CITY" != "N/A" ] && [ "$CITY" != "null" ]; then
            log_warning "Clima por coordenadas falhou. Tentando por cidade ${CITY}..."
            local city_data
            city_data=$(curl -s -m 8 "wttr.in/${CITY}?format=j1" 2>/dev/null)
            if [ -n "$city_data" ] && echo "$city_data" | jq -e '.current_condition[0]' &>/dev/null; then
                echo "$city_data" > "${pasta}/weather_raw.json"
                local t c w h
                t=$(echo "$city_data" | jq -r '.current_condition[0].temp_C // "N/A"')
                c=$(echo "$city_data" | jq -r '.current_condition[0].weatherDesc[0].value // "N/A"')
                w=$(echo "$city_data" | jq -r '.current_condition[0].windspeedKmph // "N/A"')
                h=$(echo "$city_data" | jq -r '.current_condition[0].humidity // "N/A"')
                CLIMA="${t}°C ${c} Vento:${w}km/h Umidade:${h}%"
                parse_forecast "$city_data"
                export CLIMA CLIMA_DIA1 CLIMA_DIA2 CLIMA_DIA3
                cat > "$weather_file" <<EOF
Clima Atual: ${CLIMA}
---
${CLIMA_DIA1}
${CLIMA_DIA2}
${CLIMA_DIA3}
EOF
                log_success "Clima (cidade): $CLIMA"
                log_success "Previsao: $CLIMA_DIA1 | $CLIMA_DIA2 | $CLIMA_DIA3"
                return 0
            fi
        fi

        # ---- 4. FALLBACK 2: por país + região ----
        if [ -n "$REGION" ] && [ -n "$COUNTRY" ]; then
            local city_encoded=$(echo "$CITY" | sed 's/ /+/g')
            local region_data
            region_data=$(curl -s -m 8 "wttr.in/${city_encoded},${COUNTRY}?format=j1" 2>/dev/null)
            if [ -n "$region_data" ] && echo "$region_data" | jq -e '.current_condition[0]' &>/dev/null; then
                echo "$region_data" > "${pasta}/weather_raw.json"
                local t c w h
                t=$(echo "$region_data" | jq -r '.current_condition[0].temp_C // "N/A"')
                c=$(echo "$region_data" | jq -r '.current_condition[0].weatherDesc[0].value // "N/A"')
                w=$(echo "$region_data" | jq -r '.current_condition[0].windspeedKmph // "N/A"')
                h=$(echo "$region_data" | jq -r '.current_condition[0].humidity // "N/A"')
                CLIMA="${t}°C ${c} Vento:${w}km/h Umidade:${h}%"
                parse_forecast "$region_data"
                export CLIMA CLIMA_DIA1 CLIMA_DIA2 CLIMA_DIA3
                cat > "$weather_file" <<EOF
Clima Atual: ${CLIMA}
---
${CLIMA_DIA1}
${CLIMA_DIA2}
${CLIMA_DIA3}
EOF
                log_success "Clima (região): $CLIMA"
                log_success "Previsao: $CLIMA_DIA1 | $CLIMA_DIA2 | $CLIMA_DIA3"
                return 0
            fi
        fi
    else
        log_warning "Sem internet. Clima indisponivel."
    fi

    # ---- 5. FALHA TOTAL ----
    echo "Clima: N/A (API indisponivel)" > "$weather_file"
    CLIMA="N/A"; CLIMA_DIA1="N/A"; CLIMA_DIA2="N/A"; CLIMA_DIA3="N/A"
    export CLIMA CLIMA_DIA1 CLIMA_DIA2 CLIMA_DIA3
    log_warning "Clima indisponivel."
    return 1
}
