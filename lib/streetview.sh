#!/bin/bash
# streetview.sh - Street View com fallback

get_streetview() {
    local lat=$1
    local lon=$2
    local pasta=$3
    local street_file="${pasta}/street.jpg"
    local key="${GOOGLE_MAPS_KEY:-}"

    log_info "Gerando Street View para ${lat}, ${lon}..."

    # Tenta baixar com chave
    if [ -n "$key" ] && [ "$key" != "SUA_CHAVE_AQUI" ] && [ "$key" != "COLOQUE_SUA_CHAVE_GOOGLE_AQUI" ]; then
        curl -s "https://maps.googleapis.com/maps/api/streetview?size=600x300&location=${lat},${lon}&fov=80&heading=70&pitch=0&key=${key}" -o "$street_file"
        if [ -s "$street_file" ] && [ "$(file -b --mime-type "$street_file" 2>/dev/null)" != "text/plain" ]; then
            log_success "Thumbnail do Street View baixada com sucesso!"
        else
            log_warning "Falha ao baixar imagem. Usando placeholder."
            rm -f "$street_file"
        fi
    else
        log_warning "Chave do Google Maps não configurada. Gerando apenas link."
    fi

    # Se o arquivo estiver vazio ou não existir, cria um SVG placeholder
    if [ ! -s "$street_file" ]; then
        cat > "${pasta}/street_placeholder.svg" <<'SVGEOF'
<svg xmlns="http://www.w3.org/2000/svg" width="600" height="300">
    <rect fill="#161b22" width="600" height="300"/>
    <text fill="#58a6ff" x="300" y="140" text-anchor="middle" font-family="Arial" font-size="20">Street View</text>
    <text fill="#8b949e" x="300" y="170" text-anchor="middle" font-family="Arial" font-size="14">Indisponivel no momento</text>
    <text fill="#30363d" x="300" y="200" text-anchor="middle" font-family="Arial" font-size="12">Configure sua chave no config.env</text>
</svg>
SVGEOF
        # Converte SVG para JPG se tiver o ImageMagick
        if command -v convert &>/dev/null; then
            convert "${pasta}/street_placeholder.svg" "$street_file" 2>/dev/null
            log_info "Placeholder convertido para JPG via ImageMagick."
        fi
    fi

    # Gera links uteis
    LINK_STREET="https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=${lat},${lon}"
    LINK_MAPS_EMBED="https://www.google.com/maps/embed/v1/place?q=${lat},${lon}&zoom=15${key:+&key=${key}}"
    LINK_MAPS_NAV="https://www.google.com/maps?q=${lat},${lon}"

    export LINK_STREET LINK_MAPS_EMBED LINK_MAPS_NAV
    log_success "Links do Google Maps gerados."
}
