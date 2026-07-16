#!/bin/bash
# report.sh - Gera relatório HTML a partir dos dados coletados

gerar_relatorio() {
    local ip=$1
    local pasta=$2

    log_info "Gerando relatório HTML..."

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
        </div>
        <div class="card">
            <h3>🌤️ Clima</h3>
            <p>${CLIMA:-Indisponível}</p>
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

    <div class="grid">
        <div class="card">
            <h3>📡 Latência</h3>
            <p><strong>Ping:</strong> ${PING:-Indisponível}</p>
        </div>
        <div class="card">
            <h3>⚠️ Reputação</h3>
            <p><strong>Abuse Score:</strong> ${ABUSE_SCORE:-N/A}</p>
            <p><strong>Total Reports:</strong> ${ABUSE_REPORTS:-N/A}</p>
            <p><strong>Último Report:</strong> ${ABUSE_LAST:-N/A}</p>
        </div>
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
