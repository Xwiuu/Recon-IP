#!/bin/bash
# social_osint.sh - Coleta emails, telefones e redes sociais

extract_contacts() {
    local dominio=$1
    local ip=$2
    local pasta=$3
    local contact_file="${pasta}/contacts.txt"

    log_info "Extraindo contatos (emails/telefones) do site..."

    if grep -q "80/tcp.*ABERTA" "${pasta}/portas.txt" 2>/dev/null; then
        curl -s -L "http://${dominio:-$ip}" -m 5 > "${pasta}/homepage.html" 2>/dev/null
        curl -s -L "https://${dominio:-$ip}" -m 5 >> "${pasta}/homepage.html" 2>/dev/null
    fi

    echo "=== CONTATOS ===" > "$contact_file"

    if [ -f "${pasta}/homepage.html" ]; then
        emails=$(grep -Eo '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' "${pasta}/homepage.html" | sort -u)
        if [ -n "$emails" ]; then
            echo "Emails encontrados no site:" >> "$contact_file"
            echo "$emails" | sed 's/^/  - /' >> "$contact_file"
        fi
    fi

    if [ -f "${pasta}/homepage.html" ]; then
        phones=$(grep -Eo '\([0-9]{2}\)\s?[0-9]{4,5}-[0-9]{4}' "${pasta}/homepage.html" | sort -u)
        phones_international=$(grep -Eo '\+[0-9]{1,3}\s?[0-9]{4,}[0-9]' "${pasta}/homepage.html" | sort -u)

        if [ -n "$phones" ] || [ -n "$phones_international" ]; then
            echo "Telefones encontrados:" >> "$contact_file"
            [ -n "$phones" ] && echo "$phones" | sed 's/^/  - /' >> "$contact_file"
            [ -n "$phones_international" ] && echo "$phones_international" | sed 's/^/  - /' >> "$contact_file"
        fi
    fi

    if [ -f "${pasta}/whois_domain.txt" ] && [ -s "${pasta}/whois_domain.txt" ]; then
        echo "Contatos do WHOIS:" >> "$contact_file"
        grep -iE 'Registrant Email|Admin Email|Tech Email|Registrant Phone|Admin Phone' "${pasta}/whois_domain.txt" | head -5 | sed 's/^/  - /' >> "$contact_file"
    fi

    if [ -f "${pasta}/whois_api.json" ] && [ -s "${pasta}/whois_api.json" ]; then
        email_whois_api=$(jq -r '.email // .registrant_email // empty' "${pasta}/whois_api.json" 2>/dev/null)
        phone_whois_api=$(jq -r '.phone // .registrant_phone // empty' "${pasta}/whois_api.json" 2>/dev/null)
        if [ -n "$email_whois_api" ] || [ -n "$phone_whois_api" ]; then
            echo "Contatos via WHOIS API:" >> "$contact_file"
            [ -n "$email_whois_api" ] && echo "  - Email: $email_whois_api" >> "$contact_file"
            [ -n "$phone_whois_api" ] && echo "  - Telefone: $phone_whois_api" >> "$contact_file"
        fi
    fi

    if [ ! -s "$contact_file" ] || [ "$(wc -l < "$contact_file")" -le 1 ]; then
        echo "Nenhum contato encontrado." > "$contact_file"
    fi

    log_success "Extracao de contatos concluida."
}

extract_social() {
    local dominio=$1
    local pasta=$2
    local social_file="${pasta}/social.txt"

    log_info "Verificando redes sociais para $dominio..."

    echo "=== REDES SOCIAIS ===" > "$social_file"

    found=0
    for entry in "Facebook|https://facebook.com/${dominio}" "Instagram|https://instagram.com/${dominio}" "LinkedIn|https://linkedin.com/company/${dominio}" "Twitter|https://twitter.com/${dominio}" "YouTube|https://youtube.com/@${dominio}" "GitHub|https://github.com/${dominio}" "Pinterest|https://pinterest.com/${dominio}" "TikTok|https://tiktok.com/@${dominio}" "Reddit|https://reddit.com/user/${dominio}"; do
        name="${entry%%|*}"
        url="${entry#*|}"
        status=$(curl -s -o /dev/null -L -m 2 -w "%{http_code}" "$url" 2>/dev/null)
        if [ "$status" != "404" ] && [ "$status" != "000" ] && [ -n "$status" ]; then
            echo "$name: $url" >> "$social_file"
            found=1
        fi
    done

    if [ $found -eq 0 ]; then
        echo "Nenhuma rede social encontrada (ou perfis privados/inexistentes)." >> "$social_file"
    fi

    log_success "Verificacao de redes sociais concluida."
}

run_harvester() {
    local dominio=$1
    local pasta=$2
    local harvester_file="${pasta}/harvester.txt"

    HARVESTER_EMAILS="N/A"
    HARVESTER_SUBDOMAINS="N/A"

    if [ -z "$dominio" ] || [ "$dominio" = "N/A" ]; then
        log_debug "Sem dominio. Pulando theHarvester."
        echo "theHarvester: N/A (sem dominio)" > "$harvester_file"
        export HARVESTER_EMAILS HARVESTER_SUBDOMAINS
        return
    fi

    if ! command -v theHarvester &>/dev/null; then
        log_info "theHarvester nao instalado. Pulando (opcional)."
        echo "theHarvester: N/A (nao instalado)" > "$harvester_file"
        export HARVESTER_EMAILS HARVESTER_SUBDOMAINS
        return
    fi

    log_info "Executando theHarvester para ${dominio}..."
    log_warning "Isso pode levar alguns minutos..."

    if theHarvester -d "$dominio" -b all -f "${pasta}/harvester_output" 2>/dev/null; then
        if [ -f "${pasta}/harvester_output.json" ]; then
            local emails subdomains
            emails=$(jq -r '.emails[] // empty' "${pasta}/harvester_output.json" 2>/dev/null | paste -sd ', ' -)
            subdomains=$(jq -r '.hosts[] // empty' "${pasta}/harvester_output.json" 2>/dev/null | paste -sd ', ' -)

            HARVESTER_EMAILS="${emails:-N/A}"
            HARVESTER_SUBDOMAINS="${subdomains:-N/A}"

            export HARVESTER_EMAILS HARVESTER_SUBDOMAINS
        else
            local raw_file
            raw_file=$(ls "${pasta}/harvester_output"* 2>/dev/null | head -1)
            if [ -n "$raw_file" ] && [ -f "$raw_file" ]; then
                HARVESTER_EMAILS=$(grep -oE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' "$raw_file" | sort -u | paste -sd ', ' -)
                HARVESTER_SUBDOMAINS=$(grep -oE '[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' "$raw_file" | sort -u | paste -sd ', ' -)
                export HARVESTER_EMAILS HARVESTER_SUBDOMAINS
            fi
        fi

        {
            echo "=== theHarvester Results ==="
            echo "Dominio: ${dominio}"
            echo ""
            echo "--- Emails ---"
            echo "${HARVESTER_EMAILS:-Nenhum encontrado}"
            echo ""
            echo "--- Subdominios ---"
            echo "${HARVESTER_SUBDOMAINS:-Nenhum encontrado}"
        } > "$harvester_file"

        log_success "theHarvester concluido para ${dominio}"
    else
        log_warning "theHarvester falhou para ${dominio}"
        echo "theHarvester: N/A (falha na execucao)" > "$harvester_file"
    fi

    export HARVESTER_EMAILS HARVESTER_SUBDOMAINS
}
