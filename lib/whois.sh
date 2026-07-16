#!/bin/bash
# whois.sh - Consulta WHOIS

whois_lookup() {
    local ip=$1
    local pasta=$2
    local whois_file="${pasta}/whois.txt"

    log_info "Consultando WHOIS para $ip..."

    if command -v whois &>/dev/null; then
        whois "$ip" > "$whois_file" 2>/dev/null
        if [ -s "$whois_file" ]; then
            log_success "WHOIS obtido com sucesso!"
            return 0
        fi
    fi

    # Fallback: API whois
    log_warning "WHOIS local nao disponivel. Tentando API..."
    local api_file="${pasta}/whois_api.json"
    curl -s "https://ipwhois.app/json/${ip}" -o "$api_file" 2>/dev/null
    if [ -s "$api_file" ]; then
        echo "WHOIS via API (ipwhois.app):" > "$whois_file"
        jq -r '. | to_entries | .[] | "\(.key): \(.value)"' "$api_file" >> "$whois_file" 2>/dev/null
        log_success "WHOIS via API obtido."
        return 0
    fi

    echo "WHOIS: Indisponivel" > "$whois_file"
    log_warning "WHOIS nao disponivel."
    return 1
}
