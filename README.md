# SUPERRECON v2.0 — IP Tracker & OSINT Recon

**Ferramenta de Reconhecimento Geográfico e de Rede (OSINT)**
> 80% Shell + 20% PHP | Túneis Redundantes | Relatório HTML Portátil

---

## Diferenciais

- **2 Modos de Operação:** Modo Link (com túneis) + Modo Manual (`-s IP`).
- **3 Túneis Simultâneos:** Cloudflared, Ngrok e Loclx. Se um cair, os outros seguram.
- **Encurtador Automático:** Gera links TinyURL e is.gd na hora.
- **Fingerprint Avançado:** Geolocalização, IP Local (WebRTC), Bateria, Idioma, Tela.
- **Street View + Mapa:** Baixa thumbnail da rua e gera link 360 do Google Maps.
- **Scan de Portas:** Verifica portas comuns (SSH, HTTP, MySQL, etc.).
- **Clima Local:** Puxa temperatura e condições via wttr.in.
- **Relatório Visual:** Gera um HTML com CSS Dark Mode e abre automaticamente.
- **Notificação Instantânea:** Envia foto + resumo para Telegram ou Discord.

---

## Instalação

```bash
git clone https://github.com/Xwiuu/Recon-IP.git
cd Recon-IP
chmod +x super_recon.sh lib/*.sh
cp config.env.example config.env
```

Edite o `config.env` com seu Token do Telegram e chave Google.

## Como Usar

**Modo Link (Gerar link para envio)**
```bash
./super_recon.sh
```

**Modo Scan (Você já tem o IP)**
```bash
./super_recon.sh -s 8.8.8.8
```

## Estrutura de Pastas

```
output/recon_<IP>/  → Relatórios, fotos e dados brutos de cada alvo.
lib/                → Módulos modulares (geo, ports, weather, streetview, report, tunnels, notify).
index.php           → Página de captura (Frontend).
```

## Disclaimer

Ferramenta exclusivamente para fins educacionais e pentest autorizado. O usuário é o único responsável por seu uso. Respeite a LGPD.
