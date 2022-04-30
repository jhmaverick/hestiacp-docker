#!/bin/bash

# Saves the list of IPs and hosts on the same network
add_host_from_network() {
    local ip="$1"
    local host_name="$2"
    local alternatives="$3"

    if [[ -z "$ip" && -z "$host_name" ]]; then
        echo "Invalid"
        return
    elif [[ -z "$ip" ]]; then
        ip="$(dig +short "$host_name" @127.0.0.11)"
    elif [[ -z "$host_name" ]]; then
        host_name="$(host "$ip" 127.0.0.11 | awk '($4 == "pointer"){print $5}' | sed "s|\.$||")"
        #host_name="$(nslookup "$ip" 127.0.0.11 | awk '($2 == "name"){print $4}' | sed "s|\.$||")"
    fi

    local hosts="" host_base=""
    if [[ -n "$host_name" && -z "$(grep "^$ip\s" /etc/hosts)" ]]; then
        if [[ -z "$(echo " $alternatives " | grep " $host_name ")" ]]; then
            hosts+=" $host_name"
        fi

        if [[ -n "$alternatives" ]]; then
            hosts+=" $alternatives"
        fi

        host_base="$(echo "$host_name" | sed -En "s|([^.]*).*|\1|p")"
        if [[ "$host_base" != "$host_name" && -z "$(echo " $hosts " | grep " $host_base ")" ]]; then
            hosts+=" $host_base"
        fi

        hosts="$(echo "$hosts" | sed -E "s/^\s|\s$//g")"
        echo "$ip -> $hosts"
        echo "$ip    $hosts" >> /etc/hosts
    fi
}
