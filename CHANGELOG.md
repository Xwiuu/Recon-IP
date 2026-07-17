# 📋 Changelog

Todas as mudanças notáveis neste projeto serão documentadas aqui.

O formato é baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/),
e este projeto adere ao [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [2.0.0] - 2026-07-17 — 🚀 OSINT Completo

### ✨ Adicionado

#### 🌍 Geolocalização & Ambiente
- Geoposicionamento com fallback triplo (ipinfo.io → ip-api.com → geoiplookup local)
- CEP automático via ViaCEP (logradouro, bairro, DDD, IBGE)
- Clima estendido: previsão de 3 dias via wttr.in com fallback por cidade/país
- Fuso horário e coordenadas precisas

#### 🔬 Port Scan & Banner Grabbing
- Scan TCP: 13 portas comuns com `/dev/tcp`, `nc` e `nmap` (fallback automático)
- Scan UDP: 7 portas (DNS, SNMP, NTP, DHCP, TFTP, syslog, RADIUS)
- Nmap avançado: `-sV`, `-O`, `-sC`, `--script` (se instalado)
- Banner Grabbing completo: HTTP (servidor + título), SSH, FTP, SSL, favicon hash

#### 🌐 DNS & Domínio
- Registros DNS: A, AAAA, MX, TXT, NS, SOA
- WHOIS IP (whois local + ipwhois.app API)
- WHOIS Domínio (whois local + API: criação, expiração, registrante)
- Reverse IP Lookup com 3 fontes: hackertarget, viewdns, yougetsignal
- Reverse DNS (PTR)
- Transferência de Zona (AXFR)
- Enumeração de Subdomínios (brute-force com 130+ wordlist)
- Análise de robots.txt + sitemap.xml

#### 🛡️ Segurança & Vulnerabilidades
- Testes SSL/TLS: TLS 1.0, 1.1, 1.2, 1.3
- POODLE, BEAST, CRIME detection
- Cifras fracas SSH (nmap `ssh2-enum-algos`)
- Log4j (CVE-2021-44228) com payload DNS + HTTP
- Heartbleed (CVE-2014-0160) via openssl heartbeat
- Shellshock (CVE-2014-6271) via curl payload
- CVE Check via NVD API 2.0
- Security Headers: HSTS, CSP, XFO, XCTO, COEP, COOP, CORP, Permissions-Policy
- Email Security: SPF, DKIM, DMARC com análise de spoofing

#### 🕵️ OSINT Avançado
- Google Dorks: 30+ dorks inteligentes para IP e domínio
- Redes Sociais: Facebook, Instagram, LinkedIn, Twitter, TikTok, YouTube, GitHub, Telegram, WhatsApp
- Extração de Contatos: emails e telefones via WHOIS + scraping
- Cloud Detection: AWS, Azure, GCP, Cloudflare, DigitalOcean, OVH, Linode e mais
- CMS Detection: WordPress, Joomla, Drupal, Magento, Shopify, Wix e mais
- MAC OSINT: API macvendors.com + 22 OUIs locais de fallback

#### 📊 Exportação
- **5 formatos**: HTML, JSON, CSV, Markdown, GeoJSON
- **PDF** (via wkhtmltopdf ou pandoc)
- **Google Earth**: KML + KMZ + GeoJSON
- GeoJSON compatível com QGIS, Mapbox, Leaflet

#### 🔗 Modo Link
- 3 túneis simultâneos: Cloudflared + Ngrok + Loclx
- URLs encurtadas automaticamente (TinyURL + is.gd)
- Captura de vítima com index.php (IP, User-Agent, localização aproximada)
- Scan automático ao detectar nova vítima
- Suporte a Windows (Git Bash) com fallback de caminhos PHP

#### ⚙️ Infraestrutura
- Interface TUI com barra de progresso e cores
- Notificações: Telegram (foto + resumo) e Discord (embed)
- Monitoramento contínuo com diff automático entre scans
- Agendamento via cron (`--cron`)
- Modo debug (`DEBUG=1` no config.env)
- Tratamento de IPv4 e IPv6 em todos os módulos

### 🐛 Corrigido

- CEP agora aparece corretamente no relatório HTML
- Clima 3 dias com fallback quando wttr.in falha
- MAC OSINT com fallback local (22 OUIs) quando API está offline
- Modo Link reconhece PHP no Windows (Git Bash)
- Scan de rede /24 não trava mais em IPv6
- ASN agora é populado de múltiplas fontes (ipinfo → whois)
- Váriaveis não exportadas agora são propagadas corretamente
- Tratamento de timeout em todas as APIs externas

### 🔧 Melhorado

- Barra de progresso responsiva com labels dinâmicas
- Fallbacks inteligentes em TODAS as APIs
- Performance: tempo de scan reduzido em ~40%
- Relatório HTML dark mode com design responsivo
- Código modular: 34 libs independentes
- Documentação completa dos módulos

---

## [1.0.0] - 2026-07-15 — 🎯 Primeiro MVP

### ✨ Adicionado

- Scan básico de IPs com geolocalização
- Scan de portas TCP (6 portas)
- Banner grabbing básico (HTTP)
- Relatório HTML com dark mode
- Modo Link com Cloudflared
- Notificações Telegram
- Estrutura modular inicial

### 🐛 Corrigido

- N/A — Primeira versão

---

## [0.1.0] - 2026-07-10 — 🌱 Protótipo

### ✨ Adicionado

- Validação de IP
- Requisição ip-api.com
- Geração de relatório HTML básico
- Script super_recon.sh funcional

---

<div align="center">
  <sub>Changelog mantido com ❤️ e ☕</sub>
</div>
