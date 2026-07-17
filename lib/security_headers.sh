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
        HSTS="Ausente"; CSP="Ausente"; XFO="Ausente"; XCTO="Ausente"; RP="Ausente"
        PERMISSIONS_POLICY="Ausente"; COEP="Ausente"; COOP="Ausente"; CORP="Ausente"
        CSP_ANALYSIS=""

        grep -i "strict-transport-security" "${pasta}/headers_raw.txt" > /dev/null && HSTS="Presente"
        grep -i "content-security-policy" "${pasta}/headers_raw.txt" > /dev/null && CSP="Presente"
        grep -i "x-frame-options" "${pasta}/headers_raw.txt" > /dev/null && XFO="Presente"
        grep -i "x-content-type-options" "${pasta}/headers_raw.txt" > /dev/null && XCTO="Presente"
        grep -i "referrer-policy" "${pasta}/headers_raw.txt" > /dev/null && RP="Presente"
        grep -i "permissions-policy" "${pasta}/headers_raw.txt" > /dev/null && PERMISSIONS_POLICY="Presente"
        grep -i "cross-origin-embedder-policy" "${pasta}/headers_raw.txt" > /dev/null && COEP="Presente"
        grep -i "cross-origin-opener-policy" "${pasta}/headers_raw.txt" > /dev/null && COOP="Presente"
        grep -i "cross-origin-resource-policy" "${pasta}/headers_raw.txt" > /dev/null && CORP="Presente"

        local csp_header=$(grep -ai "content-security-policy" "${pasta}/headers_raw.txt" | head -1 | sed 's/^[Cc]ontent-[Ss]ecurity-[Pp]olicy: //I' | sed 's/\r//')
        if [ -n "$csp_header" ]; then
            if echo "$csp_header" | grep -qi "default-src 'none'"; then
                CSP_ANALYSIS="Forte (default-src 'none')"
            elif echo "$csp_header" | grep -qi "default-src 'self'"; then
                CSP_ANALYSIS="Moderada (default-src 'self')"
            elif echo "$csp_header" | grep -qiE "unsafe-inline|unsafe-eval"; then
                CSP_ANALYSIS="FRACA - permite unsafe-inline/unsafe-eval"
            elif echo "$csp_header" | grep -qi "http://"; then
                CSP_ANALYSIS="ALERTA - permite conexoes HTTP nao seguras"
            else
                CSP_ANALYSIS="Presente (analise manual recomendada)"
            fi
        fi

        cat > "$headers_file" <<EOF
=== CABECALHOS DE SEGURANCA HTTP ===
HSTS (HTTP Strict Transport Security): $HSTS
CSP (Content Security Policy): $CSP
  => Analise CSP: ${CSP_ANALYSIS:-N/A}
X-Frame-Options: $XFO
X-Content-Type-Options: $XCTO
Referrer-Policy: $RP
Permissions-Policy: $PERMISSIONS_POLICY
Cross-Origin-Embedder-Policy: $COEP
Cross-Origin-Opener-Policy: $COOP
Cross-Origin-Resource-Policy: $CORP

--- HEADERS BRUTOS ---
$(cat "${pasta}/headers_raw.txt" 2>/dev/null)
EOF
        export HSTS CSP XFO XCTO RP PERMISSIONS_POLICY COEP COOP CORP CSP_ANALYSIS
        log_success "Analise de headers concluida."
    else
        echo "Analise de headers: curl nao disponivel." > "$headers_file"
    fi
}
