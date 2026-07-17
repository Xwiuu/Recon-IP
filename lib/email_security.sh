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

    EMAIL_SPF="N/A"
    EMAIL_DKIM="N/A"
    EMAIL_DMARC="N/A"
    EMAIL_SPOOFABLE="N/A"

    if command -v dig &>/dev/null; then
        local spf=$(dig +short TXT "$dominio" | grep -i "v=spf1" | head -1)
        if [ -n "$spf" ]; then
            echo "SPF: Presente ($spf)" >> "$email_file"
            EMAIL_SPF="$spf"
        else
            echo "SPF: Nao encontrado" >> "$email_file"
        fi

        local dkim=""
        dkim=$(dig +short TXT "default._domainkey.$dominio" 2>/dev/null)
        if [ -n "$dkim" ]; then
            echo "DKIM: Presente (default._domainkey)" >> "$email_file"
            EMAIL_DKIM="Presente (default._domainkey)"
        else
            for selector in google _dmarc selector1 selector2 selector3 mailout1 mailout2; do
                dkim=$(dig +short TXT "${selector}._domainkey.$dominio" 2>/dev/null)
                if [ -n "$dkim" ]; then
                    echo "DKIM: Presente (${selector}._domainkey)" >> "$email_file"
                    EMAIL_DKIM="Presente (${selector}._domainkey)"
                    break
                fi
            done
            if [ -z "$dkim" ]; then
                echo "DKIM: Nao encontrado" >> "$email_file"
                EMAIL_DKIM="Nao encontrado"
            fi
        fi

        local dmarc=$(dig +short TXT "_dmarc.$dominio" 2>/dev/null)
        if [ -n "$dmarc" ]; then
            echo "DMARC: Presente ($dmarc)" >> "$email_file"
            EMAIL_DMARC="$dmarc"
        else
            echo "DMARC: Nao encontrado" >> "$email_file"
        fi

        # --- ANALISE DE SPOOFING ---
        echo "" >> "$email_file"
        echo "--- ANALISE DE SPOOFING ---" >> "$email_file"

        local spoof_warnings=""

        if echo "$EMAIL_SPF" | grep -qiE '\?all|\+all'; then
            spoof_warnings+="[ALTO] SPF termina com ?all ou +all - permite spoofing! "
            echo "SPF: CONFIGURACAO FRACA (termina com ?all ou +all)" >> "$email_file"
        elif echo "$EMAIL_SPF" | grep -qi "\-all"; then
            echo "SPF: Configuracao forte (-all)" >> "$email_file"
        elif [ -n "$EMAIL_SPF" ] && [ "$EMAIL_SPF" != "N/A" ]; then
            echo "SPF: Configuracao neutra (sem all mechanism explicito)" >> "$email_file"
        fi

        if [ -n "$EMAIL_DMARC" ] && [ "$EMAIL_DMARC" != "N/A" ]; then
            if echo "$EMAIL_DMARC" | grep -qi "p=none"; then
                spoof_warnings+="[MEDIO] DMARC em p=none - apenas monitoramento, sem bloqueio. "
                echo "DMARC: Apenas monitoramento (p=none)" >> "$email_file"
            elif echo "$EMAIL_DMARC" | grep -qi "p=quarantine"; then
                echo "DMARC: Protecao moderada (p=quarantine)" >> "$email_file"
            elif echo "$EMAIL_DMARC" | grep -qi "p=reject"; then
                echo "DMARC: Protecao forte (p=reject)" >> "$email_file"
            fi

            local dmarc_pct=$(echo "$EMAIL_DMARC" | grep -oP 'pct=\K[0-9]+')
            if [ -n "$dmarc_pct" ] && [ "$dmarc_pct" -lt 100 ]; then
                spoof_warnings+="[INFO] DMARC com pct=$dmarc_pct - apenas ${dmarc_pct}% dos emails sao verificados. "
                echo "DMARC: Cobertura parcial (pct=${dmarc_pct}%)" >> "$email_file"
            fi
        fi

        if { [ -z "$EMAIL_SPF" ] || [ "$EMAIL_SPF" = "N/A" ]; } && { [ -z "$EMAIL_DMARC" ] || [ "$EMAIL_DMARC" = "N/A" ]; }; then
            spoof_warnings+="[CRITICO] Sem SPF e sem DMARC - dominio totalmente spoofavel! "
            echo "RESULTADO: Dominio TOTALMENTE SPOFAVEL" >> "$email_file"
        elif [ -z "$EMAIL_SPF" ] || [ "$EMAIL_SPF" = "N/A" ]; then
            spoof_warnings+="[ALTO] Sem SPF - emails podem ser forjados. "
            echo "RESULTADO: Sem SPF - risco de spoofing" >> "$email_file"
        fi

        if [ -n "$spoof_warnings" ]; then
            EMAIL_SPOOFABLE="ALERTA: $spoof_warnings"
            echo "STATUS: VULNERAVEL A SPOOFING" >> "$email_file"
            log_warning "SPOOFING: $EMAIL_SPOOFABLE"
        else
            EMAIL_SPOOFABLE="Configuracao segura"
            echo "STATUS: Configuracao parece segura" >> "$email_file"
            log_success "Email security: configuracao parece segura"
        fi
    else
        echo "Verificacao de e-mail: dig nao disponivel" >> "$email_file"
    fi

    export EMAIL_SPF EMAIL_DKIM EMAIL_DMARC EMAIL_SPOOFABLE
    log_success "Verificacao de e-mail concluida."
}
