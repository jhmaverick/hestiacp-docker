#!/bin/bash

source "/usr/local/hstc/func/env-file.sh"
source "/usr/local/hstc/func/network.sh"

# Startup variables
env_read /var/run/hestiacp-startup.conf

container_interface="$(/sbin/ip route | awk '/default/ { print $5 }')"
current_container_ip="$(ifconfig "$container_interface" | sed -En 's/.*inet ([^ ]*) .*/\1/p')"
container_netmask="$(ifconfig "$container_interface" | sed -En 's/.*netmask ([^ ]*) .*/\1/p')"
container_network_init="$(echo "$current_container_ip" | awk -F . '{print $1"."$2"."$3}')"
container_zone_name="$(echo "$current_container_ip" | awk -F . '{print $4"."$3"."$2"."$1}').in-addr.arpa"

###
## Hostname settings
###
# Reapply hostname to hestia and exim
if [[ "$CONTAINER_RECREATED" == "yes" ]]; then
    /usr/local/hestia/bin/v-change-sys-hostname "$HOSTNAME" >/dev/null 2>&1

    echo "$HOSTNAME" >/etc/mailname
    sed -i "s/\(^dc_other_hostnames=\)\(.*\)/\1'$HOSTNAME; localhost'/" /etc/exim4/update-exim4.conf.conf
    update-exim4.conf
fi

###
## Saves hosts and IPs of other containers on the network so the container doesn't lose the reference after changing the resolver
###
# Force "mariadb" host as alternative to MariaDB container
add_host_from_network "$(dig +short mariadb @127.0.0.11)" "" "mariadb"

# Add all founded hosts in docker network
mapfile -t network_hosts < <(nmap -sP -oG - "${container_network_init}.*" --dns-servers 127.0.0.11 | awk '/^Host:/{print $2 " " $3}')
for ln in "${network_hosts[@]}"; do
    ip="$(echo "$ln" | awk '{print $1}')"
    host_name="$(echo "$ln" | awk '{print $2}' | sed -E "s/^\(|\)$//g")"

    [[ -n "$host_name" ]] && add_host_from_network "$ip" "$host_name"
done

###
## Bind settings
###
# Add a zone in the bind to resolve the IP of the container using the HOSTNAME
if [[ ! -e /etc/bind/db.container ]]; then
    cat <<EOF | sed -E "s/^\ {4}//g" | tee /etc/bind/db.container >/dev/null
    ;
    ; BIND reverse data file for local loopback interface
    ;
    \$TTL    3600
    @       IN      SOA     ns0.$HOSTNAME. root.ns0.$HOSTNAME. (
                         2012020801         ; Serial
                              21600         ; Refresh
                               3600         ; Retry
                            3600000         ; Expire
                             86400 )        ; Negative Cache TTL

    @       IN      NS      ns0.$HOSTNAME.
    @       IN      NS      ns1.$HOSTNAME.
    @       IN      NS      ns2.$HOSTNAME.
    @       14400   IN      PTR             $HOSTNAME.

EOF
fi

if [[ -z "$(grep "$container_zone_name" /etc/bind/named.conf.default-zones)" ]]; then
    echo "zone \"$container_zone_name\"  { type master; file \"/etc/bind/db.container\"; };" >>/etc/bind/named.conf.default-zones
fi

###
## Resolver and local IP settings
###
# Adds Cloudflare as resolver and prioritizes local IP to avoid problems with bind
if [[ -z "$(grep -E "^nameserver 1.1.1.1$" /etc/resolv.conf)" ]]; then
    echo -e "$(cat /etc/resolv.conf | sed -E "s/^(nameserver 127.0.0.11)$/nameserver 127.0.0.1\n\1\nnameserver 1.1.1.1\nnameserver 1.0.0.1/")" >/etc/resolv.conf
fi

if [[ "$CONTAINER_RECREATED" == "yes" ]]; then
    echo "[ * ] Configuring Container IP..."

    # Get the IP of the container in the last run
    if [[ "$FIRST_RUNNING" == "yes" ]]; then
        last_container_ip="$(ls /conf/usr/local/hestia/data/ips/)"
    else
        last_container_ip="$(env_get_value /usr/local/hestia/conf/hstc.conf "CONTAINER_IP")"
    fi

    # Try other ways to get the IP if it hasn't been recorded
    if [[ -z "$last_container_ip" ]]; then
        ips="$(ls /conf/usr/local/hestia/data/ips/)"

        if [[ "$(echo "$ips" | wc -l)" == 1 ]]; then
            # Only 1 registered IP
            last_container_ip="$ips"
        elif [[ -e /conf/usr/local/hestia/data/ips/127.0.0.1 ]]; then
            # Try with local IP
            last_container_ip="127.0.0.1"
        else
            # Consider the oldest IP as the IP of the container
            last_container_ip="$(cd /conf/usr/local/hestia/data/ips && ls -1tr * 2>/dev/null | head -1)"
        fi
    fi

    if [[ -n "$last_container_ip" ]]; then
        # Rename the old IP to the new one
        if [[ "$last_container_ip" != "$current_container_ip" ]]; then
            mv "/conf/usr/local/hestia/data/ips/$last_container_ip" "/conf/usr/local/hestia/data/ips/$current_container_ip"
        fi

        # Update in Hestia IPs
        sed -Ei "s/(^INTERFACE=).*/\1'$container_interface'/" "/conf/usr/local/hestia/data/ips/$current_container_ip"
        sed -Ei "s/(^NETMASK=).*/\1'$container_netmask'/" "/conf/usr/local/hestia/data/ips/$current_container_ip"

        # Change IP directly in settings to avoid rebuilding users which takes a long time
        if [[ "$last_container_ip" != "$current_container_ip" ]]; then
            # Update in Hestia firewall
            sed -i "s/$last_container_ip/$current_container_ip/g" /conf/usr/local/hestia/data/firewall/*.conf

            # Update users
            for f in /home/*; do
                user="$(basename -- "$f")"

                # Web
                sed -i "s/$last_container_ip/$current_container_ip/g" "/conf/usr/local/hestia/data/users/$user/web.conf"
                #sed -i "s/$last_container_ip/$current_container_ip/g" "/home/$user/conf/web/"*/*.conf 2>/dev/null
                sed -i "s/$last_container_ip/$current_container_ip/g" "/home/$user/conf/web/"*/nginx.conf 2>/dev/null
                sed -i "s/$last_container_ip/$current_container_ip/g" "/home/$user/conf/web/"*/nginx.ssl.conf 2>/dev/null

                # Mail
                sed -i "s/$last_container_ip/$current_container_ip/g" "/home/$user/conf/mail/"*/ip 2>/dev/null
                #sed -i "s/$last_container_ip/$current_container_ip/g" "/home/$user/conf/mail/"*/*.conf 2>/dev/null
                sed -i "s/$last_container_ip/$current_container_ip/g" "/home/$user/conf/mail/"*/nginx.conf 2>/dev/null
                sed -i "s/$last_container_ip/$current_container_ip/g" "/home/$user/conf/mail/"*/nginx.ssl.conf 2>/dev/null

                # DNS
                sed -i "s/$last_container_ip/$current_container_ip/g" "/conf/usr/local/hestia/data/users/$user/dns.conf"
                sed -i "s/$last_container_ip/$current_container_ip/g" "/conf/usr/local/hestia/data/users/$user/dns/"*.conf 2>/dev/null
                sed -i "s/$last_container_ip/$current_container_ip/g" "/home/$user/conf/dns/"*.db 2>/dev/null
            done

            # Update default NGINX server
            if [[ ! -e "/etc/nginx/conf.d/domains/$current_container_ip.conf" ]]; then
                if [[ -e "/etc/nginx/conf.d/domains/$last_container_ip.conf" ]]; then
                    mv "/etc/nginx/conf.d/domains/$last_container_ip.conf" "/etc/nginx/conf.d/domains/$current_container_ip.conf"
                else
                    cp -a /conf-start/etc/nginx/conf.d/domains/172.*.conf "/etc/nginx/conf.d/domains/$current_container_ip.conf"
                fi

                sed -Ei "s/(listen\s+).*(80|443)/\1${current_container_ip}:\2/g" "/etc/nginx/conf.d/domains/$current_container_ip.conf"

                if [[ -z "$(grep -E "listen\s+${current_container_ip}:80" "/etc/nginx/conf.d/domains/$current_container_ip.conf")" || -z "$(grep -E "listen\s+${current_container_ip}:443" "/etc/nginx/conf.d/domains/$current_container_ip.conf")" ]]; then
                    rm -f "/etc/nginx/conf.d/domains/$current_container_ip.conf"
                fi
            fi

            if [[ -e "/etc/nginx/conf.d/domains/$last_container_ip.conf" ]]; then
                rm -f "/etc/nginx/conf.d/domains/$last_container_ip.conf"
            fi

            # Update IP on NGINX
            #if [[ -n "$(ls /etc/nginx/conf.d/domains/)" ]]; then
            #    sed --follow-symlinks -Ei "s|(listen\s+)$last_container_ip:|\1$current_container_ip:|g" /etc/nginx/conf.d/domains/* 2>/dev/null
            #fi
        fi

        # Update nat
        container_ip_nat="$(sed -En "s/^NAT='(.*)'$/\1/p" "/conf/usr/local/hestia/data/ips/$current_container_ip")"
        pub_ip=$(curl --ipv4 -s https://ip.hestiacp.com/)
        if [[ "$pub_ip" != "$container_ip_nat" ]]; then
            /usr/local/hestia/bin/v-change-sys-ip-nat "$current_container_ip" "$pub_ip" 2>/dev/null
        fi

        /usr/local/hestia/bin/v-restart-dns
        /usr/local/hestia/bin/v-update-firewall

        echo "Current IP $current_container_ip -> $pub_ip"
    else
        # Reset IPs if none are found
        /usr/local/hestia/bin/v-update-sys-ip
    fi

    env_add /usr/local/hestia/conf/hstc.conf "CONTAINER_IP" "$current_container_ip"
fi
