#!/bin/bash
# core.sh - Funções utilitárias para o SUPERRECON v2.0

# Cores para output
RED='\033[1;31m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Valida se é um IPv4 válido
validar_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        # Verifica se cada octeto está entre 0 e 255
        for octeto in $(echo $ip | tr '.' ' '); do
            if [ $octeto -lt 0 ] || [ $octeto -gt 255 ]; then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

# Formata data/hora para ISO 8601
formatar_data() {
    date +"%Y-%m-%d %H:%M:%S %Z"
}

# Cria a pasta de recon para um IP e retorna o caminho
criar_pasta_recon() {
    local ip=$1
    local pasta="output/recon_${ip}"
    mkdir -p "$pasta"
    echo "$pasta"
}

# Log de debug (se DEBUG=1 no config.env)
log_debug() {
    if [ "${DEBUG:-0}" -eq 1 ]; then
        echo -e "${YELLOW}[DEBUG] $1${NC}"
    fi
}

# Exibe mensagem de sucesso
log_success() {
    echo -e "${GREEN}[+] $1${NC}"
}

# Exibe mensagem de erro
log_error() {
    echo -e "${RED}[!] $1${NC}" >&2
}

# Exibe mensagem de aviso
log_warning() {
    echo -e "${YELLOW}[!] $1${NC}"
}

# Exibe mensagem de info
log_info() {
    echo -e "${CYAN}[*] $1${NC}"
}
