#!/bin/bash
# tunnels.sh - Gerenciamento de túneis + encurtadores

# ========== VARIÁVEIS GLOBAIS ==========
TUNNEL_PIDS=()
declare -A TUNNEL_URLS

# ========== FUNÇÕES DE TÚNEIS ==========

start_cloudflared() {
    local port=$1
    local result_file=$2
    log_info "Iniciando Cloudflared tunnel..."
    cloudflared tunnel --url "http://localhost:${port}" &> cf.log &
    local pid=$!
    echo "$pid" >> "$result_file.pid"

    local timeout=20
    local count=0
    while [ $count -lt $timeout ]; do
        local url=$(grep -o 'https://[-a-zA-Z0-9.]*trycloudflare.com' cf.log 2>/dev/null | head -n1)
        if [ -n "$url" ]; then
            echo "$url" > "$result_file"
            log_success "Cloudflared: $url"
            return 0
        fi
        sleep 1
        ((count++))
    done
    log_error "Cloudflared timeout"
    return 1
}

start_ngrok() {
    local port=$1
    local result_file=$2
    log_info "Iniciando Ngrok tunnel..."
    ngrok http "$port" --log=stdout &> ngrok.log &
    local pid=$!
    echo "$pid" >> "$result_file.pid"

    local timeout=20
    local count=0
    while [ $count -lt $timeout ]; do
        local url=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | grep -o '"public_url":"[^"]*"' | head -n1 | cut -d '"' -f4)
        if [ -n "$url" ]; then
            echo "$url" > "$result_file"
            log_success "Ngrok: $url"
            return 0
        fi
        sleep 1
        ((count++))
    done
    log_error "Ngrok timeout"
    return 1
}

start_loclx() {
    local port=$1
    local result_file=$2
    if ! command -v loclx &> /dev/null; then
        log_warning "Loclx nao encontrado. Pulando..."
        return 1
    fi
    log_info "Iniciando Loclx tunnel..."
    loclx tunnel http --to "127.0.0.1:${port}" &> loclx.log &
    local pid=$!
    echo "$pid" >> "$result_file.pid"

    local timeout=20
    local count=0
    while [ $count -lt $timeout ]; do
        local url=$(grep -o 'https://[-a-zA-Z0-9.]*.loclx.io' loclx.log 2>/dev/null | head -n1)
        if [ -n "$url" ]; then
            echo "$url" > "$result_file"
            log_success "Loclx: $url"
            return 0
        fi
        sleep 1
        ((count++))
    done
    log_error "Loclx timeout"
    return 1
}

# ========== ENCURTADORES ==========

shorten_url() {
    local url=$1
    local service=$2

    case $service in
        tinyurl)
            curl -s "https://tinyurl.com/api-create.php?url=${url}"
            ;;
        isgd)
            curl -s "https://is.gd/create.php?format=simple&url=${url}"
            ;;
        *)
            echo "$url"
            ;;
    esac
}

# ========== GERENCIADOR PRINCIPAL ==========

start_all_tunnels() {
    local port=$1
    log_info "Iniciando todos os tuneis na porta $port..."

    local tmp_dir=$(mktemp -d 2>/dev/null || echo "tmp_tunnels")
    mkdir -p "$tmp_dir"

    start_cloudflared "$port" "$tmp_dir/cf" &
    start_ngrok "$port" "$tmp_dir/ngrok" &
    start_loclx "$port" "$tmp_dir/loclx" &

    wait

    for name in cloudflared ngrok loclx; do
        local short="${name:0:2}"
        local url_file="$tmp_dir/$short"
        local pid_file="$url_file.pid"
        if [ -f "$pid_file" ]; then
            TUNNEL_PIDS+=($(cat "$pid_file"))
        fi
        if [ -f "$url_file" ]; then
            TUNNEL_URLS[$name]=$(cat "$url_file")
        fi
    done

    rm -rf "$tmp_dir"

    echo -e "\n${GREEN}== LINKS GERADOS:${NC}"
    for tunnel in cloudflared ngrok loclx; do
        if [ -n "${TUNNEL_URLS[$tunnel]}" ]; then
            local url="${TUNNEL_URLS[$tunnel]}"
            local short_tiny=$(shorten_url "$url" tinyurl)
            local short_isgd=$(shorten_url "$url" isgd)
            echo -e "${CYAN}${tunnel}:${NC} $url"
            echo -e "   ${YELLOW}Encurtado (TinyURL):${NC} $short_tiny"
            echo -e "   ${YELLOW}Encurtado (is.gd):${NC} $short_isgd"
        else
            echo -e "${RED}${tunnel}: FALHOU${NC}"
        fi
    done
}

# ========== LIMPEZA ==========

_win_kill() {
    local pid=$1
    if kill "$pid" 2>/dev/null; then
        return 0
    fi
    if command -v taskkill &> /dev/null; then
        taskkill /F /PID "$pid" 2>/dev/null
    fi
}

_pkill_compat() {
    local name=$1
    if command -v pkill &> /dev/null; then
        pkill -f "$name" 2>/dev/null
    elif command -v taskkill &> /dev/null; then
        taskkill /F /IM "${name}.exe" 2>/dev/null
    fi
}

cleanup_tunnels() {
    log_info "Encerrando tuneis..."
    for pid in "${TUNNEL_PIDS[@]}"; do
        _win_kill "$pid"
    done
    _pkill_compat cloudflared
    _pkill_compat ngrok
    _pkill_compat loclx
    log_success "Tuneis encerrados."
}
