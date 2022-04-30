#!/bin/bash

source "/usr/local/hstc/func/env-file.sh"
source "/usr/local/hstc/func/services.sh"

# Startup variables
env_read /var/run/hestiacp-startup.conf

# Update hestia firewall
/usr/local/hestia/bin/v-update-firewall

systemctl start mariadb-bridge
service_ctrl hestia start
for php_service in /etc/init.d/php*-fpm; do
    service_name="$(basename -- "$php_service")"
    service_ctrl "$service_name" start
done
service_ctrl nginx start
service_ctrl bind9 start
service_ctrl fail2ban start
service_ctrl exim4 start
service_ctrl dovecot start
service_ctrl ssh start
service_ctrl vsftpd start
clamav_start
service_ctrl spamassassin start
service_ctrl cron start

env_add /var/run/hestiacp-startup.conf "STARTUP_DATE" "$(date +'%Y-%m-%d %H:%M:%S')"
