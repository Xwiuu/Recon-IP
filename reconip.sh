#!/bin/bash
# ReconIP v2.0 - TUI OSINT Reconnaissance Tool (Terminal Puro)

source config.env 2>/dev/null || {
    echo -e "\033[1;31m[!] config.env nao encontrado! Copie config.env.example.\033[0m"
    exit 1
}

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

# Garante que jq esta no PATH (Windows via winget)
if ! command -v jq &>/dev/null; then
    _jq_dir="$(cd "$(dirname "$APPDATA")/Local/Microsoft/WinGet/Packages/jqlang.jq_Microsoft.Winget.Source_8wekyb3d8bbwe" 2>/dev/null && pwd)"
    [ -n "$_jq_dir" ] && export PATH="$PATH:$_jq_dir"
fi

# ========== CORES ==========
RED='\033[1;31m'; GREEN='\033[1;32m'; CYAN='\033[1;36m'
YELLOW='\033[1;33m'; BLUE='\033[1;34m'; NC='\033[0m'
BOLD='\033[1m'

# ========== TUI LIMPA ==========
clear_screen() {
    printf "\033[2J\033[H"
}

# ========== BANNER ==========
exibir_banner() {
    if [ -f assets/banner.txt ]; then
        cat assets/banner.txt
    else
        echo -e "${CYAN}====================================${NC}"
        echo -e "${GREEN}    ReconIP v2.0 - OSINT Tool${NC}"
        echo -e "${CYAN}====================================${NC}"
    fi
    echo
}

# ========== MENU ==========
menu_principal() {
    echo -e " ${CYAN}[1]${NC} Scan por IP"
    echo -e " ${CYAN}[2]${NC} Scan por URL (DNS)"
    echo -e " ${CYAN}[3]${NC} Scan por MAC"
    echo -e " ${CYAN}[4]${NC} Modo Link (Tuneis)"
    echo -e " ${CYAN}[5]${NC} Sair"
    echo
    printf "  Escolha (1-5): "
}

# ========== OPCOES ==========
opcao_scan_ip() {
    echo
    local ip
    printf "  Digite o IP: "
    read -r ip
    [ -z "$ip" ] && return
    if ! validar_ip "$ip"; then
        echo -e "  ${RED}IP invalido!${NC}"
        sleep 1
        return
    fi
    processar_ip "$ip"
    echo -e "  ${GREEN}Scan concluido! Relatorio: output/recon_$ip/report.html${NC}"
    printf "  Pressione Enter para continuar..."
    read -r
}

opcao_scan_url() {
    echo
    local url
    printf "  Digite a URL (ex: google.com): "
    read -r url
    [ -z "$url" ] && return
    local ip
    ip=$(resolve_dns "$url")
    if [ -z "$ip" ]; then
        echo -e "  ${RED}Falha ao resolver DNS.${NC}"
        sleep 1
        return
    fi
    echo -e "  ${GREEN}DNS resolvido: $ip${NC}"
    processar_ip "$ip" "$url"
    echo -e "  ${GREEN}Scan concluido! Relatorio: output/recon_$ip/report.html${NC}"
    printf "  Pressione Enter para continuar..."
    read -r
}

opcao_scan_mac() {
    echo
    local mac
    printf "  Digite o MAC (ex: AA:BB:CC:DD:EE:FF): "
    read -r mac
    [ -z "$mac" ] && return
    if ! validar_mac "$mac"; then
        echo -e "  ${RED}MAC invalido!${NC}"
        sleep 1
        return
    fi
    local fabricante
    fabricante=$(consulta_mac "$mac")
    echo -e "  ${GREEN}Fabricante: $fabricante${NC}"
    printf "  Pressione Enter para continuar..."
    read -r
}

opcao_modo_link() {
    echo
    if [ ! -f super_recon.sh ]; then
        echo -e "  ${RED}Arquivo super_recon.sh nao encontrado!${NC}"
        printf "  Pressione Enter para continuar..."
        read -r
        return
    fi
    echo -e "  ${YELLOW}Iniciando Modo Link...${NC}"
    ./super_recon.sh
}

# ========== HELP ==========
mostrar_help() {
    cat <<EOF
ReconIP v2.0 - TUI OSINT Reconnaissance Tool

Uso:
  ./reconip.sh              Modo TUI (menu interativo)
  ./reconip.sh -h           Mostra esta ajuda

Dependencias:
  curl, jq, whois

Modulos carregados de lib/:
  core.sh, geo.sh, ports.sh, weather.sh, whois.sh,
  streetview.sh, report.sh, tunnels.sh, notify.sh,
  banners.sh, network.sh
EOF
}

# ========== MAIN ==========
case "$1" in
    -h | --help)
        mostrar_help
        exit 0
        ;;
esac

check_deps
if [ $? -ne 0 ]; then
    echo -e "${YELLOW}[!] Algumas dependencias podem estar faltando.${NC}"
    sleep 1
fi

trap 'clear_screen; echo; echo -e "${GREEN}[+] Voltando ao menu...${NC}"; continue' INT

while true; do
    clear_screen
    exibir_banner
    menu_principal
    read -r opt
    case $opt in
        1) opcao_scan_ip ;;
        2) opcao_scan_url ;;
        3) opcao_scan_mac ;;
        4) opcao_modo_link ;;
        5) echo -e "\n  ${GREEN}Saindo...${NC}"; exit 0 ;;
        *) echo -e "  ${RED}Opcao invalida!${NC}"; sleep 1 ;;
    esac
done
