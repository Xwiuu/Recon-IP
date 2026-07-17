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

# ========== REVERSE IP LOOKUP (MULTI-FONTE) ==========

reverse_ip_hackertarget() {
    local ip=$1
    curl -s -m 8 "https://api.hackertarget.com/reverseiplookup/?q=${ip}" 2>/dev/null
}

reverse_ip_viewdns() {
    local ip=$1
    local html
    html=$(curl -s -m 8 "https://viewdns.info/reverseip/?host=${ip}&t=1" 2>/dev/null)
    if [ -z "$html" ]; then return; fi
    echo "$html" | grep -oP '<td>\K[^<]+(?=</td>)' | grep -vE '^[0-9.]+$' | head -30
}

reverse_ip_yougetsignal() {
    local ip=$1
    local json
    json=$(curl -s -m 8 -H "User-Agent: Mozilla/5.0" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "remoteAddress=${ip}" \
        "https://yougetsignal.com/tools/web-sites-on-web-server/php/get_web_sites.php" 2>/dev/null)
    if [ -z "$json" ]; then return; fi
    echo "$json" | jq -r '.domainArray[][]' 2>/dev/null | grep -v '^null$' | grep -vE '^[0-9.]+$' | head -30
}

reverse_ip_lookup() {
    local ip=$1
    local pasta=$2
    local rev_file="${pasta}/reverse_ip.txt"
    local all_domains=""
    local total=0

    log_info "Buscando dominios no mesmo IP (3 fontes)..."

    # Fonte 1: hackertarget
    log_debug "Reverse IP: consultando hackertarget..."
    local ht_result
    ht_result=$(reverse_ip_hackertarget "$ip")
    if [ -n "$ht_result" ]; then
        all_domains+="$ht_result"$'\n'
    fi

    # Fonte 2: viewdns.info
    log_debug "Reverse IP: consultando viewdns.info..."
    local vd_result
    vd_result=$(reverse_ip_viewdns "$ip")
    if [ -n "$vd_result" ]; then
        all_domains+="$vd_result"$'\n'
    fi

    # Fonte 3: yougetsignal
    log_debug "Reverse IP: consultando yougetsignal..."
    local yg_result
    yg_result=$(reverse_ip_yougetsignal "$ip")
    if [ -n "$yg_result" ]; then
        all_domains+="$yg_result"$'\n'
    fi

    # Deduplica e limpa
    REVERSE_DOMAINS="N/A"
    if [ -n "$all_domains" ]; then
        local unique_domains
        unique_domains=$(echo "$all_domains" | tr ' ' '\n' | sed '/^$/d' | sort -u | grep -vE '^(N/A|n/a|None|none)$')

        local count
        count=$(echo "$unique_domains" | sed '/^$/d' | wc -l)
        if [ "$count" -gt 0 ]; then
            REVERSE_DOMAINS=$(echo "$unique_domains" | head -50)
            total=$count

            cat > "$rev_file" <<EOF
=== REVERSE IP LOOKUP ===
IP: $ip
Total de dominios unicos: $total
Fontes: hackertarget, viewdns.info, yougetsignal

Dominios:
${REVERSE_DOMAINS}
EOF

            log_success "Reverse IP: $total dominios unicos encontrados (3 fontes)"
            export REVERSE_DOMAINS
            return 0
        fi
    fi

    echo "Nenhum dominio encontrado nas 3 fontes." > "$rev_file"
    REVERSE_DOMAINS="N/A"
    export REVERSE_DOMAINS
    log_warning "Reverse IP: nenhum dominio encontrado."
    return 1
}

# ========== MTR ANALYSIS ==========
analyze_mtr() {
    local ip=$1
    local pasta=$2
    local mtr_file="${pasta}/mtr.txt"

    MTR_REPORT="N/A"
    MTR_SUMMARY="N/A"

    if ! command -v mtr &>/dev/null; then
        echo "MTR: comando nao disponivel (instale mtr ou mtr-tiny)" > "$mtr_file"
        export MTR_REPORT MTR_SUMMARY
        return 1
    fi

    log_info "Executando MTR (5 pacotes por hop)..."
    local mtr_out
    mtr_out=$(mtr --report -c 5 -n -w "$ip" 2>/dev/null)

    if [ -z "$mtr_out" ]; then
        log_warning "MTR: sem resultado"
        echo "MTR: sem resultado" > "$mtr_file"
        export MTR_REPORT MTR_SUMMARY
        return 1
    fi

    echo "$mtr_out" > "$mtr_file"
    MTR_REPORT="$mtr_out"

    # Gera sumario: total hops, perda no ultimo hop, latencia media
    local total_hops
    total_hops=$(echo "$mtr_out" | grep -cE '^\s+[0-9]+\.')
    local last_loss
    last_loss=$(echo "$mtr_out" | tail -1 | awk '{print $3}' | tr -d '%')
    local last_lat
    last_lat=$(echo "$mtr_out" | tail -1 | awk '{print $6}')

    MTR_SUMMARY="${total_hops} hops | Perda: ${last_loss:-0}% | Lat: ${last_lat:-N/A}"

    log_success "MTR: ${total_hops} hops ate o destino"
    export MTR_REPORT MTR_SUMMARY
    return 0
}
