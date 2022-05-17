#!/usr/bin/env bash

# Adjust permissions on executables
chmod +x /etc/my_init.d/*
chmod +x /usr/local/hstc/bin/*

# Add root user in incron
echo 'root' >> /etc/incron.allow

# Change incron permissions
chmod 600 /var/spool/incron/root

# Change cron permissions
chown root:crontab /var/spool/cron/crontabs/root
chmod 600 /var/spool/cron/crontabs/root

# Add "-f" to force cron execution
sed -Ei "s|/usr/sbin/logrotate /etc/logrotate.conf|/usr/sbin/logrotate -f /etc/logrotate.conf|" /etc/cron.daily/logrotate

# Disable sudo message
cat /etc/sudoers | sed -E "s|(Defaults\s*secure_path.*)|\1\nDefaults        lecture=\"never\"|" | tee /etc/sudoers >/dev/null

# Avoid errors on fail2ban startup due to missing logs
touch /var/log/dovecot.log
touch /var/log/roundcube/errors.log
chown www-data:www-data /var/log/roundcube/errors.log
touch /var/log/nginx/domains/dummy.error.log
chown www-data:adm /var/log/nginx/domains/dummy.error.log
touch /var/log/nginx/domains/dummy.access.log
chown www-data:adm /var/log/nginx/domains/dummy.access.log

# Remove existing socks to avoid service startup issues
rm -f /var/run/fail2ban/*

# Fix clamav run directory permissions
chown clamav:clamav -R /var/run/clamav

# Add dir for mariadb-bridge socket
mkdir -p /var/run/mysqld


###
## Hestia - NGINX and PHP
###
# Add permission so php can access directories on volumes
sed -Ei "s|(^php_admin_value\[open_basedir\].*)|\1:/conf/usr/local/hestia/:/conf/etc/ssh/|" /usr/local/hestia/php/etc/php-fpm.conf


###
## Hestia Scripts
###
# Change the path of "fastcgi_cache_pool.conf" to a directory on volume
find /usr/local/hestia -type f -print0 | xargs -0 sed -i "s|/etc/nginx/conf.d/fastcgi_cache_pool.conf|/etc/nginx/conf.d/pre-domains/fastcgi_cache_pool.conf|g"

# Remove "/conf" from key path to prevent error on comparison
sed -Ei "s|(^maybe_key_path=\".*)|\1\nmaybe_key_path=\"\\\$\(echo \"\\\$maybe_key_path\" \| sed \"s/^\\\/conf//\"\)\"|" /usr/local/hestia/bin/v-check-api-key


###
## Hestia Templates
###
# Change path to domains dir
sed -Ei "s|/etc/nginx/conf.d|/etc/nginx/conf.d/pre-domains|g" /usr/local/hestia/data/templates/web/nginx/caching.sh

# Fix include files path
sed -i "s|phppgadmin.inc|general/phppgadmin.inc|g" /usr/local/hestia/data/templates/web/nginx/php-fpm/*tpl
sed -i "s|phpmyadmin.inc|general/phpmyadmin.inc|g" /usr/local/hestia/data/templates/web/nginx/php-fpm/*tpl


###
## Hestia Web
###
# Fix path to rrd to prevent error on comparison
sed -i "s|\$dir_name != \$_SERVER\[\"DOCUMENT_ROOT\"\].'/rrd'|\!in_array\(\$dir_name, \[\$_SERVER[\"DOCUMENT_ROOT\"\].'/rrd', '/conf'.\$_SERVER\[\"DOCUMENT_ROOT\"\].'/rrd']\)|" /usr/local/hestia/web/list/rrd/image.php

# Remove mysql from services list
check_mysql_services="\nif \(isset\(\\\$data\['mysql'\]\)\) unset\(\\\$data\['mysql'\]\);"
check_mysql_services+="\nif \(isset\(\\\$data\['mariadb'\]\)\) unset\(\\\$data\['mariadb'\]\);"
sed -Ei "s|(ksort\(\\\$data\);)|\1$check_mysql_services|" /usr/local/hestia/web/list/server/index.php


###
## NGINX
###
mkdir -p /etc/nginx/conf.d/general
mkdir -p /etc/nginx/conf.d/pre-domains
mkdir -p /etc/nginx/conf.d/streams

# Change includes from nginx.conf
nginx_includes="include /etc/nginx/conf.d/general/*.conf;"
nginx_includes+="\n    include /etc/nginx/conf.d/pre-domains/*.conf;"
sed -i "s|include /etc/nginx/conf.d/\*.conf;|$nginx_includes|" /etc/nginx/nginx.conf

# Add stream in the end of nginx.conf
cat <<NEOF | tee -a /etc/nginx/nginx.conf >/dev/null

stream {
    log_format mysql '\$remote_addr [\$time_local] \$protocol \$status \$bytes_received '
                     '\$bytes_sent \$upstream_addr \$upstream_connect_time '
                     '\$upstream_first_byte_time \$upstream_session_time \$session_time';

    include /etc/nginx/conf.d/streams/*.conf;
}

NEOF

# Remove domains with docker IP
#rm -f /etc/nginx/conf.d/172.*.conf
mv /etc/nginx/conf.d/172.*.conf /etc/nginx/conf.d/domains

# Move configurations file to "general"
find /etc/nginx/conf.d/ -maxdepth 1 -type f -exec mv {} /etc/nginx/conf.d/general \;


###
## PHPMyAdmin
###
# Change PHPMyAdmin configuration script to enable connection to external MariaDB servers
sed -Ei "s|\\\$\(gen_pass\)|\\\${1:-\\\$\(/usr/local/hstc/bin/v-gen-pass\)}|" /usr/local/hestia/install/deb/phpmyadmin/pma.sh
sed -Ei "s|(\['host'\] = ')localhost(';)|\1mariadb\2|" /usr/local/hestia/install/deb/phpmyadmin/pma.sh
sed -Ei "s|@'localhost'|@'%'|g" /usr/local/hestia/install/deb/phpmyadmin/pma.sh
sed -Ei "s|\\\$HESTIA_INSTALL_DIR|/usr/local/hestia/install/deb|" /usr/local/hestia/install/deb/phpmyadmin/pma.sh


###
## SSH
###
# Change SSH port to prevent conflits with Host
sed -Ei "s|#?Port .*|Port 22222|" /etc/ssh/sshd_config
sed -i "s/PORT='22'/PORT='22222'/" /usr/local/hestia/data/firewall/rules.conf
sed -i "s/PORT='22'/PORT='22222'/" /usr/local/hestia/data/firewall/chains.conf
/usr/local/hestia/bin/v-update-firewall
