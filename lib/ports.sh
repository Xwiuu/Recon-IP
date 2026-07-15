#!/bin/bash
# ports.sh - Scan de portas TCP (rápido)

scan_ports() {
    local ip=$1
    local pasta=$2
    local portas_file="${pasta}/portas.txt"
    local portas=("21" "22" "25" "80" "443" "3306" "8080")

    log_info "Escaneando portas comuns em $ip..."

    echo "SCAN DE PORTAS - $(date)" > "$portas_file"
    echo "--------------------------------" >> "$portas_file"

    for porta in "${portas[@]}"; do
        if timeout 2 bash -c "echo > /dev/tcp/${ip}/${porta}" 2>/dev/null; then
            case $porta in
                21) servico="FTP" ;;
                22) servico="SSH" ;;
                25) servico="SMTP" ;;
                80) servico="HTTP" ;;
                443) servico="HTTPS" ;;
                3306) servico="MySQL" ;;
                8080) servico="HTTP-Alt" ;;
                *) servico="Desconhecido" ;;
            esac
            echo "${porta}/tcp (${servico}) - ABERTA" | tee -a "$portas_file"
        else
            echo "${porta}/tcp - FECHADA" >> "$portas_file"
        fi
    done

    log_success "Scan de portas concluído. Salvou em $portas_file"
}
