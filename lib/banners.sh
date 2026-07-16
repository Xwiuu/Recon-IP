#!/bin/bash
# banners.sh - Banner Grabbing (HTTP, SSL, SSH, FTP, Favicon)

server_color() {
    local srv=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    case "$srv" in
        *nginx*)   echo -e "${GREEN}$1${NC}" ;;
        *apache*)  echo -e "${YELLOW}$1${NC}" ;;
        *iis*)     echo -e "${RED}$1${NC}" ;;
        *)         echo -e "${CYAN}$1${NC}" ;;
    esac
}

grab_banner() {
    local ip=$1
    local pasta=$2
    local banner_file="${pasta}/banners.txt"

    SERVER_INFO="N/A"; TITLE_INFO="N/A"
    SSL_ISSUER="N/A"; SSL_EXPIRY="N/A"; SSL_CN="N/A"
    SSH_BANNER="N/A"; FTP_BANNER="N/A"; FAVICON_HASH="N/A"

    echo "=== BANNER GRABBING ===" > "$banner_file"
    echo "IP: $ip" >> "$banner_file"
    echo "Data: $(date)" >> "$banner_file"
    echo "--------------------------------" >> "$banner_file"

    # HTTP/HTTPS
    for porta in 80 443 8080 8443; do
        if grep -q "${porta}/tcp.*ABERTA" "${pasta}/portas.txt" 2>/dev/null; then
            proto="http"
            [ "$porta" = "443" ] || [ "$porta" = "8443" ] && proto="https"

            log_info "Capturando banner HTTP na porta ${porta}..."
            curl -k -s -L -m 3 -i "${proto}://${ip}:${porta}" 2>/dev/null | head -30 > "${pasta}/http_${porta}.txt"

            server=$(grep -i "^Server:" "${pasta}/http_${porta}.txt" | head -1 | sed 's/^[Ss]erver: //' | sed 's/\r//')
            xpowered=$(grep -i "^X-Powered-By:" "${pasta}/http_${porta}.txt" | head -1 | sed 's/^[Xx]-[Pp]owered-[Bb]y: //' | sed 's/\r//')
            title=$(grep -i "<title>" "${pasta}/http_${porta}.txt" | head -1 | sed 's/.*<title>//;s/<\/title>.*//' | sed 's/\r//')

            if [ "$porta" = "80" ] || [ "$porta" = "8080" ]; then
                [ -n "$server" ] && SERVER_INFO="$server"
                [ -n "$title" ] && TITLE_INFO="$title"
            fi
            if [ "$porta" = "443" ] || [ "$porta" = "8443" ]; then
                [ -n "$server" ] && [ "$SERVER_INFO" = "N/A" ] && SERVER_INFO="$server"
                [ -n "$title" ] && [ "$TITLE_INFO" = "N/A" ] && TITLE_INFO="$title"
            fi

            echo "✅ Porta ${porta} (${proto})" >> "$banner_file"
            [ -n "$server" ] && echo "   Servidor: $server" >> "$banner_file"
            [ -n "$xpowered" ] && echo "   X-Powered-By: $xpowered" >> "$banner_file"
            [ -n "$title" ] && echo "   Título: $title" >> "$banner_file"
        fi
    done

    [ "$SERVER_INFO" != "N/A" ] && log_success "Servidor Web: $(server_color "$SERVER_INFO")"
    [ "$TITLE_INFO" != "N/A" ] && log_info "Título: $TITLE_INFO"

    # SSH Banner
    if grep -q "22/tcp.*ABERTA" "${pasta}/portas.txt" 2>/dev/null; then
        log_info "Capturando banner SSH..."
        ssh_banner=$(timeout 3 bash -c "exec 3<>/dev/tcp/${ip}/22 2>/dev/null; cat <&3" 2>/dev/null | head -1)
        if [ -z "$ssh_banner" ]; then
            ssh_banner=$(timeout 3 nc -vn "$ip" 22 2>&1 | grep -i "SSH" | head -1 | sed 's/^.*SSH/SSH/')
        fi
        [ -z "$ssh_banner" ] && ssh_banner="Timeout"
        SSH_BANNER="$ssh_banner"
        echo "✅ Porta 22 (SSH)" >> "$banner_file"
        echo "   Banner: $ssh_banner" >> "$banner_file"
        log_success "SSH: $SSH_BANNER"
    fi

    # FTP Banner
    if grep -q "21/tcp.*ABERTA" "${pasta}/portas.txt" 2>/dev/null; then
        log_info "Capturando banner FTP..."
        ftp_banner=$(timeout 3 bash -c "exec 3<>/dev/tcp/${ip}/21 2>/dev/null; cat <&3" 2>/dev/null | head -1)
        if [ -z "$ftp_banner" ]; then
            ftp_banner=$(timeout 3 nc -vn "$ip" 21 2>&1 | grep -i "220" | head -1)
        fi
        [ -z "$ftp_banner" ] && ftp_banner="Timeout"
        FTP_BANNER="$ftp_banner"
        echo "✅ Porta 21 (FTP)" >> "$banner_file"
        echo "   Banner: $ftp_banner" >> "$banner_file"
        log_success "FTP: $FTP_BANNER"
    fi

    # SSL Certificate
    if grep -q "443/tcp.*ABERTA" "${pasta}/portas.txt" 2>/dev/null; then
        log_info "Extraindo certificado SSL..."
        cert_data=$(timeout 5 openssl s_client -connect "${ip}:443" -servername "$ip" 2>/dev/null < /dev/null)
        if [ -n "$cert_data" ]; then
            echo "$cert_data" > "${pasta}/ssl_cert.txt"
            local parsed
            parsed=$(echo "$cert_data" | timeout 3 openssl x509 -text -noout 2>/dev/null)
            if [ -n "$parsed" ]; then
                echo "$parsed" >> "${pasta}/ssl_cert.txt"
                SSL_CN=$(echo "$parsed" | grep "Subject:" | grep -o 'CN = [^,]*' | sed 's/CN = //')
                SSL_ISSUER=$(echo "$parsed" | grep "Issuer:" | grep -o 'CN = [^,]*' | sed 's/CN = //' | head -1)
                local not_after
                not_after=$(echo "$parsed" | grep "Not After" | head -1 | sed 's/.*Not After : //')
                if [ -n "$not_after" ]; then
                    SSL_EXPIRY="$not_after"
                fi
                echo "🔒 SSL Certificate:" >> "$banner_file"
                echo "   Emissor: ${SSL_ISSUER:-N/A}" >> "$banner_file"
                echo "   CN: ${SSL_CN:-N/A}" >> "$banner_file"
                echo "   Expira: ${SSL_EXPIRY:-N/A}" >> "$banner_file"
                log_success "SSL: $SSL_ISSUER - Expira $SSL_EXPIRY"
            fi
        fi
    fi

    # Favicon Hash
    for proto in http https; do
        if grep -q "80/tcp.*ABERTA\|443/tcp.*ABERTA\|8080/tcp.*ABERTA\|8443/tcp.*ABERTA" "${pasta}/portas.txt" 2>/dev/null; then
            log_info "Baixando favicon.ico..."
            local favicon_data
            favicon_data=$(curl -k -s -L -m 3 "${proto}://${ip}/favicon.ico" 2>/dev/null)
            if [ -n "$favicon_data" ] && [ ${#favicon_data} -gt 100 ]; then
                local hash
                hash=$(echo "$favicon_data" | md5sum 2>/dev/null | cut -d' ' -f1)
                if [ -z "$hash" ]; then
                    hash=$(echo "$favicon_data" | openssl md5 2>/dev/null | awk '{print $NF}')
                fi
                if [ -n "$hash" ]; then
                    FAVICON_HASH="$hash"
                    echo "$favicon_data" > "${pasta}/favicon.ico"
                    echo "📁 Favicon Hash:" >> "$banner_file"
                    echo "   MD5: $hash" >> "$banner_file"
                    log_success "Favicon Hash: $hash"
                    break
                fi
            fi
        fi
    done

    export SERVER_INFO TITLE_INFO SSL_ISSUER SSL_EXPIRY SSL_CN SSH_BANNER FTP_BANNER FAVICON_HASH
    log_success "Banner grabbing concluído."
}
