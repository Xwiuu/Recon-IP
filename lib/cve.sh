#!/bin/bash
# cve.sh - Verifica CVEs do software identificado

check_cves() {
    local software=$1
    local version=$2
    local pasta=$3
    local cve_file="${pasta}/cves.txt"

    if [ -z "$software" ] || [ "$software" = "N/A" ]; then
        echo "Nenhum software identificado para verificar CVEs." > "$cve_file"
        return
    fi

    log_info "Verificando CVEs para $software $version..."

    local query="${software}"
    [ -n "$version" ] && query="${software} ${version}"

    curl -s "https://services.nvd.nist.gov/rest/json/cves/2.0?keywordSearch=${query}" -o "${pasta}/nvd_response.json"

    if [ -f "${pasta}/nvd_response.json" ] && [ -s "${pasta}/nvd_response.json" ]; then
        jq -r '.vulnerabilities[] | "CVE: \(.cve.id) - Severidade: \(.cve.metrics.cvssMetricV31[0].cvssData.baseSeverity) - Score: \(.cve.metrics.cvssMetricV31[0].cvssData.baseScore)"' "${pasta}/nvd_response.json" 2>/dev/null | head -10 > "$cve_file"
        if [ -s "$cve_file" ]; then
            log_success "CVEs encontrados (primeiros 10)."
        else
            echo "Nenhum CVE encontrado para $query." > "$cve_file"
        fi
    else
        echo "Nenhum CVE encontrado ou API indisponivel." > "$cve_file"
    fi
}

parse_server_info() {
    local server_info=$1
    local software=""
    local version=""

    if [[ "$server_info" == *"/"* ]]; then
        software=$(echo "$server_info" | cut -d/ -f1)
        version=$(echo "$server_info" | cut -d/ -f2-)
    else
        software="$server_info"
    fi

    echo "${software}|${version}"
}
