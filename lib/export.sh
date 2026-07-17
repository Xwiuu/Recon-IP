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
    "cep": {
        "logradouro": "${CEP_LOGRADOURO:-N/A}",
        "bairro": "${CEP_BAIRRO:-N/A}",
        "cidade": "${CEP_CIDADE:-N/A}",
        "estado": "${CEP_ESTADO:-N/A}",
        "ddd": "${CEP_DDD:-N/A}"
    },
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
    "pwned": {
        "count": ${PWNED_COUNT:-0},
        "breaches": "${PWNED_BREACHES:-N/A}"
    },
    "previsao": {
        "dia1": "${CLIMA_DIA1:-N/A}",
        "dia2": "${CLIMA_DIA2:-N/A}",
        "dia3": "${CLIMA_DIA3:-N/A}"
    },
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

    local pwned_csv="${PWNED_BREACHES:-N/A}"
    echo "IP,Tipo,Data,Cidade,Regiao,Pais,ISP,ASN,Hostname,Lat,Lon,Clima,Portas_Abertas,Servidor,Titulo,PTR,SPF,DMARC,Log4j,Heartbleed,Shellshock,Subdominios,CEP_Cidade,Pwned" > "$csv_file"
    echo "\"$ip\",\"${IP_TYPE:-IPv4}\",\"$(date)\",\"$CITY\",\"$REGION\",\"$COUNTRY\",\"$ISP\",\"$ASN\",\"$HOSTNAME\",\"$LAT\",\"$LON\",\"$CLIMA\",\"$portas_abertas\",\"$SERVER_INFO\",\"$TITLE_INFO\",\"$PTR_RECORD\",\"$EMAIL_SPF\",\"$EMAIL_DMARC\",\"$LOG4J_VULN\",\"$HEARTBLEED_VULN\",\"$SHELLSHOCK_VULN\",\"$SUBDOMAIN_COUNT\",\"${CEP_CIDADE:-N/A}\",\"$pwned_csv\"" >> "$csv_file"
    log_success "CSV exportado: $csv_file"
}

export_markdown() {
    local ip=$1
    local pasta=$2
    local md_file="${pasta}/report.md"

    log_info "Exportando relatorio Markdown..."

    local portas_md
    portas_md=$(grep "ABERTA" "${pasta}/portas.txt" 2>/dev/null | head -20 | sed 's/^/- /' | tr '\n' '\n')

    local cve_count
    cve_count=$(grep -c "^CVE:" "${pasta}/cves.txt" 2>/dev/null || echo "0")

    cat > "$md_file" <<EOF
# 🕵️ Recon Report: ${ip}

**Tipo:** ${IP_TYPE:-IPv4} | **Data:** $(formatar_data)

---

## 📍 Geolocalizacao

| Campo | Valor |
|-------|-------|
| Cidade | ${CITY:-N/A} |
| Regiao | ${REGION:-N/A} |
| Pais | ${COUNTRY:-N/A} |
| ISP | ${ISP:-N/A} |
| ASN | ${ASN:-N/A} |
| Hostname | ${HOSTNAME:-N/A} |
| Coordenadas | ${LAT:-N/A}, ${LON:-N/A} |

## 🌤️ Clima

${CLIMA:-Indisponivel}

## 🚪 Portas Abertas

${portas_md:-Nenhuma porta aberta encontrada.}

## 🌐 Servidor Web

| Campo | Valor |
|-------|-------|
| Servidor | ${SERVER_INFO:-N/A} |
| Titulo | ${TITLE_INFO:-N/A} |
| SSL Emissor | ${SSL_ISSUER:-N/A} |
| SSL Expira | ${SSL_EXPIRY:-N/A} |

## 📡 DNS

| Campo | Valor |
|-------|-------|
| PTR | ${PTR_RECORD:-N/A} |
| IPv4 | ${DNS_IPV4:-N/A} |
| MX | ${DNS_MX:-N/A} |
| SPF | ${EMAIL_SPF:-N/A} |
| DMARC | ${EMAIL_DMARC:-N/A} |
| Spoofavel | ${EMAIL_SPOOFABLE:-N/A} |

## 🛡️ Seguranca

| Campo | Valor |
|-------|-------|
| HSTS | ${HSTS:-N/A} |
| CSP | ${CSP:-N/A} |
| XFO | ${XFO:-N/A} |
| TLS 1.0 | ${SSL_TLS10:-N/A} |
| TLS 1.1 | ${SSL_TLS11:-N/A} |
| TLS 1.2 | ${SSL_TLS12:-N/A} |
| TLS 1.3 | ${SSL_TLS13:-N/A} |

## 💥 Vulnerabilidades

| Teste | Resultado |
|-------|-----------|
| Log4j | ${LOG4J_VULN:-N/A} |
| Heartbleed | ${HEARTBLEED_VULN:-N/A} |
| Shellshock | ${SHELLSHOCK_VULN:-N/A} |
| CVE Encontrados | ${cve_count} |

## 🔗 Links

- [Google Maps](https://maps.google.com/maps?q=${LAT:-0},${LON:-0})
- [Street View](${LINK_STREET:-#})
- [Google Earth](${GOOGLE_EARTH_URL:-#})
- [Shodan](https://www.shodan.io/host/${ip})
- [AbuseIPDB](https://www.abuseipdb.com/check/${ip})
- [VirusTotal](https://www.virustotal.com/gui/ip-address/${ip})

---

_Gerado por ReconIP v2.0 em $(formatar_data)_
EOF

    log_success "Markdown exportado: $md_file"
}

export_geojson() {
    local ip=$1
    local pasta=$2
    local geojson_file="${pasta}/report.geojson"

    if [ -z "${LAT:-}" ] || [ -z "${LON:-}" ] || [ "${LAT}" = "N/A" ] || [ "${LON}" = "N/A" ]; then
        log_warning "Coordenadas invalidas. GeoJSON nao gerado."
        return
    fi

    log_info "Exportando GeoJSON..."

    local portas_geojson
    portas_geojson=$(grep "ABERTA" "${pasta}/portas.txt" 2>/dev/null | sed 's/.*\([0-9]\+\)\/tcp.*/\1/' | sed 's/.*/"&"/' | paste -sd ',' -)
    local geojson_cve_count
    geojson_cve_count=$(grep -c "^CVE:" "${pasta}/cves.txt" 2>/dev/null || echo "0")

    cat > "$geojson_file" <<EOF
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "geometry": {
        "type": "Point",
        "coordinates": [${LON}, ${LAT}]
      },
      "properties": {
        "ip": "${ip}",
        "hostname": "${HOSTNAME:-N/A}",
        "city": "${CITY:-N/A}",
        "region": "${REGION:-N/A}",
        "country": "${COUNTRY:-N/A}",
        "isp": "${ISP:-N/A}",
        "asn": "${ASN:-N/A}",
        "clima": "${CLIMA:-N/A}",
        "servidor": "${SERVER_INFO:-N/A}",
        "portas": [${portas_geojson:-null}],
        "cves": ${geojson_cve_count:-0},
        "subdominios": ${SUBDOMAIN_COUNT:-0},
        "score_shodan": "${SHODAN_DATA:-N/A}",
        "data": "$(formatar_data)"
      }
    }
  ]
}
EOF

    log_success "GeoJSON exportado: $geojson_file"
}
