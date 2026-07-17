#!/bin/bash
# shodan.sh - Integracao com Shodan/Censys API (opcional, requer chave)

query_shodan() {
    local ip=$1
    local pasta=$2
    local shodan_file="${pasta}/shodan.txt"

    SHODAN_DATA="N/A"
    SHODAN_PORTS="N/A"
    SHODAN_VULNS="N/A"

    if [ -z "${SHODAN_API_KEY:-}" ]; then
        echo "Shodan: sem chave configurada (SKIP)" > "$shodan_file"
        export SHODAN_DATA SHODAN_PORTS SHODAN_VULNS
        return
    fi

    log_info "Consultando Shodan para IP $ip..."
    curl -s "https://api.shodan.io/shodan/host/${ip}?key=${SHODAN_API_KEY}" -o "${pasta}/shodan_response.json" 2>/dev/null

    if [ -s "${pasta}/shodan_response.json" ]; then
        local shodan_data=$(cat "${pasta}/shodan_response.json")
        if ! echo "$shodan_data" | jq -e '.error' &>/dev/null; then
            local org=$(echo "$shodan_data" | jq -r '.org // "N/A"')
            local isp=$(echo "$shodan_data" | jq -r '.isp // "N/A"')
            local os=$(echo "$shodan_data" | jq -r '.os // "N/A"')
            local hostname=$(echo "$shodan_data" | jq -r '.hostnames[0] // "N/A"')
            local ports=$(echo "$shodan_data" | jq -r '.ports[]' 2>/dev/null | paste -sd ', ' -)
            local vulns=$(echo "$shodan_data" | jq -r '.vulns[]' 2>/dev/null | paste -sd ', ' -)

            SHODAN_DATA="Org: $org | ISP: $isp | OS: $os | Hostname: $hostname"
            SHODAN_PORTS="${ports:-N/A}"
            SHODAN_VULNS="${vulns:-Nenhuma}"

            {
                echo "=== SHODAN.IO ==="
                echo "IP: $ip"
                echo "Organizacao: $org"
                echo "ISP: $isp"
                echo "SO: $os"
                echo "Hostname: $hostname"
                echo "Portas: $SHODAN_PORTS"
                echo "Vulnerabilidades: $SHODAN_VULNS"
                echo ""
                echo "Dados brutos:"
                echo "$shodan_data" | jq -c 'del(.data)' 2>/dev/null || echo "$shodan_data"
            } > "$shodan_file"

            log_success "Shodan: dados encontrados ($(echo "$ports" | wc -w) portas)"
        else
            local error_msg=$(echo "$shodan_data" | jq -r '.error // "desconhecido"')
            echo "Shodan: erro - $error_msg" > "$shodan_file"
            log_warning "Shodan: $error_msg"
        fi
    else
        echo "Shodan: sem resposta da API" > "$shodan_file"
        log_warning "Shodan: sem resposta"
    fi

    export SHODAN_DATA SHODAN_PORTS SHODAN_VULNS
}

query_censys() {
    local ip=$1
    local pasta=$2
    local censys_file="${pasta}/censys.txt"

    CENSYS_DATA="N/A"

    if [ -z "${CENSYS_API_ID:-}" ] || [ -z "${CENSYS_SECRET:-}" ]; then
        echo "Censys: sem credenciais configuradas (SKIP)" > "$censys_file"
        export CENSYS_DATA
        return
    fi

    log_info "Consultando Censys para IP $ip..."
    local auth=$(echo -n "${CENSYS_API_ID}:${CENSYS_SECRET}" | base64 -w0 2>/dev/null || echo -n "${CENSYS_API_ID}:${CENSYS_SECRET}" | base64 2>/dev/null)
    if [ -z "$auth" ]; then return; fi

    curl -s "https://search.censys.io/api/v2/hosts/${ip}" \
        -H "Authorization: Basic ${auth}" \
        -o "${pasta}/censys_response.json" 2>/dev/null

    if [ -s "${pasta}/censys_response.json" ]; then
        local censys_data=$(cat "${pasta}/censys_response.json")
        if ! echo "$censys_data" | jq -e '.error' &>/dev/null; then
            local location=$(echo "$censys_data" | jq -r '.result.location // empty')
            local services=$(echo "$censys_data" | jq -r '.result.services[]?.service_name' 2>/dev/null | paste -sd ', ' -)

            CENSYS_DATA="Location: ${location:-N/A} | Services: ${services:-N/A}"

            {
                echo "=== CENSYS.IO ==="
                echo "IP: $ip"
                echo "$censys_data" | jq '.result | {location, services: [.services[]?.service_name], ports: [.services[]?.port]}' 2>/dev/null
            } > "$censys_file"

            log_success "Censys: dados encontrados"
        else
            echo "Censys: erro na consulta" > "$censys_file"
        fi
    else
        echo "Censys: sem resposta" > "$censys_file"
    fi

    export CENSYS_DATA
}
