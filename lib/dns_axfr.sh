#!/bin/bash
# dns_axfr.sh - Testa se o servidor DNS permite transferencia de zona (AXFR)

test_axfr() {
    local dominio=$1
    local pasta=$2
    local axfr_file="${pasta}/axfr.txt"

    log_info "Testando transferencia de zona (AXFR) para $dominio..."

    if command -v dig &>/dev/null; then
        ns_servers=$(dig +short NS "$dominio" | head -3)
    elif command -v host &>/dev/null; then
        ns_servers=$(host -t NS "$dominio" | grep 'name server' | awk '{print $NF}' | head -3)
    else
        echo "AXFR: Ferramentas DNS nao disponiveis." > "$axfr_file"
        return
    fi

    if [ -z "$ns_servers" ]; then
        echo "AXFR: Nenhum servidor NS encontrado." > "$axfr_file"
        return
    fi

    echo "=== TESTE DE TRANSFERENCIA DE ZONA (AXFR) ===" > "$axfr_file"

    for ns in $ns_servers; do
        if command -v dig &>/dev/null; then
            resultado=$(dig @$ns AXFR "$dominio" +short 2>/dev/null)
            if [ -n "$resultado" ]; then
                echo "$ns: PERMITE TRANSFERENCIA (VULNERAVEL!)" >> "$axfr_file"
                echo "$resultado" | head -20 >> "$axfr_file"
                log_warning "$ns: Transferencia de zona permitida!"
                return
            else
                echo "$ns: NAO permite transferencia" >> "$axfr_file"
            fi
        else
            echo "$ns: Nao foi possivel testar (dig nao disponivel)" >> "$axfr_file"
        fi
    done

    echo "Nenhum servidor vulneravel a AXFR." >> "$axfr_file"
    log_success "Teste AXFR concluido."
}
