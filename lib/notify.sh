#!/bin/bash
# notify.sh - Notificações via Telegram e Discord

# ========== TELEGRAM ==========

notify_telegram() {
    local ip=$1
    local pasta=$2
    local token="${TELEGRAM_BOT_TOKEN:-}"
    local chat_id="${TELEGRAM_CHAT_ID:-}"

    if [ -z "$token" ] || [ -z "$chat_id" ] || [ "$token" = "SEU_TOKEN_AQUI" ]; then
        log_warning "Telegram nao configurado. Pule notificacao."
        return 1
    fi

    log_info "Enviando notificacao via Telegram..."

    local caption=$(cat <<EOF
🕵️ SUPERRECON v2.0 — Novo Alvo Capturado!

🌐 IP: ${ip}
📍 Localizacao: ${CITY:-N/A}, ${REGION:-N/A} — ${COUNTRY:-N/A}
📡 ISP: ${ISP:-N/A}
🌤️ Clima: ${CLIMA:-N/A}
🗺️ Coordenadas: ${LAT:-N/A}, ${LON:-N/A}

🔗 Abrir no Google Maps: ${LINK_MAPS_NAV:-#}
🔗 Street View 360°: ${LINK_STREET:-#}

📅 Scan realizado em $(formatar_data)
EOF
)

    local street_file="${pasta}/street.jpg"

    if [ -f "$street_file" ] && [ -s "$street_file" ] && [ "$(file -b --mime-type "$street_file" 2>/dev/null)" != "text/plain" ]; then
        curl -s -X POST "https://api.telegram.org/bot${token}/sendPhoto" \
            -F "chat_id=${chat_id}" \
            -F "photo=@${street_file}" \
            -F "caption=${caption}" \
            -F "parse_mode=Markdown" &> /dev/null
    else
        curl -s -X POST "https://api.telegram.org/bot${token}/sendMessage" \
            -d "chat_id=${chat_id}" \
            -d "text=${caption}" \
            -d "parse_mode=Markdown" &> /dev/null
    fi

    if [ $? -eq 0 ]; then
        log_success "Notificacao enviada para Telegram!"
    else
        log_error "Falha ao enviar notificacao Telegram."
    fi
}

# ========== DISCORD ==========

notify_discord() {
    local ip=$1
    local pasta=$2
    local webhook_url="${DISCORD_WEBHOOK_URL:-}"

    if [ -z "$webhook_url" ] || [ "$webhook_url" = "SEU_WEBHOOK_AQUI" ]; then
        log_warning "Discord nao configurado. Pule notificacao."
        return 1
    fi

    log_info "Enviando notificacao via Discord..."

    local embed=$(cat <<EOF
{
    "embeds": [{
        "title": "🕵️ SUPERRECON v2.0 — Novo Alvo Capturado!",
        "color": 5793266,
        "fields": [
            {"name": "🌐 IP", "value": "${ip}", "inline": true},
            {"name": "📍 Localizacao", "value": "${CITY:-N/A}, ${REGION:-N/A} — ${COUNTRY:-N/A}", "inline": true},
            {"name": "📡 ISP", "value": "${ISP:-N/A}", "inline": false},
            {"name": "🌤️ Clima", "value": "${CLIMA:-N/A}", "inline": true},
            {"name": "🗺️ Coordenadas", "value": "${LAT:-N/A}, ${LON:-N/A}", "inline": true},
            {"name": "🔗 Links", "value": "[Google Maps](${LINK_MAPS_NAV:-#}) | [Street View](${LINK_STREET:-#})", "inline": false}
        ],
        "footer": {"text": "Scan realizado em $(formatar_data)"}
    }]
}
EOF
)

    local street_file="${pasta}/street.jpg"
    if [ -f "$street_file" ] && [ -s "$street_file" ] && [ "$(file -b --mime-type "$street_file" 2>/dev/null)" != "text/plain" ]; then
        curl -s -X POST "$webhook_url" \
            -F "payload_json=${embed}" \
            -F "file=@${street_file}" &> /dev/null
    else
        curl -s -X POST "$webhook_url" \
            -H "Content-Type: application/json" \
            -d "$embed" &> /dev/null
    fi

    if [ $? -eq 0 ]; then
        log_success "Notificacao enviada para Discord!"
    else
        log_error "Falha ao enviar notificacao Discord."
    fi
}

# ========== FUNCAO PRINCIPAL ==========

send_notifications() {
    local ip=$1
    local pasta=$2

    notify_telegram "$ip" "$pasta"
    notify_discord "$ip" "$pasta"
}
