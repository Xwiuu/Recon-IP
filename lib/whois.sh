#!/bin/bash
# whois.sh - Consulta WHOIS para um IP

whois_lookup() {
    local ip=$1
    local pasta=$2
    local whois_file="${pasta}/whois.txt"

    log_info "Consultando WHOIS para $ip..."

    whois "$ip" > "$whois_file" 2>/dev/null

    if [ -s "$whois_file" ]; then
        log_success "WHOIS salvo em $whois_file"
    else
        log_warning "WHOIS vazio ou falha na consulta"
        echo "WHOIS: Indisponível" > "$whois_file"
    fi
}
