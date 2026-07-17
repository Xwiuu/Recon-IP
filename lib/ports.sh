#!/bin/bash
# ports.sh - Scan de portas TCP com nc/nmap/fallback

scan_ports() {
    local ip=$1
    local pasta=$2
    local portas_file="${pasta}/portas.txt"
    local portas=("21" "22" "25" "80" "443" "3306" "8080" "8443" "9000" "8000" "5432" "6379" "27017")

    local ip_type
    ip_type=$(tipo_ip "$ip")
    local nmap_opts=""
    local nc_opts=""
    [ "$ip_type" = "IPv6" ] && nmap_opts="-6" && nc_opts="-6"

    log_info "Escaneando portas comuns em $ip ($ip_type)..."

    echo "SCAN DE PORTAS - $(date)" > "$portas_file"
    echo "--------------------------------" >> "$portas_file"

    for porta in "${portas[@]}"; do
        local status="FECHADA"

        # Tenta nmap (mais confiável)
        if command -v nmap &>/dev/null; then
            if nmap $nmap_opts -p "$porta" --host-timeout 2s "$ip" 2>/dev/null | grep -q "open"; then
                status="ABERTA"
            fi
        # Tenta nc (netcat)
        elif command -v nc &>/dev/null; then
            if nc $nc_opts -zv -w 2 "$ip" "$porta" 2>&1 | grep -q "succeeded\|open"; then
                status="ABERTA"
            fi
        # Fallback: /dev/tcp (funciona apenas IPv4, Linux/WSL)
        elif [ "$ip_type" = "IPv4" ] && timeout 2 bash -c "echo > /dev/tcp/${ip}/${porta}" 2>/dev/null; then
            status="ABERTA"
        fi

        case $porta in
            21) servico="FTP" ;;
            22) servico="SSH" ;;
            25) servico="SMTP" ;;
            80) servico="HTTP" ;;
            443) servico="HTTPS" ;;
            3306) servico="MySQL" ;;
            5432) servico="PostgreSQL" ;;
            6379) servico="Redis" ;;
            27017) servico="MongoDB" ;;
            8080) servico="HTTP-Alt" ;;
            8443) servico="HTTPS-Alt" ;;
            8000) servico="HTTP-Alt2" ;;
            9000) servico="PHP-FPM" ;;
            *) servico="Desconhecido" ;;
        esac

        local line="${porta}/tcp (${servico}) - ${status}"
        if [ "$status" = "ABERTA" ]; then
            echo "✅ $line"
        else
            echo "❌ $line"
        fi
        echo "$line" >> "$portas_file"
    done

    log_success "Scan de portas concluído. Salvou em $portas_file"
}

# ========== SCAN DE PORTAS UDP ==========
scan_udp_ports() {
    local ip=$1
    local pasta=$2
    local udp_file="${pasta}/portas_udp.txt"
    local portas_udp=("53" "123" "161" "162" "514" "520" "12345")

    log_info "Escaneando portas UDP em $ip..."
    echo "=== PORTAS UDP ===" > "$udp_file"

    for porta in "${portas_udp[@]}"; do
        if command -v nmap &>/dev/null; then
            if nmap -sU -p "$porta" --host-timeout 2s "$ip" 2>/dev/null | grep -q "open"; then
                echo "${porta}/udp - ABERTA" >> "$udp_file"
                echo "${porta}/udp - ABERTA"
            else
                echo "${porta}/udp - FECHADA" >> "$udp_file"
            fi
        elif command -v nc &>/dev/null; then
            echo "${porta}/udp - N/A (nc nao suporta UDP scan)" >> "$udp_file"
        else
            echo "${porta}/udp - N/A (ferramenta nao disponivel)" >> "$udp_file"
        fi
    done

    log_success "Scan de portas UDP concluido. Salvou em $udp_file"
}
