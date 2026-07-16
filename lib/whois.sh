#!/bin/bash
# whois.sh - Consulta WHOIS com fallback: local -> API -> N/A

whois_lookup() {
    local ip=$1
    local pasta=$2
    local whois_file="${pasta}/whois.txt"

    log_info "Consultando WHOIS para $ip..."

    # ---- 1. COMANDO LOCAL (whois) ----
    if command -v whois &>/dev/null; then
        if whois "$ip" > "$whois_file" 2>/dev/null && [ -s "$whois_file" ]; then
            log_success "WHOIS obtido via comando local."
            return 0
        fi
        log_warning "WHOIS local falhou (sem dados)."
    else
        log_warning "Comando whois nao encontrado."
    fi

    # ---- 2. FALLBACK API (ipwhois.app) ----
    if tem_internet; then
        log_warning "Tentando WHOIS via API..."
        local api_file="${pasta}/whois_api.json"
        if curl -s -m 5 "https://ipwhois.app/json/${ip}" -o "$api_file" 2>/dev/null && [ -s "$api_file" ]; then
            if [ "$(jq -r '.success // "false"' "$api_file" 2>/dev/null)" = "true" ]; then
                echo "WHOIS via API (ipwhois.app):" > "$whois_file"
                jq -r '. | to_entries | .[] | "\(.key): \(.value)"' "$api_file" >> "$whois_file" 2>/dev/null
                log_success "WHOIS via API obtido."
                return 0
            fi
        fi
    else
        log_warning "Sem internet. Pulando fallback API."
    fi

    # ---- 3. FALHA TOTAL ----
    echo "WHOIS: Indisponivel (local e API)" > "$whois_file"
    log_error "WHOIS nao disponivel."
    return 1
}
