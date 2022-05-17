#!/usr/bin/env bash

container_ip="$(ifconfig "$(/sbin/ip route | awk '/default/ { print $5 }')" | sed -En 's/.*inet ([^ ]*) .*/\1/p')"

# Add default server for container IP in NGINX
if [[ ! -e "/etc/nginx/conf.d/domains/$container_ip.conf" ]]; then
    cp -a /conf-start/etc/nginx/conf.d/domains/172.*.conf "/etc/nginx/conf.d/domains/$container_ip.conf"
    sed -Ei "s/(listen\s+).*(80|443)/\1${container_ip}:\2/g" "/etc/nginx/conf.d/domains/$container_ip.conf"

    if [[ -z "$(grep -E "listen\s+${container_ip}:80" "/etc/nginx/conf.d/domains/$container_ip.conf")" \
        || -z "$(grep -E "listen\s+${container_ip}:443" "/etc/nginx/conf.d/domains/$container_ip.conf")" ]]; then
        rm -f "/etc/nginx/conf.d/domains/$container_ip.conf"
    fi
fi
