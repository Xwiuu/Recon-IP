#!/bin/bash
# abuse.sh - Consulta de reputacao AbuseIPDB (opcional, pula sem chave ou internet)

check_reputation() {
    local ip=$1
    local pasta=$2
    local key="${ABUSEIPDB_KEY:-}"

    ABUSE_SCORE="N/A"
    ABUSE_REPORTS="N/A"
    ABUSE_LAST="N/A"

    if [ -z "$key" ]; then
        log_info "ABUSEIPDB_KEY nao configurada. Pulando reputacao."
        export ABUSE_SCORE ABUSE_REPORTS ABUSE_LAST
        return 0
    fi

    if ! tem_internet; then
        log_warning "Sem internet. Pulando consulta AbuseIPDB."
        export ABUSE_SCORE ABUSE_REPORTS ABUSE_LAST
        return 0
    fi

    log_info "Consultando reputacao no AbuseIPDB..."

    local result
    result=$(curl -s -H "Key: ${key}" -H "Accept: application/json" \
        "https://api.abuseipdb.com/api/v2/check?ipAddress=${ip}" 2>/dev/null)

    if [ -z "$result" ]; then
        log_warning "Falha ao consultar AbuseIPDB."
        export ABUSE_SCORE ABUSE_REPORTS ABUSE_LAST
        return 1
    fi

    echo "$result" > "${pasta}/abuseipdb.json"

    ABUSE_SCORE=$(echo "$result" | jq -r '.data.abuseConfidenceScore // "N/A"' 2>/dev/null)
    ABUSE_REPORTS=$(echo "$result" | jq -r '.data.totalReports // "N/A"' 2>/dev/null)
    ABUSE_LAST=$(echo "$result" | jq -r '.data.lastReportedAt // "Nunca"' 2>/dev/null)

    export ABUSE_SCORE ABUSE_REPORTS ABUSE_LAST
    log_success "Abuse Score: ${ABUSE_SCORE} | Reports: ${ABUSE_REPORTS}"
    return 0
}
