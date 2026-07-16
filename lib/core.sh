#!/bin/bash
# core.sh - Funções utilitárias para o SUPERRECON v2.0

# Cores para output
RED='\033[1;31m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
MAGENTA='\033[1;35m'
NC='\033[0m' # No Color

# Variaveis globais de progresso
PROGRESS_STEPS=0
PROGRESS_CURRENT=0
PROGRESS_LABELS=()
PROGRESS_BAR_SIZE=20

init_progress() {
    PROGRESS_CURRENT=0
    PROGRESS_LABELS=("$@")
    PROGRESS_STEPS=${#PROGRESS_LABELS[@]}
    draw_progress 0 "${PROGRESS_LABELS[0]}"
}

draw_progress() {
    local pct=$1
    local label=$2
    local filled=$((pct * PROGRESS_BAR_SIZE / 100))
    local empty=$((PROGRESS_BAR_SIZE - filled))
    local bar="["
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    bar+="]"
    printf "\r  ${CYAN}%s${NC} ${GREEN}%3d%%${NC} ${BLUE}%s${NC}    " "$bar" "$pct" "$label"
}

update_progress() {
    local step=$1
    local label=$2
    PROGRESS_CURRENT=$step
    local pct=$((step * 100 / PROGRESS_STEPS))
    draw_progress "$pct" "$label"
}

finish_progress() {
    draw_progress 100 "Concluido"
    echo
}

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

# ========== PROCESSAR IP (SCAN COMPLETO) ==========
processar_ip() {
    local ip=$1
    local dominio=${2:-}
    if ! validar_ip "$ip"; then
        log_error "IP invalido: $ip"
        return 1
    fi

    local start_time=$SECONDS

    log_info "Iniciando scan para IP: $ip"
    local pasta=$(criar_pasta_recon "$ip")
    log_success "Pasta criada: $pasta"

    init_progress "GeoIP" "IPInfo" "Clima" "Portas" "Banners" "Whois" "Telemetria" "Rede" "Ping" "StreetView" "Reputacao" "Relatorio" "Resumo" "Notificacao"
    update_progress 1 "GeoIP..."
    geo_lookup "$ip" "$pasta"
    [ $? -ne 0 ] && log_error "Geo falhou, continuando mesmo assim..."

    update_progress 2 "IPInfo..."
    buscar_ipinfo "$ip" "$pasta"

    update_progress 3 "Clima..."
    get_weather "$LAT" "$LON" "$pasta"

    update_progress 4 "Portas..."
    scan_ports "$ip" "$pasta"

    update_progress 5 "Banners..."
    grab_banner "$ip" "$pasta"

    update_progress 6 "Whois..."
    whois_lookup "$ip" "$pasta"

    update_progress 7 "Telemetria..."
    check_telemetry "$ip" "$pasta" "$dominio"

    update_progress 8 "Rede..."
    network_recon "$ip" "$pasta" "$dominio"

    # Fallback ASN do whois_api.json (se geo.json nao tiver)
    if [ "${ASN:-N/A}" = "N/A" ] && [ -f "${pasta}/whois_api.json" ]; then
        local asn_whois
        asn_whois=$(jq -r '.asn // .as // empty' "${pasta}/whois_api.json" 2>/dev/null)
        if [ -n "$asn_whois" ]; then
            ASN="$asn_whois"
            export ASN
            log_success "ASN obtido do WHOIS API: $ASN"
        fi
    fi

    update_progress 9 "Ping..."
    ping_ip "$ip" "$pasta"

    update_progress 10 "StreetView..."
    get_streetview "$LAT" "$LON" "$pasta"

    update_progress 11 "Reputacao..."
    check_reputation "$ip" "$pasta"

    update_progress 12 "Relatorio..."
    gerar_relatorio "$ip" "$pasta"

    update_progress 13 "Resumo..."
    cat > "$pasta/resumo.txt" <<EOF
IP: $ip
Data: $(formatar_data)
Cidade: $CITY
Regiao: $REGION
Pais: $COUNTRY
ISP: $ISP
Coordenadas: $LAT, $LON
Clima: $CLIMA
Hostname: ${HOSTNAME:-N/A}
ASN: ${ASN:-N/A}
Rede: ${REDE:-N/A}
Ping: ${PING:-N/A}
Servidor Web: ${SERVER_INFO:-N/A}
Titulo: ${TITLE_INFO:-N/A}
SSL: ${SSL_ISSUER:-N/A} - ${SSL_EXPIRY:-N/A}
Favicon Hash: ${FAVICON_HASH:-N/A}
Safe Browsing: ${SAFEBROWSING_MALICIOUS:-N/A}
DNSBL: ${DNSBL_LISTED:-N/A}
VirusTotal: ${VT_MALICIOUS:-N/A}/${VT_TOTAL:-N/A}
Vizinhos /24: ${VIZINHOS_COUNT:-N/A}
Abuse Score: ${ABUSE_SCORE:-N/A}
Abuse Reports: ${ABUSE_REPORTS:-N/A}
EOF

    update_progress 14 "Notificacao..."
    send_notifications "$ip" "$pasta"

    finish_progress

    local elapsed=$((SECONDS - start_time))
    local elapsed_fmt
    if [ "$elapsed" -lt 60 ]; then
        elapsed_fmt="${elapsed}s"
    else
        elapsed_fmt="$((elapsed / 60))m $((elapsed % 60))s"
    fi

    echo
    log_success "Scan finalizado em ${elapsed_fmt}! Resumo salvo em $pasta/resumo.txt"
    log_success "Arquivos gerados:"
    ls -la "$pasta"
}

# ========== DNS RESOLVER ==========
resolve_dns() {
    local url=$1
    url=$(echo "$url" | sed -E 's|https?://||' | sed 's|/.*||' | sed 's|:.*||')

    local ip=""
    if command -v dig &>/dev/null; then
        ip=$(dig +short "$url" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n1)
    elif command -v host &>/dev/null; then
        ip=$(host "$url" 2>/dev/null | grep 'has address' | head -n1 | awk '{print $NF}')
    elif command -v nslookup &>/dev/null; then
        ip=$(nslookup "$url" 2>/dev/null | grep -E '^Address' | tail -n1 | awk '{print $NF}')
    fi

    echo "$ip"
}

# ========== MAC ADDRESS ==========
validar_mac() {
    local mac=$1
    if echo "$mac" | grep -qiE '^([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}$'; then
        return 0
    fi
    if echo "$mac" | grep -qiE '^[0-9A-Fa-f]{12}$'; then
        return 0
    fi
    return 1
}

consulta_mac() {
    local mac=$1
    if echo "$mac" | grep -qE '^[0-9A-Fa-f]{12}$'; then
        mac=$(echo "$mac" | sed 's/\(..\)/\1:/g;s/:$//')
    elif echo "$mac" | grep -q '-'; then
        mac=$(echo "$mac" | tr '-' ':')
    fi

    local fabricante=$(curl -s "https://api.macvendors.com/$mac" 2>/dev/null)
    if [ -n "$fabricante" ] && ! echo "$fabricante" | grep -qi '"error\|"errors\|not found'; then
        echo "$fabricante"
    else
        echo "Fabricante nao encontrado ou MAC invalido"
    fi
}

# ========== BUSCA DADOS EXTRAS (IPINFO.IO) ==========
buscar_ipinfo() {
    local ip=$1
    local pasta=$2
    local info_file="${pasta}/geo.json"

    if [ ! -f "$info_file" ] || [ ! -s "$info_file" ]; then
        log_info "Baixando dados extras de ipinfo.io..."
        curl -s "https://ipinfo.io/${ip}/json" -o "$info_file"
    fi

    if [ -f "$info_file" ] && [ -s "$info_file" ]; then
        TELEFONE=$(jq -r '.phone // "N/A"' "$info_file" 2>/dev/null)
        EMAIL=$(jq -r '.email // "N/A"' "$info_file" 2>/dev/null)
        REDE=$(jq -r '.org // "N/A"' "$info_file" 2>/dev/null)
        ASN=$(jq -r '.asn.name // .asn.asn // .as // "N/A"' "$info_file" 2>/dev/null)
        HOSTNAME=$(jq -r '.hostname // "N/A"' "$info_file" 2>/dev/null)
        export TELEFONE EMAIL REDE ASN HOSTNAME
        log_success "Dados extras: Rede=$REDE | ASN=$ASN"
    else
        log_warning "Falha ao buscar dados extras."
        TELEFONE="N/A"; EMAIL="N/A"; REDE="N/A"; ASN="N/A"; HOSTNAME="N/A"
        export TELEFONE EMAIL REDE ASN HOSTNAME
    fi
}

# ========== PING ==========
ping_ip() {
    local ip=$1
    local pasta=$2
    if command -v ping &>/dev/null; then
        local ping_result=$(ping -c 1 -W 1 "$ip" 2>/dev/null | grep -oE 'time=[0-9.]+ ms' | head -1)
        if [ -n "$ping_result" ]; then
            PING="$ping_result"
            log_success "Ping: $PING"
        else
            PING="Indisponivel"
            log_warning "Ping: Sem resposta"
        fi
    else
        PING="Indisponivel (sem ping)"
        log_warning "Ping: comando nao disponivel"
    fi
    export PING
}

# ========== VERIFICA CONEXAO COM INTERNET ==========
tem_internet() {
    ping -c 1 -W 2 8.8.8.8 &>/dev/null && return 0
    ping -c 1 -W 2 1.1.1.1 &>/dev/null && return 0
    curl -s --head --connect-timeout 3 http://www.google.com &>/dev/null && return 0
    return 1
}

# ========== EXECUTA COM FALLBACK LOCAL ==========
tentar_api_ou_local() {
    local nome=$1
    local func_api=$2
    local func_local=$3
    shift 3

    if tem_internet; then
        if $func_api "$@" 2>/dev/null; then
            return 0
        fi
        log_warning "API $nome falhou. Tentando fallback local..."
    else
        log_warning "Sem internet. Usando fallback local para $nome..."
    fi

    if $func_local "$@" 2>/dev/null; then
        log_success "Fallback local $nome executado com sucesso."
        return 0
    fi

    log_error "Falha total em $nome (online e local)."
    return 1
}

# ========== VERIFICA DEPENDENCIAS ==========
check_deps() {
    local missing=()
    for dep in curl jq; do
        if ! command -v "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done
    if [ ${#missing[@]} -gt 0 ]; then
        echo "Dependencias faltando: ${missing[*]}"
        return 1
    fi
    return 0
}
