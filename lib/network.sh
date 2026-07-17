#!/bin/bash
# network.sh - Reconhecimento de Rede (/24 Scan, Traceroute, Whois Dominio)

network_recon() {
    local ip=$1
    local pasta=$2
    local dominio=$3

    VIZINHOS_COUNT=0
    VIZINHOS_LIST="N/A"
    TRACEROUTE_HOPS="N/A"
    DOMAIN_CREATED="N/A"
    DOMAIN_ADMIN="N/A"
    DOMAIN_REGISTRAR="N/A"
    DOMAIN_WHOIS_RAW=""

    local net_file="${pasta}/network.txt"
    echo "=== RECONHECIMENTO DE REDE ===" > "$net_file"
    echo "IP: $ip" >> "$net_file"
    echo "Dominio: ${dominio:-N/A}" >> "$net_file"
    echo "Data: $(date)" >> "$net_file"
    echo "--------------------------------" >> "$net_file"

    # /24 Scan (ping sweep)
    log_info "Escaneando rede /24 em busca de vizinhos..."
    local prefix
    prefix=$(echo "$ip" | awk -F. '{print $1"."$2"."$3}')
    local host_count=0
    local hosts=""

    echo "✅ Scan de Rede /24:" >> "$net_file"
    echo "   Prefixo: ${prefix}.0/24" >> "$net_file"
    echo "   Hosts vivos:" >> "$net_file"

    for i in $(seq 1 254); do
        local target="${prefix}.${i}"
        if ping -c 1 -W 1 "$target" 2>/dev/null | grep -q "time="; then
            host_count=$((host_count + 1))
            hosts="${hosts}${target}\n"
            printf "   - %s\n" "$target" >> "$net_file"
            log_success "Vizinho vivo: $target"
        fi
        if [ $((i % 64)) -eq 0 ]; then
            log_info "  Scan /24: $i/254 hosts verificados..."
        fi
    done

    VIZINHOS_COUNT=$host_count
    VIZINHOS_LIST=$(echo -e "$hosts" | head -50)
    echo "   Total: ${host_count} hosts vivos" >> "$net_file"

    if [ "$host_count" -gt 0 ]; then
        log_success "Scan /24 concluido: $host_count hosts vivos encontrados"
    else
        log_info "Nenhum vizinho encontrado no /24 (pode ser esperado para IPs publicos)"
    fi

    # Traceroute
    log_info "Executando traceroute..."
    local trace_result=""
    if command -v traceroute &>/dev/null; then
        trace_result=$(traceroute -n -w 1 -m 20 "$ip" 2>/dev/null)
    elif command -v mtr &>/dev/null; then
        trace_result=$(mtr --report -c 1 -n "$ip" 2>/dev/null)
    elif command -v tracert &>/dev/null; then
        trace_result=$(tracert -d -h 20 "$ip" 2>/dev/null)
    fi

    echo -e "\n✅ Traceroute:" >> "$net_file"
    if [ -n "$trace_result" ]; then
        echo "$trace_result" > "${pasta}/traceroute.txt"
        echo "$trace_result" >> "$net_file"
        TRACEROUTE_HOPS=$(echo "$trace_result" | head -30)
        local hop_count
        hop_count=$(echo "$trace_result" | grep -cE '^[[:space:]]*[0-9]')
        log_success "Traceroute: $hop_count hops ate o destino"
    else
        echo "   Traceroute: Indisponivel (comando nao encontrado)" >> "$net_file"
        TRACEROUTE_HOPS="Indisponivel"
        log_warning "Traceroute: comando nao disponivel"
    fi

    # Whois de Dominio (pula se ja foi feito pelo whois_domain.sh)
    if [ -n "$dominio" ] && [ "${DOMAIN_WHOIS_DONE:-0}" -ne 1 ]; then
        log_info "Consultando WHOIS do dominio ${dominio}..."
        local dwhois
        dwhois=$(whois "$dominio" 2>/dev/null)
        if [ -n "$dwhois" ]; then
            echo "$dwhois" > "${pasta}/domain_whois.txt"
            DOMAIN_WHOIS_RAW="$dwhois"
            echo -e "\n✅ Whois do Dominio:" >> "$net_file"

            DOMAIN_CREATED=$(echo "$dwhois" | grep -i "creation date" | head -1 | sed 's/.*: *//')
            DOMAIN_ADMIN=$(echo "$dwhois" | grep -i "admin name\|admin name\|person" | head -1 | sed 's/.*: *//')
            DOMAIN_REGISTRAR=$(echo "$dwhois" | grep -i "registrar:" | head -1 | sed 's/.*: *//')

            echo "   Dominio: $dominio" >> "$net_file"
            echo "   Criado em: ${DOMAIN_CREATED:-N/A}" >> "$net_file"
            echo "   Administrador: ${DOMAIN_ADMIN:-N/A}" >> "$net_file"
            echo "   Registro: ${DOMAIN_REGISTRAR:-N/A}" >> "$net_file"

            [ -n "$DOMAIN_CREATED" ] && log_success "Dominio criado em: $DOMAIN_CREATED"
            [ -n "$DOMAIN_ADMIN" ] && log_success "Admin: $DOMAIN_ADMIN"
        else
            log_warning "Falha ao consultar WHOIS do dominio"
        fi
    fi
    
    export VIZINHOS_COUNT VIZINHOS_LIST TRACEROUTE_HOPS
    export DOMAIN_CREATED DOMAIN_ADMIN DOMAIN_REGISTRAR DOMAIN_WHOIS_RAW
    log_success "Reconhecimento de rede concluido."
}

# ========== REVERSE IP LOOKUP ==========
reverse_ip_lookup() {
    local ip=$1
    local pasta=$2
    local rev_file="${pasta}/reverse_ip.txt"

    log_info "Buscando dominios no mesmo IP..."

    if command -v curl &>/dev/null; then
        curl -s "https://api.hackertarget.com/reverseiplookup/?q=${ip}" -o "$rev_file"
    else
        echo "Reverse IP: Indisponivel" > "$rev_file"
        return
    fi

    if [ -s "$rev_file" ]; then
        log_success "Reverse IP concluido."
    else
        echo "Nenhum dominio encontrado." > "$rev_file"
    fi
}
