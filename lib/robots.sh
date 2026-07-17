#!/bin/bash
# robots.sh - Analisa robots.txt e sitemap.xml

check_robots() {
    local ip=$1
    local dominio=$2
    local pasta=$3
    local robots_file="${pasta}/robots_analysis.txt"

    if [ -z "$dominio" ] || [ "$dominio" = "N/A" ]; then
        echo "Nenhum dominio informado." > "$robots_file"
        ROBOTS_DISALLOW="N/A"; ROBOTS_ALLOW="N/A"
        ROBOTS_SITEMAP="N/A"; SITEMAP_URLS="N/A"; SITEMAP_COUNT=0
        export ROBOTS_DISALLOW ROBOTS_ALLOW ROBOTS_SITEMAP SITEMAP_URLS SITEMAP_COUNT
        return
    fi

    log_info "Analisando robots.txt e sitemap.xml de $dominio..."

    local proto="https"
    if ! curl -skI --max-time 5 "https://${dominio}" &>/dev/null; then
        proto="http"
    fi

    {
        echo "=== ROBOTS.TXT E SITEMAP.XML ==="
        echo "Dominio: $dominio"
        echo "Data: $(date)"
        echo "--------------------------------"
    } > "$robots_file"

    curl -skL --max-time 5 "${proto}://${dominio}/robots.txt" -o "${pasta}/robots_raw.txt" 2>/dev/null

    echo -e "\n--- robots.txt ---" >> "$robots_file"
    if [ -s "${pasta}/robots_raw.txt" ]; then
        cat "${pasta}/robots_raw.txt" >> "$robots_file"
        local disallowed=$(grep -i "^Disallow:" "${pasta}/robots_raw.txt" | sed 's/Disallow: //I')
        local allowed=$(grep -i "^Allow:" "${pasta}/robots_raw.txt" | sed 's/Allow: //I')
        local sitemap=$(grep -i "^Sitemap:" "${pasta}/robots_raw.txt" | sed 's/Sitemap: //I')

        ROBOTS_DISALLOW=$(echo "$disallowed" | paste -sd ', ' -)
        ROBOTS_ALLOW=$(echo "$allowed" | paste -sd ', ' -)
        ROBOTS_SITEMAP=$(echo "$sitemap" | paste -sd ', ' -)

        [ -n "$ROBOTS_DISALLOW" ] && log_warning "Diretorios proibidos: $ROBOTS_DISALLOW"
        [ -n "$ROBOTS_SITEMAP" ] && log_success "Sitemap encontrado em robots.txt"
    else
        echo "robots.txt nao encontrado ou inacessivel." >> "$robots_file"
        ROBOTS_DISALLOW="N/A"; ROBOTS_ALLOW="N/A"; ROBOTS_SITEMAP="N/A"
    fi

    local sitemap_url="${ROBOTS_SITEMAP:-${proto}://${dominio}/sitemap.xml}"
    sitemap_url=$(echo "$sitemap_url" | sed 's/,.*//' | xargs)

    curl -skL --max-time 5 "$sitemap_url" -o "${pasta}/sitemap_raw.xml" 2>/dev/null

    echo -e "\n--- sitemap.xml ---" >> "$robots_file"
    if [ -s "${pasta}/sitemap_raw.xml" ]; then
        head -c 2000 "${pasta}/sitemap_raw.xml" >> "$robots_file"
        local urls=$(grep -oP '<loc>\K[^<]+' "${pasta}/sitemap_raw.xml" 2>/dev/null | head -30)
        SITEMAP_URLS=$(echo "$urls" | paste -sd '\n' -)
        if [ -n "$urls" ]; then
            SITEMAP_COUNT=$(echo "$urls" | wc -l)
            log_success "Sitemap contem ${SITEMAP_COUNT} URLs"
        else
            SITEMAP_COUNT=0
            SITEMAP_URLS="N/A"
        fi
    else
        echo "sitemap.xml nao encontrado ou inacessivel." >> "$robots_file"
        SITEMAP_URLS="N/A"
        SITEMAP_COUNT=0
    fi

    export ROBOTS_DISALLOW ROBOTS_ALLOW ROBOTS_SITEMAP SITEMAP_URLS SITEMAP_COUNT
    log_success "Analise de robots.txt concluida."
}
