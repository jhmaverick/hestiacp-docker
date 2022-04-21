#!/bin/bash

source "/usr/local/hstc/func/env-file.sh"

# Starts a service if it is enabled to autostart
service_ctrl() {
    local service_name="$1"
    local action="$2" # start|stop|restart

    if [[ -z "$service_name" || ! -e "/etc/init.d/$service_name" ]]; then
        echo "Service \"$action\" not found"
        return
    fi

    if [[ -z "$action" || "$(echo "$action" | grep -Ev "^(start|stop|restart)$")" ]]; then
        echo "Action \"$action\" invalid"
        return
    fi

    if [[ "$(is_service_autostart_disabled "$service_name")" != "1" ]]; then
        bash "/etc/init.d/$service_name" "$action"
    fi
}

# Check if the service autostart is disabled
is_service_autostart_disabled() {
    local service_name="$1"
    local services_disabled="${AUTOSTART_DISABLED// /}"

    if [[ "$(echo ",${services_disabled}," | grep ",${service_name},")" ]]; then
        echo 1
    fi
}

# Check if the machine supports clamav
clamav_supported() {
    if (($(awk '/MemTotal/ {print $2}' /proc/meminfo) > 2000000)); then
        echo 1
    fi
}

# Start clamav if the machine supports it and if it is not disabled on autostart
clamav_start() {
    # Only start clamav if the system has more than 2GB of RAM
    if [[ "$(clamav_supported)" && "$(is_service_autostart_disabled "clamav-daemon")" != "1" ]]; then
        env_add /usr/local/hestia/conf/hestia.conf "ANTIVIRUS_SYSTEM" "clamav-daemon"
        sed -i "s/^#\(CLAMD =.*\)/\1/" /etc/exim4/exim4.conf.template

        /etc/init.d/clamav-daemon start
        service_ctrl clamav-freshclam start
    else
        /etc/init.d/clamav-daemon stop
        /etc/init.d/clamav-freshclam stop

        sed -i "s/\(^ANTIVIRUS_SYSTEM=\)\(.*\)/\1''/" /usr/local/hestia/conf/hestia.conf
        sed -i "s/^\(CLAMD =.*\)/#\1/" /etc/exim4/exim4.conf.template
    fi
}
