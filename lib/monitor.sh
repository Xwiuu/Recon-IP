#!/bin/bash
# monitor.sh - Modo monitoramento (scan periodico com comparacao e notificacao)

MODO_MONITOR_ATIVO=0
MONITOR_DIR="output/monitor"

init_monitor() {
    MODO_MONITOR_ATIVO=1
    mkdir -p "$MONITOR_DIR"
}

check_monitor() {
    local ip=$1
    local pasta=$2
    local monitor_base="${MONITOR_DIR}/${ip}"

    mkdir -p "$monitor_base"

    local changed=0
    local changes=""

    log_info "Verificando alteracoes em relacao ao ultimo scan..."

    local current_snapshot="${pasta}/resumo.txt"
    local last_snapshot="${monitor_base}/last_resumo.txt"

    if [ -f "$last_snapshot" ]; then
        local diff_result
        diff_result=$(diff "$last_snapshot" "$current_snapshot" 2>/dev/null)

        if [ -n "$diff_result" ]; then
            changed=1
            changes="Alteracoes detectadas no scan de $(date):"$'\n'
            changes+="$(diff "$last_snapshot" "$current_snapshot" | head -30)"
            log_warning "Alteracoes detectadas no IP $ip!"
        else
            log_success "Nenhuma alteracao detectada para $ip."
        fi
    else
        log_info "Primeiro scan para $ip - snapshots salvos."
    fi

    cp "$current_snapshot" "$last_snapshot"
    cp "${pasta}/portas.txt" "${monitor_base}/last_portas.txt" 2>/dev/null
    cp "${pasta}/banners.txt" "${monitor_base}/last_banners.txt" 2>/dev/null

    if [ "$changed" -eq 1 ]; then
        local change_file="${pasta}/alteracoes.txt"
        echo "$changes" > "$change_file"
        log_warning "Alteracoes salvas em $change_file"

        if [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ]; then
            local msg="[MONITOR] IP ${ip} mudou!"
            msg+=$'\n\n'"${changes}"
            curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
                -d "chat_id=${TELEGRAM_CHAT_ID}" \
                -d "text=${msg}" \
                -d "parse_mode=HTML" &>/dev/null
        fi

        MONITOR_CHANGED=1
        MONITOR_CHANGES="$changes"
    else
        MONITOR_CHANGED=0
        MONITOR_CHANGES=""
    fi

    export MONITOR_CHANGED MONITOR_CHANGES
    log_success "Monitoramento concluido."
}

# ========== AGENDADOR CRON ==========
setup_cron() {
    local ip=$1
    local intervalo=$2
    local cron_file="output/monitor/cron_${ip}.sh"

    if [ -z "$intervalo" ]; then
        intervalo="*/6" # default: a cada 6 horas
    fi

    cat > "$cron_file" <<EOF
#!/bin/bash
cd "$(pwd)"
source config.env
source lib/core.sh
source lib/geo.sh
source lib/ports.sh
source lib/weather.sh
source lib/whois.sh
source lib/streetview.sh
source lib/report.sh
source lib/notify.sh
source lib/banners.sh
source lib/network.sh
source lib/dns.sh
source lib/whois_domain.sh
source lib/export.sh
source lib/cve.sh
source lib/dns_axfr.sh
source lib/security_headers.sh
source lib/email_security.sh
source lib/subdomains.sh
source lib/robots.sh
source lib/vuln_tests.sh
source lib/ssl_test.sh
source lib/shodan.sh
source lib/monitor.sh

init_monitor
processar_ip "$ip"
check_monitor "$ip" "output/recon_\$(echo '$ip' | sed 's/:/_/g')"

EOF

    chmod +x "$cron_file"
    log_success "Script cron gerado: $cron_file"

    local cron_job="${intervalo} * * * * ${cron_file}"
    echo ""
    echo "=============================================="
    echo "Para agendar no cron (Linux/Mac), adicione:"
    echo ""
    echo "  $cron_job"
    echo ""
    echo "No Windows, use o Agendador de Tarefas"
    echo "=============================================="
}
