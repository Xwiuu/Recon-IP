#!/bin/bash
# pwned.sh - Verificacao de vazamento de dados via Have I Been Pwned

check_pwned() {
    local email=$1
    local pasta=$2
    local pwned_file="${pasta}/pwned.txt"

    PWNED_COUNT=0
    PWNED_BREACHES="N/A"

    if [ -z "$email" ] || [ "$email" = "N/A" ] || [ "$email" = "null" ]; then
        log_debug "Email invalido ou inexistente. Pulando HIBP."
        echo "Have I Been Pwned: N/A (email nao disponivel)" > "$pwned_file"
        export PWNED_COUNT PWNED_BREACHES
        return 1
    fi

    log_info "Verificando vazamentos para ${email}..."

    if ! tem_internet; then
        log_warning "Sem internet. HIBP indisponivel."
        echo "Have I Been Pwned: N/A (sem internet)" > "$pwned_file"
        export PWNED_COUNT PWNED_BREACHES
        return 1
    fi

    local email_encoded
    email_encoded=$(printf '%s' "$email" | jq -sRr @uri)

    if [ -n "${HIBP_API_KEY:-}" ]; then
        local response
        response=$(curl -s -m 10 \
            -H "hibp-api-key: ${HIBP_API_KEY}" \
            -H "user-agent: ReconIP-v2.0" \
            "https://haveibeenpwned.com/api/v3/breachedaccount/${email_encoded}?truncateResponse=true" 2>/dev/null)

        local http_code
        http_code=$(curl -s -o /dev/null -w "%{http_code}" \
            -H "hibp-api-key: ${HIBP_API_KEY}" \
            -H "user-agent: ReconIP-v2.0" \
            "https://haveibeenpwned.com/api/v3/breachedaccount/${email_encoded}?truncateResponse=true" 2>/dev/null)

        if [ "$http_code" = "404" ]; then
            log_success "Nenhum vazamento encontrado para ${email}"
            echo "Email: ${email}" > "$pwned_file"
            echo "Vazamentos: Nenhum encontrado" >> "$pwned_file"
            PWNED_COUNT=0
            PWNED_BREACHES="Nenhum"
            export PWNED_COUNT PWNED_BREACHES
            return 0
        elif [ "$http_code" = "200" ] && [ -n "$response" ]; then
            local count
            count=$(echo "$response" | jq length 2>/dev/null)
            local names
            names=$(echo "$response" | jq -r '.[].Name' 2>/dev/null | paste -sd ', ' -)

            PWNED_COUNT=${count:-0}
            PWNED_BREACHES="${names:-N/A}"

            echo "$response" > "${pasta}/pwned_response.json"

            cat > "$pwned_file" <<EOF
Email: ${email}
Vazamentos Encontrados: ${PWNED_COUNT}

=== BREACHES ===
$(echo "$response" | jq -r '.[] | "  - \(.Name) (\(.Domain)) - \(.BreachDate) - \(.PwnCount) contas"' 2>/dev/null | head -30)
EOF

            log_success "${PWNED_COUNT} vazamento(s) encontrado(s) para ${email}!"
            export PWNED_COUNT PWNED_BREACHES
            return 0
        else
            log_warning "HIBP retornou HTTP ${http_code}. Pode ser rate-limit ou erro."
            echo "Have I Been Pwned: HTTP ${http_code}" > "$pwned_file"
            export PWNED_COUNT PWNED_BREACHES
            return 1
        fi
    else
        log_warning "HIBP_API_KEY nao configurada. Pulando verificacao de vazamentos."
        echo "Have I Been Pwned: N/A (chave nao configurada)" > "$pwned_file"
        export PWNED_COUNT PWNED_BREACHES
        return 1
    fi
}
