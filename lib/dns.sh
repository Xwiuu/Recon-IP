#!/bin/bash
# dns.sh - Coleta registros DNS avancados, ping no dominio e verificacao HTTPS

dns_extras() {
    local dominio=$1
    local pasta=$2
    local dns_file="${pasta}/dns.txt"

    log_info "Coletando registros DNS de $dominio..."

    echo "=== REGISTROS DNS ===" > "$dns_file"

    local ipv4="" ipv6="" mx="" txt="" ns="" soa=""

    if command -v dig &>/dev/null; then
        ipv4=$(dig +short -4 "$dominio" 2>/dev/null | grep -E '^[0-9.]+$' | head -1)
        ipv6=$(dig +short AAAA "$dominio" 2>/dev/null | grep -E '^[0-9a-fA-F:]+$' | head -1)
        mx=$(dig +short MX "$dominio" 2>/dev/null | sort -n | head -5 | while IFS= read -r line; do
            local prio=$(echo "$line" | awk '{print $1}')
            local host=$(echo "$line" | awk '{print $2}')
            echo "$host (prioridade $prio)"
        done | paste -sd ', ')
        txt=$(dig +short TXT "$dominio" 2>/dev/null | head -5 | paste -sd ', ')
        ns=$(dig +short NS "$dominio" 2>/dev/null | head -5 | paste -sd ', ')
        soa=$(dig +short SOA "$dominio" 2>/dev/null | head -1)
    elif command -v host &>/dev/null; then
        ipv4=$(host -t A "$dominio" 2>/dev/null | grep 'has address' | head -1 | awk '{print $NF}')
        ipv6=$(host -t AAAA "$dominio" 2>/dev/null | grep 'has IPv6 address' | head -1 | awk '{print $NF}')
        mx=$(host -t MX "$dominio" 2>/dev/null | grep 'mail exchanger' | head -5 | awk '{print $NF}' | paste -sd ', ')
        txt=$(host -t TXT "$dominio" 2>/dev/null | grep 'descriptive text' | head -5 | sed 's/.*"\(.*\)".*/\1/' | paste -sd ', ')
        ns=$(host -t NS "$dominio" 2>/dev/null | grep 'name server' | head -5 | awk '{print $NF}' | paste -sd ', ')
        soa=""
    else
        log_warning "Nem dig nem host disponiveis para consulta DNS"
        echo "N/A" > "$dns_file"
        return 1
    fi

    {
        echo "IPv4: ${ipv4:-N/A}"
        echo "IPv6: ${ipv6:-N/A}"
        echo "MX: ${mx:-N/A}"
        echo "TXT: ${txt:-N/A}"
        echo "NS: ${ns:-N/A}"
        echo "SOA: ${soa:-N/A}"
    } >> "$dns_file"

    DNS_IPV4="${ipv4:-N/A}"
    DNS_IPV6="${ipv6:-N/A}"
    DNS_MX="${mx:-N/A}"
    DNS_TXT="${txt:-N/A}"
    DNS_NS="${ns:-N/A}"
    DNS_SOA="${soa:-N/A}"
    export DNS_IPV4 DNS_IPV6 DNS_MX DNS_TXT DNS_NS DNS_SOA
    log_success "Registros DNS coletados."
}

# ========== REVERSE DNS (PTR) ==========
reverse_dns_lookup() {
    local ip=$1
    local pasta=$2
    local ptr_file="${pasta}/reverse_dns.txt"

    PTR_RECORD="N/A"

    log_info "Consultando registro PTR (reverse DNS) para $ip..."

    local ptr=""
    if command -v nslookup &>/dev/null; then
        ptr=$(nslookup "$ip" 2>/dev/null | grep -E '^Name:' | awk '{print $NF}' | head -1)
    elif command -v host &>/dev/null; then
        ptr=$(host "$ip" 2>/dev/null | grep 'domain name pointer' | head -1 | awk '{print $NF}' | sed 's/\.$//')
    elif command -v dig &>/dev/null; then
        ptr=$(dig +short -x "$ip" 2>/dev/null | head -1)
    fi

    if [ -n "$ptr" ]; then
        PTR_RECORD="$ptr"
        echo "PTR: $ptr" > "$ptr_file"
        log_success "Reverse DNS: $ptr"
    else
        echo "PTR: Nao encontrado" > "$ptr_file"
        log_info "Reverse DNS: sem registro PTR para $ip"
    fi

    export PTR_RECORD
}

ping_domain() {
    local dominio=$1
    local pasta=$2

    log_info "Pingando dominio $dominio..."

    if command -v ping &>/dev/null; then
        local ping_result
        ping_result=$(ping -c 1 -W 1 "$dominio" 2>/dev/null | grep -oE 'time=[0-9.]+ ms' | head -1)
        if [ -n "$ping_result" ]; then
            DOMAIN_PING="$ping_result"
            log_success "Ping dominio: $DOMAIN_PING"
        else
            DOMAIN_PING="Sem resposta"
            log_warning "Ping dominio: Sem resposta"
        fi
    else
        DOMAIN_PING="Indisponivel (sem ping)"
        log_warning "Ping dominio: comando nao disponivel"
    fi
    export DOMAIN_PING
}

check_https() {
    local dominio=$1
    local pasta=$2
    local https_file="${pasta}/https.txt"

    log_info "Verificando HTTPS de $dominio..."

    echo "=== VERIFICACAO HTTPS ===" > "$https_file"

    local http_code server_info cert_info cert_valid

    http_code=$(curl -sI --max-time 5 --location "https://$dominio" 2>/dev/null | head -1 | awk '{print $2}')

    if [ -n "$http_code" ]; then
        HTTPS_STATUS="HTTPS ativo (HTTP $http_code)"
        server_info=$(curl -sI --max-time 5 "https://$dominio" 2>/dev/null | grep -i "^Server:" | sed 's/^[Ss][Ee][Rr][Vv][Ee][Rr]:[[:space:]]*//')
        HTTPS_SERVER="${server_info:-N/A}"

        if command -v openssl &>/dev/null; then
            cert_info=$(echo | openssl s_client -connect "${dominio}:443" -servername "$dominio" 2>/dev/null)
            if [ -n "$cert_info" ]; then
                local cert_subject cert_issuer cert_start cert_end
                cert_subject=$(echo "$cert_info" | openssl x509 -noout -subject 2>/dev/null | sed 's/^subject=//')
                cert_issuer=$(echo "$cert_info" | openssl x509 -noout -issuer 2>/dev/null | sed 's/^issuer=//')
                cert_start=$(echo "$cert_info" | openssl x509 -noout -startdate 2>/dev/null | sed 's/^notBefore=//')
                cert_end=$(echo "$cert_info" | openssl x509 -noout -enddate 2>/dev/null | sed 's/^notAfter=//')
                HTTPS_CERT_SUBJECT="${cert_subject:-N/A}"
                HTTPS_CERT_ISSUER="${cert_issuer:-N/A}"
                HTTPS_CERT_START="${cert_start:-N/A}"
                HTTPS_CERT_END="${cert_end:-N/A}"

                local now_epoch end_epoch
                now_epoch=$(date +%s)
                end_epoch=$(date -d "$cert_end" +%s 2>/dev/null)
                if [ -n "$end_epoch" ] && [ "$end_epoch" -gt "$now_epoch" ]; then
                    local days_left=$(( (end_epoch - now_epoch) / 86400 ))
                    HTTPS_CERT_VALID="Sim ($days_left dias restantes)"
                else
                    HTTPS_CERT_VALID="Nao (expirado ou invalido)"
                fi
            else
                HTTPS_CERT_SUBJECT="N/A"
                HTTPS_CERT_ISSUER="N/A"
                HTTPS_CERT_START="N/A"
                HTTPS_CERT_END="N/A"
                HTTPS_CERT_VALID="N/A"
            fi
        else
            HTTPS_CERT_SUBJECT="N/A (sem openssl)"
            HTTPS_CERT_ISSUER="N/A"
            HTTPS_CERT_START="N/A"
            HTTPS_CERT_END="N/A"
            HTTPS_CERT_VALID="N/A"
        fi
    else
        local http_code_plain
        http_code_plain=$(curl -sI --max-time 5 --location "http://$dominio" 2>/dev/null | head -1 | awk '{print $2}')
        if [ -n "$http_code_plain" ]; then
            HTTPS_STATUS="HTTPS indisponivel (apenas HTTP)"
        else
            HTTPS_STATUS="N/A (dominio nao respondeu)"
        fi
        HTTPS_SERVER="N/A"
        HTTPS_CERT_SUBJECT="N/A"
        HTTPS_CERT_ISSUER="N/A"
        HTTPS_CERT_START="N/A"
        HTTPS_CERT_END="N/A"
        HTTPS_CERT_VALID="N/A"
    fi

    {
        echo "Status: $HTTPS_STATUS"
        echo "Server: $HTTPS_SERVER"
        echo "Certificado Valido: $HTTPS_CERT_VALID"
        echo "Subject: $HTTPS_CERT_SUBJECT"
        echo "Emissor: $HTTPS_CERT_ISSUER"
        echo "Valido de: $HTTPS_CERT_START"
        echo "Valido ate: $HTTPS_CERT_END"
    } >> "$https_file"

    export HTTPS_STATUS HTTPS_SERVER HTTPS_CERT_SUBJECT HTTPS_CERT_ISSUER HTTPS_CERT_START HTTPS_CERT_END HTTPS_CERT_VALID
    log_success "Verificacao HTTPS: $HTTPS_STATUS"
}
