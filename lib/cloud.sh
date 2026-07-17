#!/bin/bash
# cloud.sh - Detecta se o IP pertence a provedores de nuvem (AWS, Azure, GCP, Cloudflare, etc.)

detect_cloud() {
    local ip=$1
    local pasta=$2
    local cloud_file="${pasta}/cloud.txt"

    CLOUD_PROVIDER="N/A"
    CLOUD_DETAILS="N/A"

    local isp="${ISP:-N/A}"
    local asn="${ASN:-N/A}"
    local org="${REDE:-N/A}"
    local hostname="${HOSTNAME:-N/A}"
    local combined="${isp} ${asn} ${org} ${hostname}"

    check_provider() {
        local name=$1
        local pattern=$2
        if echo "$combined" | grep -qiE "$pattern"; then
            CLOUD_PROVIDER="$name"
            CLOUD_DETAILS=$(echo "$combined" | grep -ioE "$pattern" | head -1)
            return 0
        fi
        return 1
    }

    check_provider "Amazon Web Services (AWS)" "amazon|aws|ec2|compute\.amazon" && { write_cloud; return 0; }
    check_provider "Microsoft Azure" "azure|microsoft.*cloud|windows azure" && { write_cloud; return 0; }
    check_provider "Google Cloud Platform (GCP)" "google.*cloud|gcp|compute\.google" && { write_cloud; return 0; }
    check_provider "Cloudflare" "cloudflare" && { write_cloud; return 0; }
    check_provider "DigitalOcean" "digitalocean|digital ocean" && { write_cloud; return 0; }
    check_provider "Oracle Cloud (OCI)" "oracle.*cloud|oci" && { write_cloud; return 0; }
    check_provider "IBM Cloud" "ibm.*cloud|softlayer" && { write_cloud; return 0; }
    check_provider "Linode" "linode|akamai.*cloud" && { write_cloud; return 0; }
    check_provider "Vultr" "vultr" && { write_cloud; return 0; }
    check_provider "OVHcloud" "ovh" && { write_cloud; return 0; }
    check_provider "Hetzner" "hetzner" && { write_cloud; return 0; }
    check_provider "Alibaba Cloud" "alibaba.*cloud|aliyun" && { write_cloud; return 0; }

    log_debug "Nenhum provedor de nuvem detectado"
    echo "Provedor de Nuvem: Nao detectado" > "$cloud_file"
    export CLOUD_PROVIDER CLOUD_DETAILS
    return 1
}

write_cloud() {
    local cloud_file="${pasta}/cloud.txt"
    {
        echo "=== DETECCAO DE NUVEM ==="
        echo "IP: $ip"
        echo "Provedor: $CLOUD_PROVIDER"
        echo "Detalhes: $CLOUD_DETAILS"
        echo "ISP: $ISP"
        echo "ASN: $ASN"
        echo "Org: $REDE"
        echo "Hostname: $HOSTNAME"
    } > "$cloud_file"
    log_success "Cloud detectado: $CLOUD_PROVIDER ($CLOUD_DETAILS)"
    export CLOUD_PROVIDER CLOUD_DETAILS
}
