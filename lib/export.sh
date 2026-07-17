#!/bin/bash
# export.sh - Exporta dados em JSON e CSV

export_json() {
    local ip=$1
    local pasta=$2
    local json_file="${pasta}/report.json"

    local portas_json
    portas_json=$(grep "ABERTA" "${pasta}/portas.txt" 2>/dev/null | sed 's/.*\([0-9]\+\)\/tcp.*/\1/' | sed 's/.*/"&"/' | paste -sd, -)

    local whois_text
    whois_text=$(cat "${pasta}/whois.txt" 2>/dev/null | head -20 | sed 's/"/\\"/g' | tr '\n' ' ')

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
        "titulo": "$TITLE",
        "ssl_emissor": "$SSL_ISSUER"
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

    echo "IP,Tipo,Data,Cidade,Regiao,Pais,ISP,ASN,Hostname,Lat,Lon,Clima,Portas_Abertas,Servidor,Titulo" > "$csv_file"
    echo "\"$ip\",\"${IP_TYPE:-IPv4}\",\"$(date)\",\"$CITY\",\"$REGION\",\"$COUNTRY\",\"$ISP\",\"$ASN\",\"$HOSTNAME\",\"$LAT\",\"$LON\",\"$CLIMA\",\"$portas_abertas\",\"$SERVER_INFO\",\"$TITLE\"" >> "$csv_file"
    log_success "CSV exportado: $csv_file"
}
