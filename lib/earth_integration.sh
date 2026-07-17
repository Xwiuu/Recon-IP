#!/bin/bash
# earth_integration.sh - Integracao com Google Earth

generate_kml() {
    local ip=$1
    local lat=$2
    local lon=$3
    local pasta=$4
    local kml_file="${pasta}/location.kml"

    if [ -z "$lat" ] || [ -z "$lon" ] || [ "$lat" = "null" ] || [ "$lon" = "null" ]; then
        log_warning "Coordenadas invalidas. KML nao gerado."
        return
    fi

    log_info "Gerando arquivo KML para Google Earth..."

    cat > "$kml_file" <<KML
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <name>ReconIP - ${ip}</name>
    <description>Relatorio OSINT gerado em $(date)</description>
    <Style id="pin">
      <IconStyle>
        <scale>1.2</scale>
        <Icon>
          <href>http://maps.google.com/mapfiles/kml/pushpin/red-pushpin.png</href>
        </Icon>
      </IconStyle>
    </Style>
    <Placemark>
      <name>${ip}</name>
      <description>
        <![CDATA[
          <b>IP:</b> ${ip}<br/>
          <b>Local:</b> ${CITY:-N/A}, ${REGION:-N/A} - ${COUNTRY:-N/A}<br/>
          <b>ISP:</b> ${ISP:-N/A}<br/>
          <b>Hostname:</b> ${HOSTNAME:-N/A}<br/>
          <b>Relatorio:</b> <a href="file://$(pwd)/${pasta}/report.html">HTML</a>
        ]]>
      </description>
      <styleUrl>#pin</styleUrl>
      <Point>
        <coordinates>${lon},${lat},0</coordinates>
      </Point>
    </Placemark>
  </Document>
</kml>
KML

    log_success "KML gerado: $kml_file"
    export KML_FILE="$kml_file"
    generate_kmz "$pasta"
}

generate_kmz() {
    local pasta=$1
    local kml_file="${pasta}/location.kml"
    local kmz_file="${pasta}/location.kmz"

    if [ ! -f "$kml_file" ]; then
        log_warning "KML nao encontrado. KMZ nao gerado."
        return
    fi

    log_info "Compactando KML para KMZ..."

    if command -v zip &>/dev/null; then
        (cd "$pasta" && zip -q "location.kmz" "location.kml" 2>/dev/null)
        if [ -f "$kmz_file" ]; then
            log_success "KMZ gerado: $kmz_file"
            export KMZ_FILE="$kmz_file"
            return 0
        fi
    fi

    if command -v powershell &>/dev/null; then
        powershell -Command "Compress-Archive -Path '$kml_file' -DestinationPath '$kmz_file' -Force" 2>/dev/null
        if [ -f "$kmz_file" ]; then
            log_success "KMZ gerado via PowerShell."
            export KMZ_FILE="$kmz_file"
            return 0
        fi
    fi

    log_warning "zip nao disponivel. KMZ nao gerado (apenas KML disponivel)."
}

open_google_earth() {
    local lat=$1
    local lon=$2

    if [ -z "$lat" ] || [ -z "$lon" ] || [ "$lat" = "null" ] || [ "$lon" = "null" ]; then
        log_warning "Coordenadas invalidas."
        return
    fi

    local earth_url="https://earth.google.com/web/@${lat},${lon},150a,0d,0h,0t,0r"
    echo -e "\n${GREEN}ABRIR NO GOOGLE EARTH:${NC} $earth_url"

    if command -v start &>/dev/null; then
        start "$earth_url"
    elif command -v xdg-open &>/dev/null; then
        xdg-open "$earth_url"
    elif command -v open &>/dev/null; then
        open "$earth_url"
    else
        log_info "Copie o link e cole no navegador: $earth_url"
    fi

    export GOOGLE_EARTH_URL="$earth_url"
}
