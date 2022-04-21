#!/bin/bash

# Default persistent files list

mkdir -p /conf-start

#bash /usr/local/hstc/install/make-persistent.sh /etc/bind/conf.d
bash /usr/local/hstc/install/make-persistent.sh /etc/bind/named.conf yes
bash /usr/local/hstc/install/make-persistent.sh /etc/bind/named.conf.options yes
bash /usr/local/hstc/install/make-persistent.sh /etc/exim4/domains
bash /usr/local/hstc/install/make-persistent.sh /etc/fail2ban/jail.local yes
bash /usr/local/hstc/install/make-persistent.sh /etc/nginx/conf.d/domains
#bash /usr/local/hstc/install/make-persistent.sh /etc/nginx/conf.d/fastcgi_cache_pool.conf yes
bash /usr/local/hstc/install/make-persistent.sh /etc/nginx/conf.d/pre-domains
for php_path in /etc/php/*; do
    php_version="$(basename -- "$php_path")";
    bash /usr/local/hstc/install/make-persistent.sh /etc/php/${php_version}/fpm/pool.d;
done
bash /usr/local/hstc/install/make-persistent.sh /etc/phpmyadmin/conf.d
bash /usr/local/hstc/install/make-persistent.sh /etc/roundcube/config.inc.php yes
bash /usr/local/hstc/install/make-persistent.sh /etc/ssh
bash /usr/local/hstc/install/make-persistent.sh /etc/ssl
bash /usr/local/hstc/install/make-persistent.sh /root
bash /usr/local/hstc/install/make-persistent.sh /usr/local/hestia/data
bash /usr/local/hstc/install/make-persistent.sh /usr/local/hestia/conf
bash /usr/local/hstc/install/make-persistent.sh /usr/local/hestia/ssl
bash /usr/local/hstc/install/make-persistent.sh /usr/local/hestia/web/rrd
#bash /usr/local/hstc/install/make-persistent.sh /var/lib/clamav
bash /usr/local/hstc/install/make-persistent.sh /var/lib/fail2ban
bash /usr/local/hstc/install/make-persistent.sh /var/spool/cron/crontabs

mv /home /home-start
