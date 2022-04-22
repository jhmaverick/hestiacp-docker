#!/bin/bash

source "/usr/local/hstc/func/env-file.sh"

# Startup variables
env_read /var/run/hestiacp-startup.conf

if [[ "$FIRST_RUNNING" != "yes" && "$CONTAINER_RECREATED" == "yes" ]]; then
    # Check version update
    bash /usr/local/hstc/bin/v-update-container-data
fi

# Configuring server hostname
/usr/local/hestia/bin/v-change-sys-hostname "$HOSTNAME" >/dev/null 2>&1

# Update exim configs
echo "$HOSTNAME" >/etc/mailname
sed -i "s/\(^dc_other_hostnames=\)\(.*\)/\1'$HOSTNAME'/" /etc/exim4/update-exim4.conf.conf
update-exim4.conf

# Update server resolv and IP
if [[ ! "$(grep -E "^nameserver 1.1.1.1$" /etc/resolv.conf)" ]]; then
    # Apply Cloudflare IPs to resolver
    echo -e "$(cat /etc/resolv.conf | sed -E "/^nameserver 127.0.0.11$/a nameserver 1.1.1.1\nnameserver 1.0.0.1\nnameserver 127.0.0.1")" >/etc/resolv.conf

    # Fix container IP in docker network
    /usr/local/hstc/bin/v-update-container-ip
fi
echo
