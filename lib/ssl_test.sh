#!/bin/bash
# ssl_test.sh - Testes profundos de SSL/TLS (protocolos, POODLE, BEAST, CRIME, cifras fracas)

test_ssl_protocols() {
    local ip=$1
    local dominio=$2
    local pasta=$3
    local ssl_file="${pasta}/ssl_test.txt"

    SSL_TLS10="N/A"
    SSL_TLS11="N/A"
    SSL_TLS12="N/A"
    SSL_TLS13="N/A"
    SSL_POODLE="N/A"
    SSL_BEAST="N/A"
    SSL_CRIME="N/A"
    SSL_WEAK_CIPHERS="N/A"

    if ! grep -q "443/tcp.*ABERTA\|8443/tcp.*ABERTA" "${pasta}/portas.txt" 2>/dev/null; then
        echo "Sem HTTPS disponivel." > "$ssl_file"
        export SSL_TLS10 SSL_TLS11 SSL_TLS12 SSL_TLS13 SSL_POODLE SSL_BEAST SSL_CRIME SSL_WEAK_CIPHERS
        return
    fi

    log_info "Testando protocolos SSL/TLS..."

    local host="${dominio:-$ip}"
    local ip_type=$(tipo_ip "$ip")
    local ssl_opts=""
    [ "$ip_type" = "IPv6" ] && ssl_opts="-6"

    {
        echo "=== TESTE DE SSL/TLS ==="
        echo "Host: $host"
        echo "Data: $(date)"
        echo "--------------------------------"
    } > "$ssl_file"

    if ! command -v openssl &>/dev/null; then
        echo "Teste SSL: openssl nao disponivel" >> "$ssl_file"
        export SSL_TLS10 SSL_TLS11 SSL_TLS12 SSL_TLS13 SSL_POODLE SSL_BEAST SSL_CRIME SSL_WEAK_CIPHERS
        return
    fi

    local hostport="${host}:443"

    # TLS 1.0
    if echo | timeout 4 openssl s_client $ssl_opts -connect "$hostport" -tls1 2>/dev/null < /dev/null | grep -q "CONNECTED"; then
        SSL_TLS10="Suportado (INSEGURO)"
        echo -e "\nTLS 1.0: Suportado - INSEGURO, deve ser desativado" >> "$ssl_file"
    else
        SSL_TLS10="Nao suportado (OK)"
        echo -e "\nTLS 1.0: Nao suportado" >> "$ssl_file"
    fi

    # TLS 1.1
    if echo | timeout 4 openssl s_client $ssl_opts -connect "$hostport" -tls1_1 2>/dev/null < /dev/null | grep -q "CONNECTED"; then
        SSL_TLS11="Suportado (INSEGURO)"
        echo "TLS 1.1: Suportado - INSEGURO, deve ser desativado" >> "$ssl_file"
    else
        SSL_TLS11="Nao suportado (OK)"
        echo "TLS 1.1: Nao suportado" >> "$ssl_file"
    fi

    # TLS 1.2
    if echo | timeout 4 openssl s_client $ssl_opts -connect "$hostport" -tls1_2 2>/dev/null < /dev/null | grep -q "CONNECTED"; then
        SSL_TLS12="Suportado (OK)"
        echo "TLS 1.2: Suportado" >> "$ssl_file"
    else
        SSL_TLS12="Nao suportado"
        echo "TLS 1.2: Nao suportado" >> "$ssl_file"
    fi

    # TLS 1.3
    if echo | timeout 4 openssl s_client $ssl_opts -connect "$hostport" -tls1_3 2>/dev/null < /dev/null | grep -q "CONNECTED"; then
        SSL_TLS13="Suportado (OK)"
        echo "TLS 1.3: Suportado" >> "$ssl_file"
    else
        SSL_TLS13="Nao suportado"
        echo "TLS 1.3: Nao suportado" >> "$ssl_file"
    fi

    # POODLE (SSLv3)
    if echo | timeout 4 openssl s_client $ssl_opts -connect "$hostport" -ssl3 2>/dev/null < /dev/null | grep -q "CONNECTED"; then
        SSL_POODLE="VULNERAVEL - SSLv3 suportado"
        echo "POODLE (SSLv3): VULNERAVEL" >> "$ssl_file"
    else
        SSL_POODLE="Nao vulneravel (SSLv3 bloqueado)"
        echo "POODLE (SSLv3): Nao vulneravel" >> "$ssl_file"
    fi

    # BEAST (TLS 1.0 + CBC)
    local beast_test=$(echo | timeout 4 openssl s_client $ssl_opts -connect "$hostport" -tls1 -cipher "aes" 2>/dev/null < /dev/null)
    if echo "$beast_test" | grep -q "CONNECTED"; then
        SSL_BEAST="Potencialmente vulneravel (TLS 1.0 + CBC)"
        echo "BEAST: Potencialmente vulneravel - TLS 1.0 com CBC" >> "$ssl_file"
    else
        SSL_BEAST="Nao vulneravel"
        echo "BEAST: Nao vulneravel" >> "$ssl_file"
    fi

    # CRIME (TLS compression)
    local crime_test=$(echo | timeout 4 openssl s_client $ssl_opts -connect "$hostport" -tlsextdebug 2>/dev/null < /dev/null)
    if echo "$crime_test" | grep -qi "compression"; then
        SSL_CRIME="VULNERAVEL - Compressao TLS habilitada"
        echo "CRIME: VULNERAVEL - Compressao TLS ativa" >> "$ssl_file"
    else
        SSL_CRIME="Nao vulneravel"
        echo "CRIME: Nao vulneravel" >> "$ssl_file"
    fi

    # Cifras fracas
    local weak_found=""
    for cipher in "RC4" "3DES" "EDH" "EXP" "NULL" "aNULL" "ADH"; do
        if echo | timeout 4 openssl s_client $ssl_opts -connect "$hostport" -cipher "$cipher" 2>/dev/null < /dev/null | grep -q "Cipher is"; then
            weak_found="${weak_found} ${cipher}"
        fi
    done

    if [ -n "$weak_found" ]; then
        SSL_WEAK_CIPHERS="Cifras fracas detectadas:${weak_found}"
        echo "Cifras fracas:${weak_found}" >> "$ssl_file"
    else
        SSL_WEAK_CIPHERS="Nenhuma cifra fraca detectada"
        echo "Cifras fracas: Nenhuma detectada" >> "$ssl_file"
    fi

    export SSL_TLS10 SSL_TLS11 SSL_TLS12 SSL_TLS13 SSL_POODLE SSL_BEAST SSL_CRIME SSL_WEAK_CIPHERS
    log_success "Testes SSL/TLS concluidos."
}
