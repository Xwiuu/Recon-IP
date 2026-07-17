#!/bin/bash
# mac_osint.sh - OSINT completo para MAC Address

mac_osint_full() {
    local mac=$1
    local pasta=$2
    local mac_file="${pasta}/mac_osint.txt"

    local mac_normalized=$(echo "$mac" | tr '[:lower:]' '[:upper:]' | tr -d ':-')

    echo "=== MAC OSINT COMPLETO ===" > "$mac_file"
    echo "MAC: ${mac}" >> "$mac_file"
    echo "MAC Normalizado: ${mac_normalized}" >> "$mac_file"
    echo "Data: $(date)" >> "$mac_file"
    echo "--------------------------------" >> "$mac_file"

    # 1. FABRICANTE
    log_info "Buscando fabricante detalhado..."
    local fabricante=$(consulta_mac "$mac")
    echo "Fabricante: ${fabricante}" >> "$mac_file"

    # 2. OUI DETAILS
    if command -v curl &>/dev/null; then
        log_info "Buscando detalhes do OUI..."
        curl -s "https://api.macvendors.com/v1/${mac_normalized}" -o "${pasta}/oui_details.json" 2>/dev/null
        if [ -s "${pasta}/oui_details.json" ]; then
            local oui_cidade=$(jq -r '.city // "N/A"' "${pasta}/oui_details.json" 2>/dev/null)
            local oui_pais=$(jq -r '.country // "N/A"' "${pasta}/oui_details.json" 2>/dev/null)
            local oui_endereco=$(jq -r '.address // "N/A"' "${pasta}/oui_details.json" 2>/dev/null)
            local oui_tipo=$(jq -r '.type // "N/A"' "${pasta}/oui_details.json" 2>/dev/null)
            echo "OUI Cidade: ${oui_cidade}" >> "$mac_file"
            echo "OUI Pais: ${oui_pais}" >> "$mac_file"
            echo "OUI Endereco: ${oui_endereco}" >> "$mac_file"
            echo "OUI Tipo: ${oui_tipo}" >> "$mac_file"
        fi
    fi

    # 3. ARP SCAN
    log_info "Verificando rede local via ARP..."
    local ip_local=""
    if command -v arp &>/dev/null; then
        ip_local=$(arp -a 2>/dev/null | grep -i "$mac" | awk '{print $1}' | head -n1)
        if [ -n "$ip_local" ]; then
            echo "IP Local (ARP): ${ip_local}" >> "$mac_file"
            log_success "IP Local encontrado: ${ip_local}"
        else
            echo "IP Local (ARP): Nao encontrado" >> "$mac_file"
            log_warning "IP Local nao encontrado no ARP."
        fi
    elif command -v arp-scan &>/dev/null; then
        ip_local=$(arp-scan --localnet 2>/dev/null | grep -i "$mac" | awk '{print $1}')
        if [ -n "$ip_local" ]; then
            echo "IP Local (arp-scan): ${ip_local}" >> "$mac_file"
            log_success "IP Local encontrado: ${ip_local}"
        fi
    else
        echo "IP Local: ARP/arp-scan nao disponivel" >> "$mac_file"
    fi

    # 4. SHODAN
    if [ -n "$SHODAN_API_KEY" ] && [ "$SHODAN_API_KEY" != "COLOQUE_SUA_CHAVE_AQUI" ]; then
        log_info "Consultando Shodan para MAC ${mac}..."
        local shodan_data=$(curl -s "https://api.shodan.io/shodan/host/search?key=${SHODAN_API_KEY}&query=${mac_normalized}")
        echo "$shodan_data" > "${pasta}/shodan_mac.json" 2>/dev/null
        local total=$(echo "$shodan_data" | jq -r '.total // 0')
        echo "Shodan IPs encontrados: ${total}" >> "$mac_file"
        if [ "$total" -gt 0 ]; then
            echo "Shodan IPs:" >> "$mac_file"
            echo "$shodan_data" | jq -r '.matches[].ip_str' | head -10 | sed 's/^/  - /' >> "$mac_file"
        fi
    else
        echo "Shodan: Chave nao configurada" >> "$mac_file"
    fi

    # 5. WIRESHARK OUI
    if command -v curl &>/dev/null; then
        log_info "Buscando no banco de dados do Wireshark..."
        curl -s "https://www.wireshark.org/cgi-bin/oui?q=${mac_normalized:0:6}" -o "${pasta}/wireshark_oui.html" 2>/dev/null
        if [ -s "${pasta}/wireshark_oui.html" ] && grep -qi "Technicolor\|Intel\|${fabricante}" "${pasta}/wireshark_oui.html" 2>/dev/null; then
            echo "Wireshark OUI: Encontrado" >> "$mac_file"
        else
            echo "Wireshark OUI: Nao encontrado" >> "$mac_file"
        fi
    fi

    # 6. GOOGLE DORKS
    log_info "Gerando Google Dorks para MAC..."
    echo "" >> "$mac_file"
    echo "=== GOOGLE DORKS (MAC) ===" >> "$mac_file"
    local dorks=(
        "https://www.google.com/search?q=%22${mac}%22"
        "https://www.google.com/search?q=%22${mac_normalized}%22"
        "https://www.google.com/search?q=${mac_normalized}"
        "https://www.google.com/search?q=%22${mac}%22+shodan"
        "https://www.google.com/search?q=%22${mac}%22+vulnerable"
        "https://www.google.com/search?q=%22${mac}%22+default+password"
        "https://www.google.com/search?q=%22${mac}%22+device"
    )
    for dork in "${dorks[@]}"; do
        echo "  ${dork}" >> "$mac_file"
    done

    # 7. REPUTACAO
    echo "" >> "$mac_file"
    echo "=== REPUTACAO ===" >> "$mac_file"
    if [ -n "$ABUSEIPDB_KEY" ] && [ "$ABUSEIPDB_KEY" != "COLOQUE_SUA_CHAVE_AQUI" ] && [ -n "$ip_local" ]; then
        log_info "Consultando reputacao do IP ${ip_local}..."
        local abuse_data=$(curl -s "https://api.abuseipdb.com/api/v2/check?ipAddress=${ip_local}" -H "Key: ${ABUSEIPDB_KEY}" -H "Accept: application/json")
        echo "$abuse_data" > "${pasta}/abuse_mac.json" 2>/dev/null
        local score=$(echo "$abuse_data" | jq -r '.data.abuseConfidenceScore // 0')
        local reports=$(echo "$abuse_data" | jq -r '.data.totalReports // 0')
        echo "Abuse Score: ${score}%" >> "$mac_file"
        echo "Abuse Reports: ${reports}" >> "$mac_file"
    else
        echo "Reputacao: Nao disponivel" >> "$mac_file"
    fi

    log_success "MAC OSINT concluido!"
}
