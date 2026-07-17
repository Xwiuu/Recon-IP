#!/bin/bash
# cms.sh - Detecta CMS (WordPress, Joomla, Drupal, etc.) via analise HTML

detect_cms() {
    local dominio=$1
    local pasta=$2
    local cms_file="${pasta}/cms.txt"

    CMS_NAME="N/A"
    CMS_VERSION="N/A"
    CMS_THEME="N/A"
    CMS_PLUGINS="N/A"

    if [ -z "$dominio" ] || [ "$dominio" = "N/A" ]; then
        echo "CMS: N/A (nenhum dominio)" > "$cms_file"
        export CMS_NAME CMS_VERSION CMS_THEME CMS_PLUGINS
        return 1
    fi

    log_info "Detectando CMS para $dominio..."

    local proto="https"
    if ! curl -skI --max-time 5 "https://${dominio}" &>/dev/null; then
        proto="http"
    fi

    local html
    html=$(curl -skL --max-time 8 "${proto}://${dominio}" 2>/dev/null)
    if [ -z "$html" ]; then
        log_warning "CMS: pagina nao acessivel"
        echo "CMS: N/A (pagina inacessivel)" > "$cms_file"
        export CMS_NAME CMS_VERSION CMS_THEME CMS_PLUGINS
        return 1
    fi

    local headers
    headers=$(curl -skI --max-time 5 "${proto}://${dominio}" 2>/dev/null)

    # WordPress
    if echo "$html" | grep -qiE 'wp-content|wp-includes|wp-json|WordPress'; then
        CMS_NAME="WordPress"
        CMS_VERSION=$(echo "$html" | grep -oP 'ver=\K[0-9.]+' | head -1)
        CMS_VERSION=${CMS_VERSION:-$(echo "$html" | grep -oP 'WordPress [0-9.]+' | head -1 | sed 's/WordPress //')}
        CMS_THEME=$(echo "$html" | grep -oP 'wp-content/themes/\K[^/]+' | sort -u | head -1)
        local plugins
        plugins=$(echo "$html" | grep -oP 'wp-content/plugins/\K[^/]+' | sort -u | head -5)
        [ -n "$plugins" ] && CMS_PLUGINS=$(echo "$plugins" | tr '\n' ', ' | sed 's/,$//')
        log_success "CMS: WordPress ${CMS_VERSION:-detectado}"
    # Joomla
    elif echo "$html" | grep -qiE 'joomla|com_content|com_modules|mod_footer'; then
        CMS_NAME="Joomla"
        CMS_VERSION=$(echo "$html" | grep -oP 'Joomla! [0-9.]+' | head -1 | sed 's/Joomla! //')
        CMS_VERSION=${CMS_VERSION:-$(echo "$html" | grep -oP 'version=\K[0-9.]+' | head -1)}
        log_success "CMS: Joomla ${CMS_VERSION:-detectado}"
    # Drupal
    elif echo "$html" | grep -qiE 'drupal|Drupal\.settings|drupal\.js|sites/default'; then
        CMS_NAME="Drupal"
        CMS_VERSION=$(echo "$html" | grep -oP 'Drupal [0-9.]+' | head -1 | sed 's/Drupal //')
        CMS_VERSION=${CMS_VERSION:-$(echo "$html" | grep -oP 'version=\K[0-9.]+' | head -1)}
        log_success "CMS: Drupal ${CMS_VERSION:-detectado}"
    # Magento
    elif echo "$html" | grep -qiE 'mage\.|Magento|var\/generation|static\/version'; then
        CMS_NAME="Magento"
        CMS_VERSION=$(echo "$html" | grep -oP 'Magento[ /][0-9.]+' | head -1 | sed 's/Magento[ /]//')
        log_success "CMS: Magento ${CMS_VERSION:-detectado}"
    # Shopify
    elif echo "$headers" | grep -qiE 'X-Server-Type: Shopify|X-ShopId'; then
        CMS_NAME="Shopify"
        log_success "CMS: Shopify"
    # Wix
    elif echo "$html" | grep -qiE 'Wix\.com|X-Wix'; then
        CMS_NAME="Wix"
        log_success "CMS: Wix"
    # Squarespace
    elif echo "$html" | grep -qiE 'squarespace|Squarespace'; then
        CMS_NAME="Squarespace"
        log_success "CMS: Squarespace"
    # Blogger/Blogspot
    elif echo "$html" | grep -qiE 'blogger\.com|blogspot\.com|#[0-9]+\. Blogger'; then
        CMS_NAME="Blogger"
        log_success "CMS: Blogger"
    else
        log_debug "CMS: nenhum CMS conhecido detectado"
    fi

    {
        echo "=== DETECCAO DE CMS ==="
        echo "Dominio: $dominio"
        echo "CMS: ${CMS_NAME:-N/A}"
        echo "Versao: ${CMS_VERSION:-N/A}"
        echo "Tema: ${CMS_THEME:-N/A}"
        echo "Plugins: ${CMS_PLUGINS:-N/A}"
    } > "$cms_file"

    export CMS_NAME CMS_VERSION CMS_THEME CMS_PLUGINS
}
