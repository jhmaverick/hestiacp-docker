#!/bin/bash

source "/usr/local/hstc/func/env-file.sh"

# Startup variables
env_read /var/run/hestiacp-startup.conf
# Load container variables
env_read /usr/local/hestia/conf/hstc.conf

if [[ "$FIRST_RUNNING" == "yes" ]]; then
    # Generating SSL certificate
    echo "[ * ] Generating default self-signed SSL certificate..."
    /usr/local/hestia/bin/v-generate-ssl-cert "$(hostname)" '' 'US' 'California' \
        'San Francisco' 'Hestia Control Panel' 'IT' >/tmp/hst.pem

    # Parsing certificate file
    crt_end=$(grep -n "END CERTIFICATE-" /tmp/hst.pem | cut -f 1 -d:)
    key_start=$(grep -n "BEGIN RSA" /tmp/hst.pem | cut -f 1 -d:)
    key_end=$(grep -n "END RSA" /tmp/hst.pem | cut -f 1 -d:)

    # Adding SSL certificate
    echo "[ * ] Adding SSL certificate to Hestia Control Panel..."
    sed -n "1,${crt_end}p" /tmp/hst.pem >/usr/local/hestia/ssl/certificate.crt
    sed -n "$key_start,${key_end}p" /tmp/hst.pem >/usr/local/hestia/ssl/certificate.key
    chown root:mail /usr/local/hestia/ssl/*
    chmod 660 /usr/local/hestia/ssl/*
    rm /tmp/hst.pem

    if [[ "${DEV_MODE,,}" != "yes" ]]; then
        # Update dhparam
        openssl dhparam -out /etc/ssl/dhparam.pem 2048

        external_ip="$(/usr/local/hestia/bin/v-list-web-domains "admin" | tail -n +3 | awk -v domain="$HOSTNAME" '$1 == domain {print $2}')"
    else
        external_ip="$(dig +short myip.opendns.com @resolver1.opendns.com)"
    fi

    /usr/local/hestia/bin/v-add-web-domain "admin" "$HOSTNAME" "$external_ip"
    /usr/local/hestia/bin/v-add-dns-domain "admin" "$HOSTNAME" "$external_ip"
    /usr/local/hestia/bin/v-add-mail-domain "admin" "$HOSTNAME"

    if [[ "${DEV_MODE,,}" != "yes" ]]; then
        /usr/local/hestia/bin/v-add-letsencrypt-host
    fi

    # Restart web services
    /usr/local/hestia/bin/v-restart-web-backend
    /usr/local/hestia/bin/v-restart-web

    echo
    echo "Congratulations!"
    echo
    echo "Initial settings have been applied."
    echo
    echo "Log in using the following credentials:"
    echo "    Admin URL: https://$HOSTNAME:8083"
    echo "    Username:  admin"
    echo "    Password:  ${ADMIN_PASSWORD}"
    echo
    echo "[ ! ] IMPORTANT: It is recommended to restart the container before continuing!"
fi
