#!/bin/bash

source "/usr/local/hstc/func/env-file.sh"

# Startup variables
env_read /var/run/hestiacp-startup.conf

# Defining return code check function
check_result() {
    if [ $1 -ne 0 ]; then
        echo "Error: $2"
        exit $1
    fi
}

# Start service
init_service() {
    service_name="$1"
    /bin/systemctl start "$service_name" >> $LOG
    check_result $? "$service_name start failed"
}

# Update hestia firewall
/usr/local/hestia/bin/v-update-firewall

/etc/init.d/hestia start
# Start all services
for php_service in /etc/init.d/php*-fpm; do
    bash "$php_service" start
done
/etc/init.d/nginx start
/etc/init.d/bind9 start
/etc/init.d/fail2ban start
/etc/init.d/exim4 start
/etc/init.d/dovecot start
/etc/init.d/ssh start
/etc/init.d/vsftpd start

# Checks if the system has more than 2GB of ram
if [[ "${CONTAINER_INFRA,,}" != "local" ]] && (($(awk '/MemTotal/ {print $2}' /proc/meminfo) > 2000000)); then
    env_add /usr/local/hestia/conf/hestia.conf "ANTIVIRUS_SYSTEM" "clamav-daemon"
    sed -i "s/^#\(CLAMD =.*\)/\1/" /etc/exim4/exim4.conf.template

    /etc/init.d/clamav-daemon start
    /etc/init.d/clamav-freshclam start
else
    sed -i "s/\(^ANTIVIRUS_SYSTEM=\)\(.*\)/\1''/" /usr/local/hestia/conf/hestia.conf
    sed -i "s/^\(CLAMD =.*\)/#\1/" /etc/exim4/exim4.conf.template
    /etc/init.d/clamav-daemon stop
    /etc/init.d/clamav-freshclam stop
fi

/etc/init.d/spamassassin start
/etc/init.d/cron start

env_add /var/run/hestiacp-startup.conf "STARTUP_DATE" "$(date +'%Y-%m-%d %H:%M:%S')"
