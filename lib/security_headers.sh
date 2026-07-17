#!/bin/bash
# security_headers.sh - Analisa cabecalhos de seguranca HTTP

check_security_headers() {
    local ip=$1
    local dominio=$2
    local pasta=$3
    local headers_file="${pasta}/security_headers.txt"
    local port=80
    local proto="http"

    if grep -q "443/tcp.*ABERTA" "${pasta}/portas.txt" 2>/dev/null; then
        proto="https"
        port=443
    elif grep -q "80/tcp.*ABERTA" "${pasta}/portas.txt" 2>/dev/null; then
        proto="http"
        port=80
    else
        echo "Nenhuma porta HTTP/HTTPS aberta." > "$headers_file"
        return
    fi

    log_info "Analisando cabecalhos de seguranca HTTP..."

    if command -v curl &>/dev/null; then
        if [ -n "$dominio" ] && [ "$dominio" != "N/A" ]; then
            url="${proto}://${dominio}:${port}"
        else
            url="${proto}://${ip}:${port}"
        fi

        curl -s -I -L "$url" 2>/dev/null > "${pasta}/headers_raw.txt"
        grep -i "strict-transport-security" "${pasta}/headers_raw.txt" > /dev/null && HSTS="Presente" || HSTS="Ausente"
        grep -i "content-security-policy" "${pasta}/headers_raw.txt" > /dev/null && CSP="Presente" || CSP="Ausente"
        grep -i "x-frame-options" "${pasta}/headers_raw.txt" > /dev/null && XFO="Presente" || XFO="Ausente"
        grep -i "x-content-type-options" "${pasta}/headers_raw.txt" > /dev/null && XCTO="Presente" || XCTO="Ausente"
        grep -i "referrer-policy" "${pasta}/headers_raw.txt" > /dev/null && RP="Presente" || RP="Ausente"

        cat > "$headers_file" <<EOF
=== CABECALHOS DE SEGURANCA HTTP ===
HSTS (HTTP Strict Transport Security): $HSTS
CSP (Content Security Policy): $CSP
X-Frame-Options: $XFO
X-Content-Type-Options: $XCTO
Referrer-Policy: $RP
EOF
        log_success "Analise de headers concluida."
    else
        echo "Analise de headers: curl nao disponivel." > "$headers_file"
    fi
}
