#!/bin/bash
# subdomains.sh - Enumeracao de subdominios via DNS brute-force

enumerate_subdomains() {
    local dominio=$1
    local pasta=$2
    local sub_file="${pasta}/subdominios.txt"

    if [ -z "$dominio" ] || [ "$dominio" = "N/A" ]; then
        echo "Nenhum dominio informado." > "$sub_file"
        SUBDOMAIN_COUNT=0; SUBDOMAIN_LIST="N/A"
        export SUBDOMAIN_COUNT SUBDOMAIN_LIST
        return
    fi

    log_info "Iniciando enumeracao de subdominios para $dominio..."

    local wordlist=(
        admin mail ftp www webmail smtp pop3 imap
        blog shop store forum wiki help support
        dev test staging beta demo app api
        mobile m wap remote vpn secure ssl
        cdn static assets images img css js
        download uploads files media video tv
        news status server server1 server2
        ns1 ns2 dns1 dns2 mx1 mx2 mail1 mail2
        owa exchange roundcube squirrelmail
        cpanel whm phpmyadmin phpadmin manager
        dashboard portal gateway proxy firewall
        monitor logs backup db database sql mysql
        jenkins git svn jira confluence
        grafana prometheus kibana elastic kafka
        redis memcached rabbitmq mqtt
        docs documentation api-docs swagger openapi
        partner clients customer billing payment
        intranet corp office hr people employee
        webdisk webdav caldav carddav
        autodiscover lyncdiscover sip voip
        stage dev2 dev3 test2 uat qa
        app1 app2 web1 web2 web3 db1 db2
        mailstore mailrelay spam antivirus
        cloud aws azure gcp do droplet
        config setup install upgrade
        status dashboard monitor admin-dev
        loja cadastro suporte atendimento
        intranet corporativo rh financeiro
        homolog homologacao treinamento cursos
    )

    local found=0
    local results=""

    {
        echo "=== ENUMERACAO DE SUBDOMINIOS ==="
        echo "Dominio alvo: $dominio"
        echo "Data: $(date)"
        echo "--------------------------------"
    } > "$sub_file"

    for sub in "${wordlist[@]}"; do
        local target="${sub}.${dominio}"
        local ip=""

        if command -v nslookup &>/dev/null; then
            ip=$(nslookup "$target" 2>/dev/null | grep -E '^Address' | grep -v '#' | awk '{print $NF}' | grep -E '^[0-9.]+$' | head -1)
        elif command -v host &>/dev/null; then
            ip=$(host -t A "$target" 2>/dev/null | grep 'has address' | awk '{print $NF}')
        fi

        if [ -n "$ip" ]; then
            found=$((found + 1))
            results="${results}${target} -> ${ip}"$'\n'
            echo "FOUND ${target} -> ${ip}" >> "$sub_file"
            log_success "Subdominio: ${target} (${ip})"
        fi
    done

    if [ "$found" -gt 0 ]; then
        echo "" >> "$sub_file"
        echo "Total: ${found} subdominios encontrados" >> "$sub_file"
        SUBDOMAIN_COUNT="$found"
        SUBDOMAIN_LIST="$results"
    else
        echo "Nenhum subdominio encontrado." >> "$sub_file"
        SUBDOMAIN_COUNT=0
        SUBDOMAIN_LIST="Nenhum"
    fi

    export SUBDOMAIN_COUNT SUBDOMAIN_LIST
    log_success "Enumeracao de subdominios: ${found} encontrados"
}
