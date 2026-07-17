#!/bin/bash
# email_security.sh - Verifica SPF, DKIM, DMARC para dominios

check_email_security() {
    local dominio=$1
    local pasta=$2
    local email_file="${pasta}/email_security.txt"

    if [ -z "$dominio" ] || [ "$dominio" = "N/A" ]; then
        echo "Nenhum dominio informado." > "$email_file"
        return
    fi

    log_info "Verificando registros de seguranca de e-mail para $dominio..."

    echo "=== REGISTROS DE SEGURANCA DE E-MAIL ===" > "$email_file"

    if command -v dig &>/dev/null; then
        spf=$(dig +short TXT "$dominio" | grep -i "v=spf1" | head -1)
        if [ -n "$spf" ]; then
            echo "SPF: Presente ($spf)" >> "$email_file"
        else
            echo "SPF: Nao encontrado" >> "$email_file"
        fi

        dkim=$(dig +short TXT "default._domainkey.$dominio" 2>/dev/null)
        if [ -n "$dkim" ]; then
            echo "DKIM: Presente (default._domainkey)" >> "$email_file"
        else
            for selector in google _dmarc selector1 selector2; do
                dkim=$(dig +short TXT "${selector}._domainkey.$dominio" 2>/dev/null)
                if [ -n "$dkim" ]; then
                    echo "DKIM: Presente (${selector}._domainkey)" >> "$email_file"
                    break
                fi
            done
            if [ -z "$dkim" ]; then
                echo "DKIM: Nao encontrado" >> "$email_file"
            fi
        fi

        dmarc=$(dig +short TXT "_dmarc.$dominio" 2>/dev/null)
        if [ -n "$dmarc" ]; then
            echo "DMARC: Presente ($dmarc)" >> "$email_file"
        else
            echo "DMARC: Nao encontrado" >> "$email_file"
        fi
    else
        echo "Verificacao de e-mail: dig nao disponivel" >> "$email_file"
    fi

    log_success "Verificacao de e-mail concluida."
}
