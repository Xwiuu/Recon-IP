#!/bin/bash
# whois_domain.sh - WHOIS de dominio detalhado

whois_domain() {
    local dominio=$1
    local pasta=$2
    local whois_file="${pasta}/whois_domain.txt"

    log_info "Consultando WHOIS do dominio $dominio..."

    if ! command -v whois &>/dev/null; then
        {
            echo "=== WHOIS DO DOMINIO ==="
            echo "Dominio: $dominio"
            echo "Status: Indisponivel (comando whois nao encontrado)"
        } > "$whois_file"
        DOMAIN_CREATED="N/A"; DOMAIN_EXPIRY="N/A"; DOMAIN_UPDATED="N/A"
        DOMAIN_REGISTRAR="N/A"; DOMAIN_ADMIN="N/A"; DOMAIN_NS_WHOIS="N/A"
        DOMAIN_STATUS="N/A"; DOMAIN_WHOIS_DONE=1
        export DOMAIN_CREATED DOMAIN_EXPIRY DOMAIN_UPDATED DOMAIN_REGISTRAR \
               DOMAIN_ADMIN DOMAIN_NS_WHOIS DOMAIN_STATUS DOMAIN_WHOIS_DONE
        log_warning "WHOIS: comando nao disponivel"
        return 1
    fi

    local raw
    raw=$(whois "$dominio" 2>/dev/null)
    if [ -z "$raw" ]; then
        {
            echo "=== WHOIS DO DOMINIO ==="
            echo "Dominio: $dominio"
            echo "Status: Falha na consulta"
        } > "$whois_file"
        log_warning "Falha ao consultar WHOIS do dominio"
        return 1
    fi

    echo "$raw" > "${pasta}/domain_whois_raw.txt"

    DOMAIN_CREATED=$(echo "$raw" | grep -iE "Creation Date:|created:" | head -1 | sed 's/^[^:]*:[[:space:]]*//' | xargs)
    DOMAIN_EXPIRY=$(echo "$raw" | grep -iE "Registry Expiry Date:|Expiration Date:|expire:" | head -1 | sed 's/^[^:]*:[[:space:]]*//' | xargs)
    DOMAIN_UPDATED=$(echo "$raw" | grep -iE "Updated Date:|last-modified:" | head -1 | sed 's/^[^:]*:[[:space:]]*//' | xargs)
    DOMAIN_REGISTRAR=$(echo "$raw" | grep -iE "^Registrar:" | head -1 | sed 's/^[^:]*:[[:space:]]*//' | xargs)
    DOMAIN_ADMIN=$(echo "$raw" | grep -iE "Registrant Name:|Registrant Organization:|owner:" | head -1 | sed 's/^[^:]*:[[:space:]]*//' | xargs)
    DOMAIN_NS_WHOIS=$(echo "$raw" | grep -iE "Name Server:" | head -5 | sed 's/^[^:]*:[[:space:]]*//' | tr '\n' ', ' | sed 's/,[[:space:]]*$//' | xargs)
    DOMAIN_STATUS_RAW=$(echo "$raw" | grep -iE "^Domain Status:|^Status:" | head -3 | sed 's/^[^:]*:[[:space:]]*//' | tr '\n' ', ' | sed 's/,[[:space:]]*$//' | xargs)

    DOMAIN_CREATED="${DOMAIN_CREATED:-N/A}"
    DOMAIN_EXPIRY="${DOMAIN_EXPIRY:-N/A}"
    DOMAIN_UPDATED="${DOMAIN_UPDATED:-N/A}"
    DOMAIN_REGISTRAR="${DOMAIN_REGISTRAR:-N/A}"
    DOMAIN_ADMIN="${DOMAIN_ADMIN:-N/A}"
    DOMAIN_NS_WHOIS="${DOMAIN_NS_WHOIS:-N/A}"
    DOMAIN_STATUS="${DOMAIN_STATUS_RAW:-N/A}"
    DOMAIN_WHOIS_DONE=1

    export DOMAIN_CREATED DOMAIN_EXPIRY DOMAIN_UPDATED DOMAIN_REGISTRAR \
           DOMAIN_ADMIN DOMAIN_NS_WHOIS DOMAIN_STATUS DOMAIN_WHOIS_DONE

    {
        echo "=== WHOIS DO DOMINIO ==="
        echo "Dominio: $dominio"
        echo "Criado em: $DOMAIN_CREATED"
        echo "Expira em: $DOMAIN_EXPIRY"
        echo "Atualizado em: $DOMAIN_UPDATED"
        echo "Registrante: $DOMAIN_ADMIN"
        echo "Registrar: $DOMAIN_REGISTRAR"
        echo "Servidores NS: $DOMAIN_NS_WHOIS"
        echo "Status: $DOMAIN_STATUS"
    } > "$whois_file"

    log_success "WHOIS do dominio: Criado=$DOMAIN_CREATED | Registrar=$DOMAIN_REGISTRAR"
}
