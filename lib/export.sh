#!/bin/bash
# export.sh - Exporta dados em JSON e CSV

export_json() {
    local ip=$1
    local pasta=$2
    local json_file="${pasta}/report.json"

    local portas_json
    portas_json=$(grep "ABERTA" "${pasta}/portas.txt" 2>/dev/null | sed 's/.*\([0-9]\+\)\/tcp.*/\1/' | sed 's/.*/"&"/' | paste -sd, -)
    local sub_json=$(echo "${SUBDOMAIN_LIST:-}" | sed 's/ ->.*//' | sed 's/.*/"&"/' | paste -sd, -)
    local ssl_tls=$(echo "{\"tls10\":\"$SSL_TLS10\",\"tls11\":\"$SSL_TLS11\",\"tls12\":\"$SSL_TLS12\",\"tls13\":\"$SSL_TLS13\",\"poodle\":\"$SSL_POODLE\",\"beast\":\"$SSL_BEAST\",\"crime\":\"$SSL_CRIME\",\"weak_ciphers\":\"$SSL_WEAK_CIPHERS\"}")

    cat > "$json_file" <<EOF
{
    "ip": "$ip",
    "tipo": "${IP_TYPE:-IPv4}",
    "data": "$(date)",
    "geo": {
        "cidade": "$CITY",
        "regiao": "$REGION",
        "pais": "$COUNTRY",
        "isp": "$ISP",
        "asn": "$ASN",
        "hostname": "$HOSTNAME",
        "coordenadas": "$LAT,$LON"
    },
    "clima": "$CLIMA",
    "portas_abertas": [$portas_json],
    "banner": {
        "servidor": "$SERVER_INFO",
        "titulo": "$TITLE_INFO",
        "ssl_emissor": "$SSL_ISSUER"
    },
    "dns": {
        "ptr": "$PTR_RECORD",
        "spf": "$EMAIL_SPF",
        "dkim": "$EMAIL_DKIM",
        "dmarc": "$EMAIL_DMARC",
        "spoofable": "$EMAIL_SPOOFABLE"
    },
    "seguranca": {
        "hsts": "$HSTS",
        "csp": "$CSP",
        "xfo": "$XFO",
        "xcto": "$XCTO",
        "permissions_policy": "$PERMISSIONS_POLICY"
    },
    "ssl_tls": $ssl_tls,
    "vulnerabilidades": {
        "log4j": "$LOG4J_VULN",
        "heartbleed": "$HEARTBLEED_VULN",
        "shellshock": "$SHELLSHOCK_VULN",
        "ssh": "$SSH_WEAK"
    },
    "subdominios": [${sub_json:-null}],
    "robots": {
        "disallow": "$ROBOTS_DISALLOW",
        "sitemap": "$ROBOTS_SITEMAP"
    },
    "shodan": "$SHODAN_DATA",
    "monitoramento": {
        "alteracoes": ${MONITOR_CHANGED:-0}
    }
}
EOF
    log_success "JSON exportado: $json_file"
}

export_csv() {
    local ip=$1
    local pasta=$2
    local csv_file="${pasta}/report.csv"

    local portas_abertas
    portas_abertas=$(grep "ABERTA" "${pasta}/portas.txt" 2>/dev/null | sed 's/.*\([0-9]\+\)\/tcp.*/\1/' | paste -sd '|' -)

    echo "IP,Tipo,Data,Cidade,Regiao,Pais,ISP,ASN,Hostname,Lat,Lon,Clima,Portas_Abertas,Servidor,Titulo,PTR,SPF,DMARC,Log4j,Heartbleed,Shellshock,Subdominios" > "$csv_file"
    echo "\"$ip\",\"${IP_TYPE:-IPv4}\",\"$(date)\",\"$CITY\",\"$REGION\",\"$COUNTRY\",\"$ISP\",\"$ASN\",\"$HOSTNAME\",\"$LAT\",\"$LON\",\"$CLIMA\",\"$portas_abertas\",\"$SERVER_INFO\",\"$TITLE_INFO\",\"$PTR_RECORD\",\"$EMAIL_SPF\",\"$EMAIL_DMARC\",\"$LOG4J_VULN\",\"$HEARTBLEED_VULN\",\"$SHELLSHOCK_VULN\",\"$SUBDOMAIN_COUNT\"" >> "$csv_file"
    log_success "CSV exportado: $csv_file"
}
