#!/bin/bash
# telemetry.sh - Análise de Segurança (Safe Browsing, DNSBL, URLScan, VirusTotal)

check_telemetry() {
    local ip=$1
    local pasta=$2
    local dominio=$3
    local telemetry_file="${pasta}/telemetry.txt"

    SAFEBROWSING_MALICIOUS="N/A (sem chave)"
    SB_THREATS=""
    DNSBL_LISTED="Não"
    DNSBL_SOURCES=""
    URLSCAN_URL="N/A"
    URLSCAN_RESULT=""
    VT_MALICIOUS="N/A"
    VT_TOTAL="N/A"
    VT_SCORE="N/A"

    echo "=== TELEMETRIA DE SEGURANCA ===" > "$telemetry_file"
    echo "IP: $ip" >> "$telemetry_file"
    echo "Dominio: ${dominio:-N/A}" >> "$telemetry_file"
    echo "Data: $(date)" >> "$telemetry_file"
    echo "--------------------------------" >> "$telemetry_file"

    if ! tem_internet; then
        log_warning "Sem internet. Pulando todas as consultas online de telemetria."
        SAFEBROWSING_MALICIOUS="N/A (offline)"
        URLSCAN_URL="N/A (offline)"
        VT_MALICIOUS="N/A"
        VT_TOTAL="N/A"
        export SAFEBROWSING_MALICIOUS SB_THREATS DNSBL_LISTED DNSBL_SOURCES
        export URLSCAN_URL URLSCAN_RESULT VT_MALICIOUS VT_TOTAL VT_SCORE
        return 1
    fi

    # Google Safe Browsing
    if [ -n "$dominio" ] && [ -n "${SAFEBROWSING_KEY:-}" ]; then
        log_info "Consultando Google Safe Browsing..."
        local sb_payload
        sb_payload=$(cat <<EOF
{
  "client": {
    "clientId": "reconip",
    "clientVersion": "2.0"
  },
  "threatInfo": {
    "threatTypes": ["MALWARE", "SOCIAL_ENGINEERING", "UNWANTED_SOFTWARE", "POTENTIALLY_HARMFUL_APPLICATION"],
    "platformTypes": ["ANY_PLATFORM"],
    "threatEntryTypes": ["URL"],
    "threatEntries": [
      {"url": "https://${dominio}/"},
      {"url": "http://${dominio}/"}
    ]
  }
}
EOF
)
        local sb_result
        sb_result=$(curl -s -m 10 -X POST \
            "https://safebrowsing.googleapis.com/v4/threatMatches:find?key=${SAFEBROWSING_KEY}" \
            -H "Content-Type: application/json" \
            -d "$sb_payload" 2>/dev/null)
        if [ -n "$sb_result" ]; then
            echo "$sb_result" > "${pasta}/safe_browsing.json"
            if echo "$sb_result" | grep -q "matches"; then
                SAFEBROWSING_MALICIOUS="⚠️ MALICIOSO"
                SB_THREATS=$(echo "$sb_result" | jq -r '.matches[]?.threatType // empty' 2>/dev/null | tr '\n' ', ')
                log_warning "Safe Browsing: MALICIOSO ($SB_THREATS)"
            else
                SAFEBROWSING_MALICIOUS="✅ Seguro"
                log_success "Safe Browsing: Seguro"
            fi
            echo "✅ Google Safe Browsing:" >> "$telemetry_file"
            echo "   Status: ${SAFEBROWSING_MALICIOUS}" >> "$telemetry_file"
            [ -n "$SB_THREATS" ] && echo "   Ameacas: ${SB_THREATS}" >> "$telemetry_file"
        else
            log_warning "Safe Browsing: sem resposta"
        fi
    elif [ -n "$dominio" ]; then
        log_info "SAFEBROWSING_KEY nao configurada. Pulando Safe Browsing."
    fi

    # DNSBL Checks
    log_info "Verificando listas negras DNSBL..."
    local rev_ip
    rev_ip=$(echo "$ip" | awk -F. '{print $4"."$3"."$2"."$1}')
    local dnsbl_zones=("zen.spamhaus.org" "b.barracudacentral.org" "bl.spamcop.net" "dnsbl.sorbs.net")
    local listed=0
    for zone in "${dnsbl_zones[@]}"; do
        local lookup="${rev_ip}.${zone}"
        if command -v host &>/dev/null; then
            if host -W 2 "$lookup" 2>/dev/null | grep -q "NXDOMAIN\|not found\|SERVFAIL"; then
                :
            elif host -W 2 "$lookup" 2>/dev/null | grep -qE "127\.|has address"; then
                listed=1
                DNSBL_SOURCES="${DNSBL_SOURCES}${zone}, "
                log_warning "Listado em: $zone"
            fi
        elif command -v dig &>/dev/null; then
            if dig +short +time=2 "$lookup" 2>/dev/null | grep -qE '^127\.'; then
                listed=1
                DNSBL_SOURCES="${DNSBL_SOURCES}${zone}, "
                log_warning "Listado em: $zone"
            fi
        fi
    done
    if [ "$listed" -eq 1 ]; then
        DNSBL_LISTED="⚠️ Listado"
        DNSBL_SOURCES="${DNSBL_SOURCES%, }"
    else
        DNSBL_LISTED="✅ Nao listado"
        log_success "DNSBL: Nao listado em nenhuma blacklist"
    fi
    echo "✅ DNSBL:" >> "$telemetry_file"
    echo "   Status: ${DNSBL_LISTED}" >> "$telemetry_file"
    [ -n "$DNSBL_SOURCES" ] && echo "   Fontes: ${DNSBL_SOURCES}" >> "$telemetry_file"

    # URLScan.io
    if [ -n "$dominio" ] && [ -n "${URLSCAN_API_KEY:-}" ]; then
        log_info "Enviando para URLScan.io..."
        local us_payload
        us_payload=$(cat <<EOF
{"url": "https://${dominio}/", "visibility": "public"}
EOF
)
        local us_submit
        us_submit=$(curl -s -m 15 -X POST "https://urlscan.io/api/v1/scan/" \
            -H "Content-Type: application/json" \
            -H "API-Key: ${URLSCAN_API_KEY}" \
            -d "$us_payload" 2>/dev/null)
        if [ -n "$us_submit" ]; then
            echo "$us_submit" > "${pasta}/urlscan_submit.json"
            local us_api_url
            us_api_url=$(echo "$us_submit" | jq -r '.api // empty' 2>/dev/null)
            local us_result_url
            us_result_url=$(echo "$us_submit" | jq -r '.result // empty' 2>/dev/null)
            if [ -n "$us_result_url" ]; then
                URLSCAN_URL="$us_result_url"
                log_success "URLScan.io: $URLSCAN_URL"
                # Poll for result
                sleep 3
                local us_result
                us_result=$(curl -s -m 10 "$us_api_url" 2>/dev/null)
                if [ -n "$us_result" ]; then
                    echo "$us_result" > "${pasta}/urlscan_result.json"
                    URLSCAN_RESULT=$(echo "$us_result" | jq -r '.verdicts.overall.malicious // false' 2>/dev/null)
                    local us_domains
                    us_domains=$(echo "$us_result" | jq -r '.lists.domains[]? // empty' 2>/dev/null | head -5)
                    [ -n "$us_domains" ] && URLSCAN_RESULT="${URLSCAN_RESULT} | dominios: $(echo "$us_domains" | tr '\n' ', ')"
                fi
            fi
            echo "✅ URLScan.io:" >> "$telemetry_file"
            echo "   URL: ${URLSCAN_URL}" >> "$telemetry_file"
            [ -n "$URLSCAN_RESULT" ] && echo "   Resultado: ${URLSCAN_RESULT}" >> "$telemetry_file"
        fi
    elif [ -n "$dominio" ]; then
        log_info "URLSCAN_API_KEY nao configurada. Pulando URLScan."
    fi

    # VirusTotal
    if [ -n "${VIRUSTOTAL_KEY:-}" ]; then
        log_info "Consultando VirusTotal..."
        local vt_result
        vt_result=$(curl -s -m 10 \
            -H "x-apikey: ${VIRUSTOTAL_KEY}" \
            "https://www.virustotal.com/api/v3/ip_addresses/${ip}" 2>/dev/null)
        if [ -n "$vt_result" ]; then
            echo "$vt_result" > "${pasta}/virustotal.json"
            local stats
            stats=$(echo "$vt_result" | jq '.data.attributes.last_analysis_stats' 2>/dev/null)
            if [ -n "$stats" ] && [ "$stats" != "null" ]; then
                VT_MALICIOUS=$(echo "$stats" | jq '.malicious // 0' 2>/dev/null)
                VT_TOTAL=$(echo "$stats" | jq '(.harmless // 0) + (.malicious // 0) + (.suspicious // 0) + (.undetected // 0)' 2>/dev/null)
                if [ "$VT_TOTAL" -gt 0 ]; then
                    VT_SCORE=$(echo "scale=2; $VT_MALICIOUS * 100 / $VT_TOTAL" | bc 2>/dev/null || echo "0")
                fi
                if [ "$VT_MALICIOUS" -gt 0 ]; then
                    log_warning "VirusTotal: ${VT_MALICIOUS}/${VT_TOTAL} malicioso (${VT_SCORE}%)"
                else
                    log_success "VirusTotal: ${VT_MALICIOUS}/${VT_TOTAL} — Limpo"
                fi
            fi
            echo "✅ VirusTotal:" >> "$telemetry_file"
            echo "   Malicioso: ${VT_MALICIOUS}/${VT_TOTAL}" >> "$telemetry_file"
            [ "$VT_SCORE" != "N/A" ] && echo "   Score: ${VT_SCORE}%" >> "$telemetry_file"
        else
            log_warning "Falha ao consultar VirusTotal."
        fi
    else
        log_info "VIRUSTOTAL_KEY nao configurada. Pulando VirusTotal."
    fi

    export SAFEBROWSING_MALICIOUS SB_THREATS DNSBL_LISTED DNSBL_SOURCES
    export URLSCAN_URL URLSCAN_RESULT VT_MALICIOUS VT_TOTAL VT_SCORE
    log_success "Telemetria concluída."
}
