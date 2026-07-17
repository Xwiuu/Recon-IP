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

# Valida se é IPv4 ou IPv6 válido
validar_ip() {
    local ip=$1
    # IPv4
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        for octeto in $(echo "$ip" | tr '.' ' '); do
            [ "$octeto" -gt 255 ] && return 1
        done
        return 0
    fi
    # IPv6 (presença de : com dígitos hexa)
    if [[ $ip =~ ^[0-9a-fA-F:]+$ ]]; then
        return 0
    fi
    return 1
}

tipo_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "IPv4"
    else
        echo "IPv6"
    fi
}

# Formata data/hora para ISO 8601
formatar_data() {
    date +"%Y-%m-%d %H:%M:%S %Z"
}

# Cria a pasta de recon para um IP e retorna o caminho
criar_pasta_recon() {
    local ip=$1
    local safe_ip=$(echo "$ip" | sed 's/:/_/g' | sed 's/%/_/g')
    local pasta="output/recon_${safe_ip}"
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

    local ip_type
    ip_type=$(tipo_ip "$ip")
    export IP_TYPE="$ip_type"

    local start_time=$SECONDS

    log_info "Iniciando scan para IP: $ip ($ip_type)"
    local pasta=$(criar_pasta_recon "$ip")
    log_success "Pasta criada: $pasta"

    local has_domain=0
    [ -n "$dominio" ] && has_domain=1

    if [ "$has_domain" -eq 1 ]; then
        init_progress "GeoIP" "IPInfo" "CEP" "Clima" "Portas" "UDP" "Banners" "CVE" "Whois" "DNS" "WHOIS Dom" "Subdominios" "RobotsTXT" "AXFR" "EmailSec" "HttpHeaders" "VulnTests" "SSLTest" "Rede" "ReverseIP" "ReverseDNS" "Ping" "StreetView" "Contatos" "Pwned" "RedesSociais" "Dorks" "theHarvester" "Earth" "KMZ" "Relatorio" "PDF" "Export" "Extra" "Resumo" "Notificacao"
    else
        init_progress "GeoIP" "IPInfo" "CEP" "Clima" "Portas" "UDP" "Banners" "CVE" "Whois" "HttpHeaders" "VulnTests" "SSLTest" "Rede" "ReverseIP" "ReverseDNS" "Ping" "StreetView" "Contatos" "Pwned" "RedesSociais" "Dorks" "Earth" "KMZ" "Relatorio" "PDF" "Export" "Extra" "Resumo" "Notificacao"
    fi

    update_progress 1 "GeoIP..."
    geo_lookup "$ip" "$pasta"
    [ $? -ne 0 ] && log_error "Geo falhou, continuando mesmo assim..."

    update_progress 2 "IPInfo..."
    buscar_ipinfo "$ip" "$pasta"

    update_progress 3 "CEP..."
    if [ -n "${ZIP:-}" ] && [ "${ZIP}" != "N/A" ] && [ "${ZIP}" != "null" ]; then
        query_cep "$ZIP" "$pasta"
    else
        log_debug "Sem CEP disponivel. Pulando."
    fi

    update_progress 4 "Clima..."
    get_weather "$LAT" "$LON" "$pasta"

    update_progress 5 "Portas TCP..."
    scan_ports "$ip" "$pasta"

    update_progress 6 "Portas UDP..."
    scan_udp_ports "$ip" "$pasta"

    scan_advanced_nmap "$ip" "$pasta"

    update_progress 7 "Banners..."
    grab_banner "$ip" "$pasta"

    update_progress 8 "CVE..."
    if [ -n "${SERVER_INFO:-}" ] && [ "$SERVER_INFO" != "N/A" ]; then
        local parsed
        parsed=$(parse_server_info "$SERVER_INFO")
        local sw=$(echo "$parsed" | cut -d'|' -f1)
        local ver=$(echo "$parsed" | cut -d'|' -f2)
        check_cves "$sw" "$ver" "$pasta"
    else
        check_cves "N/A" "" "$pasta"
    fi

    update_progress 9 "Whois..."
    whois_lookup "$ip" "$pasta"

    # Soh executa se tivermos dominio
    if [ "$has_domain" -eq 1 ]; then
        update_progress 10 "DNS..."
        dns_extras "$dominio" "$pasta"

        update_progress 11 "WHOIS Dom..."
        whois_domain "$dominio" "$pasta"

        update_progress 12 "Subdominios..."
        enumerate_subdomains "$dominio" "$pasta"

        update_progress 13 "RobotsTXT..."
        check_robots "$ip" "$dominio" "$pasta"
    fi

    if [ "$has_domain" -eq 1 ]; then
        update_progress 14 "AXFR..."
        test_axfr "$dominio" "$pasta"

        update_progress 15 "EmailSec..."
        check_email_security "$dominio" "$pasta"

        update_progress 16 "HttpHeaders..."
        check_security_headers "$ip" "$dominio" "$pasta"

        update_progress 17 "VulnTests..."
        run_vuln_tests "$ip" "$dominio" "$pasta"

        update_progress 18 "SSLTest..."
        test_ssl_protocols "$ip" "$dominio" "$pasta"
    else
        update_progress 10 "HttpHeaders..."
        check_security_headers "$ip" "$dominio" "$pasta"

        update_progress 11 "VulnTests..."
        run_vuln_tests "$ip" "$dominio" "$pasta"

        update_progress 12 "SSLTest..."
        test_ssl_protocols "$ip" "$dominio" "$pasta"
    fi

    # Ajusta o indice do progresso com base em has_domain
    local step_net=13
    local step_reverse=14
    local step_reverse_dns=15
    local step_ping=16
    local step_street=17
    local step_contacts=18
    local step_pwned=19
    local step_social=20
    local step_dorks=21
    local step_earth=22
    local step_kmz=23
    local step_report=24
    local step_pdf=25
    local step_export=26
    local step_export_extra=27
    local step_resumo=28
    local step_notify=29
    if [ "$has_domain" -eq 1 ]; then
        step_net=19
        step_reverse=20
        step_reverse_dns=21
        step_ping=22
        step_street=23
        step_contacts=24
        step_pwned=25
        step_social=26
        step_dorks=27
        step_harvester=28
        step_earth=29
        step_kmz=30
        step_report=31
        step_pdf=32
        step_export=33
        step_export_extra=34
        step_resumo=35
        step_notify=36
    fi

    if [ "$ip_type" = "IPv6" ]; then
        update_progress $step_net "Rede..."
        log_info "Scan de rede /24 nao suportado para IPv6, pulando..."
        VIZINHOS_COUNT="N/A"; VIZINHOS_LIST="N/A"
        TRACEROUTE_HOPS="N/A"; DOMAIN_CREATED="N/A"; DOMAIN_ADMIN="N/A"; DOMAIN_REGISTRAR="N/A"
    else
        update_progress $step_net "Rede..."
        network_recon "$ip" "$pasta" "$dominio"

        update_progress $step_reverse "Reverse IP..."
        reverse_ip_lookup "$ip" "$pasta"

        update_progress $step_reverse_dns "Reverse DNS..."
        reverse_dns_lookup "$ip" "$pasta"
    fi

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

    update_progress $step_ping "Ping..."
    ping_ip "$ip" "$pasta"
    if [ "$has_domain" -eq 1 ]; then
        ping_domain "$dominio" "$pasta"
        check_https "$dominio" "$pasta"
    fi

    update_progress $step_street "StreetView..."
    get_streetview "$LAT" "$LON" "$pasta"

    update_progress $step_contacts "Contatos..."
    extract_contacts "$dominio" "$ip" "$pasta"

    update_progress $step_pwned "Pwned..."
    if [ -n "${EMAIL:-}" ] && [ "${EMAIL}" != "N/A" ] && [ "${EMAIL}" != "null" ]; then
        check_pwned "$EMAIL" "$pasta"
    else
        log_debug "Nenhum email encontrado para verificar vazamentos."
    fi

    update_progress $step_social "Redes Sociais..."
    [ "$has_domain" -eq 1 ] && extract_social "$dominio" "$pasta"

    update_progress $step_dorks "Dorks..."
    generate_dorks "$ip" "$dominio" "$pasta"

    if [ "$has_domain" -eq 1 ]; then
        update_progress $step_harvester "theHarvester..."
        run_harvester "$dominio" "$pasta"
    fi

    update_progress $step_earth "Google Earth..."
    generate_kml "$ip" "$LAT" "$LON" "$pasta"
    open_google_earth "$LAT" "$LON"

    update_progress $step_kmz "KMZ..."

    [ -n "${SHODAN_API_KEY:-}" ] && query_shodan "$ip" "$pasta"
    [ -n "${CENSYS_API_ID:-}" ] && query_censys "$ip" "$pasta"
    [ "$MODO_MONITOR_ATIVO" -eq 1 ] && check_monitor "$ip" "$pasta"

    update_progress $step_report "Relatorio..."
    gerar_relatorio "$ip" "$pasta"

    update_progress $step_pdf "PDF..."
    generate_pdf "$pasta"

    update_progress $step_export "Exportando..."
    export_json "$ip" "$pasta"
    export_csv "$ip" "$pasta"

    update_progress $step_export_extra "Extra..."
    export_markdown "$ip" "$pasta"
    export_geojson "$ip" "$pasta"

    update_progress $step_resumo "Resumo..."
    local cve_count
    cve_count=$(grep -c "^CVE:" "${pasta}/cves.txt" 2>/dev/null || echo "0")

    local udp_ports
    udp_ports=$(grep "ABERTA" "${pasta}/portas_udp.txt" 2>/dev/null | grep -oP '\d+/udp' | paste -sd ',' -)

    cat > "$pasta/resumo.txt" <<EOF
IP: $ip
Tipo: $ip_type
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
Ping Dominio: ${DOMAIN_PING:-N/A}
Servidor Web: ${SERVER_INFO:-N/A}
Titulo: ${TITLE_INFO:-N/A}
SSL: ${SSL_ISSUER:-N/A} - ${SSL_EXPIRY:-N/A}
Favicon Hash: ${FAVICON_HASH:-N/A}
Vizinhos /24: ${VIZINHOS_COUNT:-N/A}
Dominio: ${dominio:-N/A}
DNS IPv4: ${DNS_IPV4:-N/A}
DNS IPv6: ${DNS_IPV6:-N/A}
HTTPS: ${HTTPS_STATUS:-N/A}
UDP Abertas: ${udp_ports:-N/A}
CVEs Encontrados: ${cve_count:-0}
Subdominios: ${SUBDOMAIN_COUNT:-0}
PTR: ${PTR_RECORD:-N/A}
TLS 1.0: ${SSL_TLS10:-N/A}
TLS 1.1: ${SSL_TLS11:-N/A}
TLS 1.2: ${SSL_TLS12:-N/A}
TLS 1.3: ${SSL_TLS13:-N/A}
POODLE: ${SSL_POODLE:-N/A}
BEAST: ${SSL_BEAST:-N/A}
CRIME: ${SSL_CRIME:-N/A}
Cifras Fracas: ${SSL_WEAK_CIPHERS:-N/A}
Log4j: ${LOG4J_VULN:-N/A}
Heartbleed: ${HEARTBLEED_VULN:-N/A}
Shellshock: ${SHELLSHOCK_VULN:-N/A}
SSH: ${SSH_WEAK:-N/A}
SPF: ${EMAIL_SPOOFABLE:-N/A}
DMARC: ${EMAIL_DMARC:-N/A}
Robots Disallow: ${ROBOTS_DISALLOW:-N/A}
CEP Logradouro: ${CEP_LOGRADOURO:-N/A}
CEP Bairro: ${CEP_BAIRRO:-N/A}
CEP Cidade: ${CEP_CIDADE:-N/A}
CEP Estado: ${CEP_ESTADO:-N/A}
Vazamentos (Pwned): ${PWNED_COUNT:-0} - ${PWNED_BREACHES:-N/A}
theHarvester Emails: ${HARVESTER_EMAILS:-N/A}
EOF

    update_progress $step_notify "Notificacao..."
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

# ========== DNS RESOLVER (prioriza IPv4, fallback IPv6) ==========
resolve_dns() {
    local url=$1
    url=$(echo "$url" | sed -E 's|https?://||' | sed 's|/.*||' | sed 's|:.*||')

    local ip4=""
    local ip6=""

    if command -v dig &>/dev/null; then
        ip4=$(dig +short -4 "$url" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n1)
        [ -z "$ip4" ] && ip6=$(dig +short -6 "$url" 2>/dev/null | grep -E '^[0-9a-fA-F:]+$' | head -n1)
    elif command -v host &>/dev/null; then
        ip4=$(host -t A "$url" 2>/dev/null | grep 'has address' | head -n1 | awk '{print $NF}')
        [ -z "$ip4" ] && ip6=$(host -t AAAA "$url" 2>/dev/null | grep 'has IPv6 address' | head -n1 | awk '{print $NF}')
    elif command -v nslookup &>/dev/null; then
        ip4=$(nslookup "$url" 2>/dev/null | grep -E '^Address' | grep -v '#' | awk '{print $NF}' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n1)
        [ -z "$ip4" ] && ip6=$(nslookup "$url" 2>/dev/null | grep -E '^Address' | grep -v '#' | awk '{print $NF}' | grep -E '^[0-9a-fA-F:]+$' | head -n1)
    fi

    # Prioriza IPv4
    if [ -n "$ip4" ]; then
        echo "$ip4"
    elif [ -n "$ip6" ]; then
        echo "$ip6"
    else
        echo ""
    fi
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
    mac=$(echo "$mac" | tr '[:lower:]' '[:upper:]' | tr -d ':-' | sed 's/\(..\)/\1:/g;s/:$//')

    local fabricante=$(curl -s -m 3 "https://api.macvendors.com/$mac" 2>/dev/null)
    if [ -n "$fabricante" ] && ! echo "$fabricante" | grep -qi "not found"; then
        echo "$fabricante"
        return
    fi

    case "${mac:0:8}" in
        "00:1A:2B") echo "Ayecom Technology Co., Ltd." ;;
        "00:11:22") echo "Apple Inc." ;;
        "00:23:DF") echo "Cisco Systems, Inc." ;;
        "00:24:36") echo "Dell Inc." ;;
        "00:25:9C") echo "HP Inc." ;;
        "00:1C:B3") echo "Microsoft Corporation" ;;
        "00:50:56") echo "VMware, Inc." ;;
        *) echo "Fabricante não encontrado (MAC inválido ou API offline)" ;;
    esac
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

# ========== PING (IPv4 e IPv6) ==========
ping_ip() {
    local ip=$1
    local pasta=$2
    local ip_type
    ip_type=$(tipo_ip "$ip")

    if command -v ping &>/dev/null; then
        local ping_cmd="ping"
        local ping_args="-c 1 -W 1"
        [ "$ip_type" = "IPv6" ] && ping_args="-c 1 -W 1 -6"

        local ping_result=$($ping_cmd $ping_args "$ip" 2>/dev/null | grep -oE 'time=[0-9.]+ ms' | head -1)
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
