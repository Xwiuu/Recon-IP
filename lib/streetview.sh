#!/bin/bash
# streetview.sh - Gera thumbnail do Street View e links do Google Maps

get_streetview() {
    local lat=$1
    local lon=$2
    local pasta=$3
    local street_file="${pasta}/street.jpg"
    local key="${GOOGLE_MAPS_KEY:-}"

    log_info "Gerando Street View para ${lat}, ${lon}..."

    if [ -n "$key" ] && [ "$key" != "SEU_GOOGLE_MAPS_KEY" ]; then
        curl -s "https://maps.googleapis.com/maps/api/streetview?size=600x300&location=${lat},${lon}&fov=80&heading=70&pitch=0&key=${key}" -o "$street_file"
        if [ -s "$street_file" ]; then
            log_success "Thumbnail do Street View baixada."
        else
            log_warning "Falha ao baixar imagem. Usando placeholder."
            echo "Imagem indisponível" > "$street_file"
        fi
    else
        log_warning "Chave do Google Maps não configurada. Usando placeholder."
        echo "Imagem indisponível" > "$street_file"
    fi

    LINK_STREET="https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=${lat},${lon}"
    LINK_MAPS_EMBED="https://maps.google.com/maps?q=${lat},${lon}&z=15&output=embed"
    LINK_MAPS_NAV="https://www.google.com/maps?q=${lat},${lon}"

    export LINK_STREET LINK_MAPS_EMBED LINK_MAPS_NAV
    log_success "Links do Google Maps gerados."
}
