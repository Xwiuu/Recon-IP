#!/bin/bash
# report.sh - Gera relatório HTML a partir dos dados coletados

gerar_relatorio() {
    local ip=$1
    local pasta=$2

    log_info "Gerando relatório HTML..."
    local ip_type
    ip_type=$(tipo_ip "$ip")

    local vizinhos_text
    if [ "${IP_TYPE}" = "IPv6" ]; then
        vizinhos_text="N/A (IPv6)"
    elif [ -z "${VIZINHOS_COUNT}" ] || [ "${VIZINHOS_COUNT}" = "N/A" ]; then
        vizinhos_text="N/A"
    elif [ "${VIZINHOS_COUNT}" -eq 0 ] 2>/dev/null; then
        vizinhos_text="Nenhum host vivo encontrado"
    else
        vizinhos_text="${VIZINHOS_COUNT} hosts encontrados"
    fi

    cat > "${pasta}/report.html" <<EOF
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Recon - ${ip}</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Segoe UI', Arial, sans-serif; background: #0d1117; color: #c9d1d9; padding: 20px; }
        .container { max-width: 1000px; margin: auto; background: #161b22; padding: 30px; border-radius: 16px; border: 1px solid #30363d; }
        h1 { color: #58a6ff; font-size: 28px; margin-bottom: 10px; display: flex; align-items: center; gap: 10px; }
        .badge { background: #21262d; padding: 6px 14px; border-radius: 20px; display: inline-block; margin: 5px 5px 5px 0; font-size: 14px; border: 1px solid #30363d; }
        .badge-green { border-color: #2ea043; color: #3fb950; }
        .badge-blue { border-color: #58a6ff; color: #58a6ff; }
        .badge-red { border-color: #da3633; color: #f85149; }
        .badge-purple { border-color: #bc8cff; color: #bc8cff; }
        .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; margin: 20px 0; }
        .card { background: #0d1117; padding: 18px; border-radius: 12px; border: 1px solid #30363d; }
        .card h3 { color: #f0f6fc; margin-bottom: 12px; font-size: 18px; border-bottom: 1px solid #30363d; padding-bottom: 8px; }
        .map { width: 100%; height: 400px; border: 0; border-radius: 12px; margin: 15px 0; }
        .street-img { width: 100%; max-height: 350px; object-fit: cover; border-radius: 12px; border: 1px solid #30363d; }
        .port-table { width: 100%; border-collapse: collapse; }
        .port-table td { padding: 8px; border-bottom: 1px solid #21262d; }
        .port-open { color: #3fb950; font-weight: bold; }
        .port-closed { color: #f85149; }
        pre { background: #0d1117; padding: 12px; border-radius: 8px; overflow-x: auto; font-size: 13px; max-height: 200px; }
        .footer { margin-top: 30px; padding-top: 15px; border-top: 1px solid #30363d; color: #8b949e; font-size: 13px; text-align: center; }
        a { color: #58a6ff; text-decoration: none; }
        a:hover { text-decoration: underline; }
        @media (max-width: 768px) { .grid { grid-template-columns: 1fr; } }
    </style>
</head>
<body>
<div class="container">
    <h1>🕵️ ReconIP v2.0 — Relatório de IP</h1>
    <div>
        <span class="badge badge-blue">🌐 ${ip}</span>
        <span class="badge badge-purple">📡 ${ip_type}</span>
        <span class="badge badge-green">📅 $(formatar_data)</span>
    </div>

    <div class="grid">
        <div class="card">
            <h3>📍 Localização</h3>
            <p><strong>Cidade:</strong> ${CITY:-N/A}</p>
            <p><strong>Região:</strong> ${REGION:-N/A}</p>
            <p><strong>País:</strong> ${COUNTRY:-N/A}</p>
            <p><strong>ISP:</strong> ${ISP:-N/A}</p>
            <p><strong>Rede:</strong> ${REDE:-N/A}</p>
            <p><strong>ASN:</strong> ${ASN:-N/A}</p>
            <p><strong>Hostname:</strong> ${HOSTNAME:-N/A}</p>
            <p><strong>Telefone:</strong> ${TELEFONE:-N/A}</p>
            <p><strong>E-mail:</strong> ${EMAIL:-N/A}</p>
            <p><strong>Coordenadas:</strong> ${LAT:-N/A}, ${LON:-N/A}</p>
            <p><strong>Fuso:</strong> ${TIMEZONE:-N/A}</p>
            <p><strong>CEP:</strong> ${ZIP:-N/A}</p>
            $(if [ "${CEP_LOGRADOURO:-N/A}" != "N/A" ]; then echo "<p><strong>Endereço:</strong> ${CEP_LOGRADOURO}, ${CEP_BAIRRO}, ${CEP_CIDADE}/${CEP_ESTADO}</p><p><strong>DDD:</strong> ${CEP_DDD:-N/A}</p>"; fi)
        </div>
        <div class="card">
            <h3>🌤️ Clima</h3>
            <p>${CLIMA:-Indisponível}</p>
            <p><strong>${CLIMA_DIA1:-}</strong></p>
            <p><strong>${CLIMA_DIA2:-}</strong></p>
            <p><strong>${CLIMA_DIA3:-}</strong></p>
        </div>
    </div>

    <div class="card">
        <h3>🗺️ Mapa Interativo</h3>
        <iframe class="map" src="${LINK_MAPS_EMBED:-https://maps.google.com/maps?q=${LAT:-0},${LON:-0}&z=15&output=embed}" allowfullscreen></iframe>
        <p><a href="${LINK_MAPS_NAV:-#}" target="_blank">🔗 Abrir no Google Maps (nova aba)</a></p>
    </div>

    <div class="card">
        <h3>🏙️ Street View</h3>
        <img class="street-img" src="street.jpg" onerror="this.src='data:image/svg+xml,%3Csvg xmlns=%22http://www.w3.org/2000/svg%22 width=%22600%22 height=%22300%22%3E%3Crect fill=%22%23161b22%22 width=%22600%22 height=%22300%22/%3E%3Ctext fill=%22%2358a6ff%22 x=%22300%22 y=%22140%22 text-anchor=%22middle%22 font-family=%22Arial%22 font-size=%2220%22%3E🌍 Street View%3C/text%3E%3Ctext fill=%22%238b949e%22 x=%22300%22 y=%22170%22 text-anchor=%22middle%22 font-family=%22Arial%22 font-size=%2214%22%3EIndisponível no momento%3C/text%3E%3Ctext fill=%22%2330363d%22 x=%22300%22 y=%22200%22 text-anchor=%22middle%22 font-family=%22Arial%22 font-size=%2212%22%3EConfigure sua chave no config.env%3C/text%3E%3C/svg%3E'" alt="Street View">
        <p><a href="${LINK_STREET:-#}" target="_blank">🔗 Ver no Google Street View 360°</a></p>
    </div>

    <div class="card">
        <h3>📞 Contatos (Emails/Telefones)</h3>
        <pre>$(cat "${pasta}/contacts.txt" 2>/dev/null || echo "N/A")</pre>
    </div>

    <div class="card">
        <h3>🌐 Redes Sociais</h3>
        <pre>$(cat "${pasta}/social.txt" 2>/dev/null || echo "N/A")</pre>
    </div>

    $(if [ -f "${pasta}/pwned.txt" ] && [ -s "${pasta}/pwned.txt" ] && ! grep -q "N/A" "${pasta}/pwned.txt"; then cat <<PWNED
    <div class="card">
        <h3>🔓 Vazamentos (Have I Been Pwned)</h3>
        <pre>$(head -10 "${pasta}/pwned.txt" 2>/dev/null)</pre>
    </div>
PWNED
    fi)

    <div class="card">
        <h3>🔍 Google Dorks</h3>
        <pre>$(head -40 "${pasta}/dorks.txt" 2>/dev/null || echo "N/A")</pre>
    </div>

    $(if [ -f "${pasta}/harvester.txt" ] && [ -s "${pasta}/harvester.txt" ] && ! grep -q "N/A" "${pasta}/harvester.txt"; then cat <<HARV
    <div class="card">
        <h3>🌾 theHarvester OSINT</h3>
        <pre>$(cat "${pasta}/harvester.txt" 2>/dev/null)</pre>
    </div>
HARV
    fi)

    <div class="card">
        <h3>🌍 Google Earth / Maps</h3>
        <p><strong>KML:</strong> <a href="location.kml">Baixar KML</a></p>
        <p><strong>KMZ:</strong> <a href="location.kmz">Baixar KMZ (compactado)</a></p>
        <p><strong>GeoJSON:</strong> <a href="report.geojson">Baixar GeoJSON</a></p>
        <p><strong>Markdown:</strong> <a href="report.md">Baixar Relatório MD</a></p>
        <p><strong>Google Earth:</strong> <a href="${GOOGLE_EARTH_URL:-#}" target="_blank">Abrir no Google Earth Web</a></p>
    </div>
EOF

    # Banner Grabbing (só exibe se houver dados)
    if [ -n "${SERVER_INFO}" ] && [ "${SERVER_INFO}" != "N/A" ] || \
       [ -n "${TITLE_INFO}" ] && [ "${TITLE_INFO}" != "N/A" ] || \
       [ -n "${SSL_ISSUER}" ] && [ "${SSL_ISSUER}" != "N/A" ] || \
       [ -n "${SSL_EXPIRY}" ] && [ "${SSL_EXPIRY}" != "N/A" ] || \
       [ -n "${SSL_CN}" ] && [ "${SSL_CN}" != "N/A" ] || \
       [ -n "${SSH_BANNER}" ] && [ "${SSH_BANNER}" != "N/A" ] || \
       [ -n "${FTP_BANNER}" ] && [ "${FTP_BANNER}" != "N/A" ] || \
       [ -n "${FAVICON_HASH}" ] && [ "${FAVICON_HASH}" != "N/A" ]; then
        cat >> "${pasta}/report.html" <<EOF
    <div class="card">
        <h3>🌐 Banner Grabbing</h3>
        <p><strong>Servidor:</strong> ${SERVER_INFO:-N/A}</p>
        <p><strong>Título:</strong> ${TITLE_INFO:-N/A}</p>
        <p><strong>SSL Emissor:</strong> ${SSL_ISSUER:-N/A}</p>
        <p><strong>SSL Expira:</strong> ${SSL_EXPIRY:-N/A}</p>
        <p><strong>SSL CN:</strong> ${SSL_CN:-N/A}</p>
        <p><strong>SSH Banner:</strong> <code>${SSH_BANNER:-N/A}</code></p>
        <p><strong>FTP Banner:</strong> <code>${FTP_BANNER:-N/A}</code></p>
        <p><strong>Favicon Hash:</strong> <code>${FAVICON_HASH:-N/A}</code></p>
    </div>
EOF
    fi

    # DNS Records card (só se houver dados de dominio)
    if [ -n "${DNS_IPV4}" ] && [ "${DNS_IPV4}" != "N/A" ]; then
        cat >> "${pasta}/report.html" <<EOF
    <div class="card">
        <h3>📡 Registros DNS</h3>
        <p><strong>IPv4:</strong> ${DNS_IPV4}</p>
        <p><strong>IPv6:</strong> ${DNS_IPV6:-N/A}</p>
        <p><strong>MX:</strong> ${DNS_MX:-N/A}</p>
        <p><strong>TXT:</strong> ${DNS_TXT:-N/A}</p>
        <p><strong>NS:</strong> ${DNS_NS:-N/A}</p>
        <p><strong>SOA:</strong> ${DNS_SOA:-N/A}</p>
    </div>
EOF
    fi

    cat >> "${pasta}/report.html" <<EOF
    <div class="card">
        <h3>📡 Latência</h3>
        <p><strong>Ping:</strong> ${PING:-Indisponível}</p>
    </div>
EOF

    if [ -n "${HTTPS_STATUS}" ] && [ "${HTTPS_STATUS}" != "N/A" ]; then
        cat >> "${pasta}/report.html" <<EOF
    <div class="card">
        <h3>🔒 Segurança HTTPS</h3>
        <p><strong>Status:</strong> ${HTTPS_STATUS}</p>
        <p><strong>Servidor:</strong> ${HTTPS_SERVER:-N/A}</p>
        <p><strong>Certificado Válido:</strong> ${HTTPS_CERT_VALID:-N/A}</p>
        <p><strong>Subject:</strong> ${HTTPS_CERT_SUBJECT:-N/A}</p>
        <p><strong>Emissor:</strong> ${HTTPS_CERT_ISSUER:-N/A}</p>
        <p><strong>Válido de:</strong> ${HTTPS_CERT_START:-N/A}</p>
        <p><strong>Válido até:</strong> ${HTTPS_CERT_END:-N/A}</p>
    </div>
EOF
    fi

    cat >> "${pasta}/report.html" <<EOF
    <div class="card">
        <h3>🗺️ Reconhecimento de Rede</h3>
        <p><strong>Vizinhos /24:</strong> ${vizinhos_text}</p>
        <pre>${VIZINHOS_LIST:-N/A}</pre>
        <p><strong>Traceroute:</strong></p>
        <pre>${TRACEROUTE_HOPS:-N/A}</pre>
        $(if [ -n "${dominio:-}" ]; then echo "<p><strong>Domínio:</strong> ${dominio}</p>"; fi)
        <p><strong>Criado em:</strong> ${DOMAIN_CREATED:-N/A}</p>
        <p><strong>Expira em:</strong> ${DOMAIN_EXPIRY:-N/A}</p>
        <p><strong>Registrante:</strong> ${DOMAIN_ADMIN:-N/A}</p>
        <p><strong>Registrar:</strong> ${DOMAIN_REGISTRAR:-N/A}</p>
        <p><strong>Servidores NS:</strong> ${DOMAIN_NS_WHOIS:-N/A}</p>
        <p><strong>Status:</strong> ${DOMAIN_STATUS:-N/A}</p>
        <p><strong>Ping Domínio:</strong> ${DOMAIN_PING:-N/A}</p>
    </div>

    <div class="card">
        <h3>🚪 Scan de Portas</h3>
        <table class="port-table">
$(cat "${pasta}/portas.txt" 2>/dev/null | while read linha; do
    if echo "$linha" | grep -q "ABERTA"; then
        echo "<tr><td><span class='port-open'>✅</span> ${linha}</td></tr>"
    elif echo "$linha" | grep -q "FECHADA"; then
        echo "<tr><td><span class='port-closed'>❌</span> ${linha}</td></tr>"
    elif echo "$linha" | grep -q "SCAN"; then
        echo "<tr><td><em>${linha}</em></td></tr>"
    else
        echo "<tr><td>${linha}</td></tr>"
    fi
done)
        </table>
    </div>

    <div class="card">
        <h3>📋 WHOIS (primeiras 20 linhas)</h3>
        <pre>$(head -n 20 "${pasta}/whois.txt" 2>/dev/null || echo "WHOIS não disponível")</pre>
    </div>

    <div class="card">
        <h3>🌐 Transferência de Zona (AXFR)</h3>
        <pre>$(cat "${pasta}/axfr.txt" 2>/dev/null || echo "N/A")</pre>
    </div>

    <div class="card">
        <h3>🛡️ Cabeçalhos de Segurança HTTP</h3>
        <pre>$(cat "${pasta}/security_headers.txt" 2>/dev/null || echo "N/A")</pre>
    </div>

    <div class="card">
        <h3>📧 Segurança de E-mail (SPF/DKIM/DMARC)</h3>
        <pre>$(cat "${pasta}/email_security.txt" 2>/dev/null || echo "N/A")</pre>
    </div>

    $(if [ -n "${SUBDOMAIN_COUNT}" ] && [ "${SUBDOMAIN_COUNT}" -gt 0 ] 2>/dev/null; then
    cat <<SUB
    <div class="card">
        <h3>🌐 Subdomínios Encontrados (${SUBDOMAIN_COUNT})</h3>
        <pre>${SUBDOMAIN_LIST:-Nenhum}</pre>
    </div>
SUB
    fi)

    $(if [ -n "${ROBOTS_DISALLOW}" ] && [ "${ROBOTS_DISALLOW}" != "N/A" ]; then
    cat <<ROB
    <div class="card">
        <h3>🤖 robots.txt Analysis</h3>
        <p><strong>Disallow:</strong> ${ROBOTS_DISALLOW}</p>
        <p><strong>Sitemap:</strong> ${ROBOTS_SITEMAP:-N/A}</p>
        <p><strong>URLs no Sitemap:</strong> ${SITEMAP_COUNT:-0}</p>
        <pre>$(head -c 1000 "${pasta}/robots_raw.txt" 2>/dev/null || echo "N/A")</pre>
    </div>
ROB
    fi)

    $(if { [ -n "${LOG4J_VULN}" ] && [ "${LOG4J_VULN}" != "N/A" ] && [ "${LOG4J_VULN}" != "Nao testado" ]; } || \
       { [ -n "${HEARTBLEED_VULN}" ] && [ "${HEARTBLEED_VULN}" != "N/A" ] && [ "${HEARTBLEED_VULN}" != "Nao testado" ]; } || \
       { [ -n "${SHELLSHOCK_VULN}" ] && [ "${SHELLSHOCK_VULN}" != "N/A" ] && [ "${SHELLSHOCK_VULN}" != "Nao testado" ]; } || \
       { [ -n "${SSH_WEAK}" ] && [ "${SSH_WEAK}" != "N/A" ] && [ "${SSH_WEAK}" != "Nao testado" ]; }; then
    cat <<VULN
    <div class="card">
        <h3>💥 Testes de Vulnerabilidade</h3>
        <p><strong>Log4j (CVE-2021-44228):</strong> ${LOG4J_VULN:-N/A}</p>
        <p><strong>Heartbleed (CVE-2014-0160):</strong> ${HEARTBLEED_VULN:-N/A}</p>
        <p><strong>Shellshock (CVE-2014-6271):</strong> ${SHELLSHOCK_VULN:-N/A}</p>
        <p><strong>SSH Weak Ciphers:</strong> ${SSH_WEAK:-N/A}</p>
    </div>
VULN
    fi)

    $(if { [ -n "${SSL_TLS10}" ] && [ "${SSL_TLS10}" != "N/A" ]; } || \
       { [ -n "${SSL_TLS11}" ] && [ "${SSL_TLS11}" != "N/A" ]; } || \
       { [ -n "${SSL_TLS12}" ] && [ "${SSL_TLS12}" != "N/A" ]; }; then
    cat <<SSL
    <div class="card">
        <h3>🔐 Teste SSL/TLS</h3>
        <p><strong>TLS 1.0:</strong> <span class="$(echo "${SSL_TLS10}" | grep -qi "inseguro" && echo "badge-red" || echo "badge-green")">${SSL_TLS10}</span></p>
        <p><strong>TLS 1.1:</strong> <span class="$(echo "${SSL_TLS11}" | grep -qi "inseguro" && echo "badge-red" || echo "badge-green")">${SSL_TLS11}</span></p>
        <p><strong>TLS 1.2:</strong> ${SSL_TLS12}</p>
        <p><strong>TLS 1.3:</strong> ${SSL_TLS13}</p>
        <p><strong>POODLE:</strong> <span class="$(echo "${SSL_POODLE}" | grep -qi "vulneravel" && echo "badge-red" || echo "badge-green")">${SSL_POODLE}</span></p>
        <p><strong>BEAST:</strong> <span class="$(echo "${SSL_BEAST}" | grep -qi "vulneravel" && echo "badge-red" || echo "badge-green")">${SSL_BEAST}</span></p>
        <p><strong>CRIME:</strong> <span class="$(echo "${SSL_CRIME}" | grep -qi "vulneravel" && echo "badge-red" || echo "badge-green")">${SSL_CRIME}</span></p>
        <p><strong>Cifras Fracas:</strong> ${SSL_WEAK_CIPHERS}</p>
    </div>
SSL
    fi)

    $(if [ -n "${PTR_RECORD}" ] && [ "${PTR_RECORD}" != "N/A" ]; then
    cat <<PTR
    <div class="card">
        <h3>🔍 Reverse DNS (PTR)</h3>
        <p><strong>Nome do Host:</strong> ${PTR_RECORD}</p>
    </div>
PTR
    fi)

    $(if [ -n "${SHODAN_DATA}" ] && [ "${SHODAN_DATA}" != "N/A" ]; then
    cat <<SHO
    <div class="card">
        <h3>🌍 Shodan Intelligence</h3>
        <pre>$(cat "${pasta}/shodan.txt" 2>/dev/null | head -20)</pre>
    </div>
SHO
    fi)

    $(if [ "${MONITOR_CHANGED:-0}" -eq 1 ]; then
    cat <<MON
    <div class="card">
        <h3>🔄 Monitoramento - Alterações Detectadas</h3>
        <pre>${MONITOR_CHANGES:-N/A}</pre>
    </div>
MON
    fi)

    <div class="footer">
        ⚙️ Gerado por ReconIP v2.0 em $(formatar_data)
    </div>
</div>
</body>
</html>
EOF

    log_success "Relatório HTML gerado em: ${pasta}/report.html"

    if command -v xdg-open &>/dev/null; then
        xdg-open "${pasta}/report.html" 2>/dev/null &
    elif command -v open &>/dev/null; then
        open "${pasta}/report.html" 2>/dev/null &
    elif command -v start &>/dev/null; then
        start "${pasta}/report.html" 2>/dev/null &
    else
        log_info "Abra manualmente: ${pasta}/report.html"
    fi
}

generate_pdf() {
    local pasta=$1
    local html_file="${pasta}/report.html"
    local pdf_file="${pasta}/report.pdf"

    PDF_GENERATED="N/A"

    if [ ! -f "$html_file" ]; then
        return
    fi

    if command -v pandoc &>/dev/null; then
        log_info "Gerando PDF com pandoc..."
        pandoc "$html_file" -o "$pdf_file" --pdf-engine=weasyprint 2>/dev/null || \
        pandoc "$html_file" -o "$pdf_file" --pdf-engine=wkhtmltopdf 2>/dev/null || \
        pandoc "$html_file" -o "$pdf_file" -f html -t pdf 2>/dev/null
        if [ -f "$pdf_file" ] && [ -s "$pdf_file" ]; then
            PDF_GENERATED="$pdf_file"
            log_success "PDF gerado: $pdf_file"
        else
            log_warning "Falha ao gerar PDF com pandoc"
        fi
    elif command -v wkhtmltopdf &>/dev/null; then
        log_info "Gerando PDF com wkhtmltopdf..."
        wkhtmltopdf "$html_file" "$pdf_file" 2>/dev/null
        if [ -f "$pdf_file" ] && [ -s "$pdf_file" ]; then
            PDF_GENERATED="$pdf_file"
            log_success "PDF gerado: $pdf_file"
        else
            log_warning "Falha ao gerar PDF com wkhtmltopdf"
        fi
    else
        log_info "PDF nao gerado (pandoc/wkhtmltopdf nao disponiveis)"
    fi

    export PDF_GENERATED
}
