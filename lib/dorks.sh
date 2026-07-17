#!/bin/bash
# dorks.sh - Gera links de Google Dorks para IP/Dominio

generate_dorks() {
    local ip=$1
    local dominio=$2
    local pasta=$3
    local dorks_file="${pasta}/dorks.txt"

    log_info "Gerando Google Dorks para ${ip}..."

    cat > "$dorks_file" <<EOF
=== GOOGLE DORKS ===
Alvo: ${ip} ${dominio:-(sem dominio)}
Gerado em: $(date)

--- Pesquisas para o IP ${ip} ---
🔍 IP Address: https://www.google.com/search?q=${ip}
🔍 "ip:${ip}": https://www.google.com/search?q=%22${ip}%22
🔍 intitle:${ip}: https://www.google.com/search?q=intitle%3A${ip}
🔍 inurl:${ip}: https://www.google.com/search?q=inurl%3A${ip}
🔍 site:${ip}: https://www.google.com/search?q=site%3A${ip}
🔍 allinurl:${ip}: https://www.google.com/search?q=allinurl%3A${ip}
🔍 allintext:${ip}: https://www.google.com/search?q=allintext%3A${ip}
🔍 cache:${ip}: https://webcache.googleusercontent.com/search?q=cache%3A${ip}
🔍 DNS /24: https://www.google.com/search?q=$(echo "$ip" | sed 's/\.[0-9]*$/.0\/24/')

EOF

    if [ -n "$dominio" ]; then
        cat >> "$dorks_file" <<EOF
--- Pesquisas para o Dominio ${dominio} ---
🔍 site:${dominio}: https://www.google.com/search?q=site%3A${dominio}
🔍 site:${dominio} filetype:pdf: https://www.google.com/search?q=site%3A${dominio}+filetype%3Apdf
🔍 site:${dominio} filetype:sql: https://www.google.com/search?q=site%3A${dominio}+filetype%3Asql
🔍 site:${dominio} filetype:log: https://www.google.com/search?q=site%3A${dominio}+filetype%3Alog
🔍 site:${dominio} filetype:txt: https://www.google.com/search?q=site%3A${dominio}+filetype%3Atxt
🔍 site:${dominio} filetype:env: https://www.google.com/search?q=site%3A${dominio}+filetype%3Aenv
🔍 site:${dominio} filetype:json: https://www.google.com/search?q=site%3A${dominio}+filetype%3Ajson
🔍 site:${dominio} filetype:xml: https://www.google.com/search?q=site%3A${dominio}+filetype%3Axml
🔍 site:${dominio} filetype:conf: https://www.google.com/search?q=site%3A${dominio}+filetype%3Aconf
🔍 site:${dominio} inurl:admin: https://www.google.com/search?q=site%3A${dominio}+inurl%3Aadmin
🔍 site:${dominio} inurl:login: https://www.google.com/search?q=site%3A${dominio}+inurl%3Alogin
🔍 site:${dominio} inurl:wp-admin: https://www.google.com/search?q=site%3A${dominio}+inurl%3Awp-admin
🔍 site:${dominio} inurl:config: https://www.google.com/search?q=site%3A${dominio}+inurl%3Aconfig
🔍 site:${dominio} inurl:backup: https://www.google.com/search?q=site%3A${dominio}+inurl%3Abackup
🔍 site:${dominio} inurl:php?id=: https://www.google.com/search?q=site%3A${dominio}+inurl%3Aphp%3Fid%3D
🔍 site:${dominio} ext:php intitle:phpinfo: https://www.google.com/search?q=site%3A${dominio}+ext%3Aphp+intitle%3Aphpinfo
🔍 site:${dominio} intitle:"index of": https://www.google.com/search?q=site%3A${dominio}+intitle%3A%22index+of%22
🔍 site:${dominio} "senha" OR "password": https://www.google.com/search?q=site%3A${dominio}+%22senha%22+OR+%22password%22
🔍 site:${dominio} "confidencial" OR "confidential": https://www.google.com/search?q=site%3A${dominio}+%22confidencial%22+OR+%22confidential%22
🔍 link:${dominio}: https://www.google.com/search?q=link%3A${dominio}
🔍 related:${dominio}: https://www.google.com/search?q=related%3A${dominio}
🔍 info:${dominio}: https://www.google.com/search?q=info%3A${dominio}

EOF
    fi

    cat >> "$dorks_file" <<EOF
--- Pesquisas Avancadas ---
🔍 Servidores web: https://www.google.com/search?q=%22Server%3A%22+${ip}
🔍 Shodan: https://www.shodan.io/host/${ip}
🔍 Censys: https://search.censys.io/hosts/${ip}
🔍 AbuseIPDB: https://www.abuseipdb.com/check/${ip}
🔍 VirusTotal: https://www.virustotal.com/gui/ip-address/${ip}
🔍 Talos Intelligence: https://talosintelligence.com/reputation_center/lookup?search=${ip}
🔍 urlscan.io: https://urlscan.io/ip/${ip}
🔍 ThreatCrowd: https://www.threatcrowd.org/ip.php?ip=${ip}
🔍 IPInfo: https://ipinfo.io/${ip}
🔍 Shodan Trending: https://www.google.com/search?q=%22${ip}%22+shodan
EOF

    log_success "Google Dorks gerados: $dorks_file"
}
