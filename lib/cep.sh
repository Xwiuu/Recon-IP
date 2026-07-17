#!/bin/bash
# cep.sh - Busca endereco completo via API ViaCEP

buscar_cep_por_ip() {
    local ip=$1
    local pasta=$2

    CEP_LOGRADOURO="N/A"
    CEP_BAIRRO="N/A"
    CEP_CIDADE="N/A"
    CEP_ESTADO="N/A"
    CEP_DDD="N/A"
    CEP_IBGE="N/A"

    # Tenta CEP do geo.json (ja extraido via ipinfo.io)
    local cep="${ZIP:-N/A}"
    if [ -n "$cep" ] && [ "$cep" != "N/A" ] && [ "$cep" != "null" ]; then
        if query_cep "$cep" "$pasta"; then
            ZIP="$cep"; export ZIP CEP_LOGRADOURO CEP_BAIRRO CEP_CIDADE CEP_ESTADO CEP_DDD CEP_IBGE
            return 0
        fi
    fi

    # Fallback: tenta ipinfo.io diretamente pelo campo postal
    if tem_internet; then
        log_info "Buscando CEP via ipinfo.io para $ip..."
        local geo_data
        geo_data=$(curl -s -m 5 "https://ipinfo.io/${ip}/json" 2>/dev/null)
        if [ -n "$geo_data" ]; then
            cep=$(echo "$geo_data" | jq -r '.postal // empty' 2>/dev/null)
            if [ -n "$cep" ]; then
                if query_cep "$cep" "$pasta"; then
                    ZIP="$cep"; export ZIP CEP_LOGRADOURO CEP_BAIRRO CEP_CIDADE CEP_ESTADO CEP_DDD CEP_IBGE
                    return 0
                fi
            fi
        fi
    fi

    log_debug "CEP nao disponivel para IP $ip"
    local cep_file="${pasta}/cep.txt"
    echo "CEP: N/A (indisponivel para este IP)" > "$cep_file"
    export CEP_LOGRADOURO CEP_BAIRRO CEP_CIDADE CEP_ESTADO CEP_DDD CEP_IBGE
    return 1
}

query_cep() {
    local cep=$1
    local pasta=$2
    local cep_file="${pasta}/cep.txt"

    CEP_LOGRADOURO="N/A"
    CEP_BAIRRO="N/A"
    CEP_CIDADE="N/A"
    CEP_ESTADO="N/A"
    CEP_DDD="N/A"
    CEP_IBGE="N/A"

    cep=$(echo "$cep" | sed 's/[^0-9]//g')
    if [ -z "$cep" ] || [ "${#cep}" -ne 8 ]; then
        log_debug "CEP invalido ou nao brasileiro: '$cep'"
        echo "CEP: N/A (formato invalido)" > "$cep_file"
        export CEP_LOGRADOURO CEP_BAIRRO CEP_CIDADE CEP_ESTADO CEP_DDD CEP_IBGE
        return 1
    fi

    log_info "Buscando CEP ${cep} via ViaCEP..."

    if ! tem_internet; then
        log_warning "Sem internet. CEP indisponivel."
        echo "CEP: N/A (sem internet)" > "$cep_file"
        export CEP_LOGRADOURO CEP_BAIRRO CEP_CIDADE CEP_ESTADO CEP_DDD CEP_IBGE
        return 1
    fi

    local viacep_data
    viacep_data=$(curl -s -m 5 "https://viacep.com.br/ws/${cep}/json/" 2>/dev/null)

    if [ -z "$viacep_data" ] || echo "$viacep_data" | grep -q '"erro"'; then
        log_warning "CEP ${cep} nao encontrado na ViaCEP."
        echo "CEP: ${cep} - Nao encontrado" > "$cep_file"
        export CEP_LOGRADOURO CEP_BAIRRO CEP_CIDADE CEP_ESTADO CEP_DDD CEP_IBGE
        return 1
    fi

    echo "$viacep_data" > "${pasta}/viacep_response.json"

    CEP_LOGRADOURO=$(echo "$viacep_data" | jq -r '.logradouro // "N/A"')
    CEP_BAIRRO=$(echo "$viacep_data" | jq -r '.bairro // "N/A"')
    CEP_CIDADE=$(echo "$viacep_data" | jq -r '.localidade // "N/A"')
    CEP_ESTADO=$(echo "$viacep_data" | jq -r '.uf // "N/A"')
    CEP_DDD=$(echo "$viacep_data" | jq -r '.ddd // "N/A"')
    CEP_IBGE=$(echo "$viacep_data" | jq -r '.ibge // "N/A"')

    export CEP_LOGRADOURO CEP_BAIRRO CEP_CIDADE CEP_ESTADO CEP_DDD CEP_IBGE

    cat > "$cep_file" <<EOF
CEP: ${cep}
Logradouro: ${CEP_LOGRADOURO}
Bairro: ${CEP_BAIRRO}
Cidade: ${CEP_CIDADE}
Estado: ${CEP_ESTADO}
DDD: ${CEP_DDD}
IBGE: ${CEP_IBGE}
EOF

    log_success "CEP encontrado: ${CEP_LOGRADOURO}, ${CEP_BAIRRO}, ${CEP_CIDADE}/${CEP_ESTADO}"
}
