#!/bin/bash

source "/usr/local/hstc/func/env-file.sh"

# Startup variables
env_read /var/run/hestiacp-startup.conf
# Load container variables
env_read /usr/local/hestia/conf/hstc.conf

run_sql() {
    current_pass="$(sed -e "s/\(.*PASSWORD='\)\([^']*\)\('.*\)/\2/" /usr/local/hestia/conf/mysql.conf)"
    mysql -u "root" -p"$current_pass" -h "mariadb" -e "$@" -s --skip-column-names
}

# Executa as rotinas da primeira execução que dependem dos serviços rodando
if [[ "$FIRST_RUNNING" == "yes" ]]; then
    export ADMIN_PASSWORD ROOT_DB_PASSWORD ROUNDCUBE_DB_PASSWORD PHPMYADMIN_DB_PASSWORD
    ADMIN_PASSWORD="$(v-gen-pass)"
    ROOT_DB_PASSWORD="$(v-gen-pass)"
    ROUNDCUBE_DB_PASSWORD="$(v-gen-pass)"
    PHPMYADMIN_DB_PASSWORD="$(v-gen-pass)"

    if [[ "${CONTAINER_INFRA,,}" == "local" ]]; then
        ADMIN_PASSWORD="admin"
        ROOT_DB_PASSWORD="root"
        ROUNDCUBE_DB_PASSWORD="roundcube"
        PHPMYADMIN_DB_PASSWORD="phpmyadmin"
    fi

    env_add /var/run/hestiacp-startup.conf "ADMIN_PASSWORD" "$ADMIN_PASSWORD"

    ###
    ## Hestia
    ###
    # Change admin password
    /usr/local/hestia/bin/v-change-user-password admin "$ADMIN_PASSWORD"

    # Change admin mail
    if [[ "$MAIL_ADMIN" ]]; then
        /usr/local/hestia/bin/v-change-user-contact admin "$MAIL_ADMIN"
    else
        /usr/local/hestia/bin/v-change-user-contact admin "admin@$HOSTNAME"
    fi

    ###
    ## MariaDB
    ###
    # Change mariadb root password
    /usr/bin/mysqladmin --host="mariadb" --user="root" --password="root" password "$ROOT_DB_PASSWORD"

    # Add MariaDB to Hestia Hosts
    /usr/local/hestia/bin/v-add-database-host mysql mariadb root "$ROOT_DB_PASSWORD" 500
    echo -e "[client]\nuser='root'\npassword='$ROOT_DB_PASSWORD'\n" >/root/.my.cnf
    chmod 600 /root/.my.cnf

    ###
    ## PHPMyAdmin
    ###
    if [[ -f /conf/etc/phpmyadmin/conf.d/01-localhost.php ]]; then
        rm -f /conf/etc/phpmyadmin/conf.d/01-localhost.php
    fi

    # Create user for phpmyadmin and apply in config file
    bash /usr/local/hestia/install/deb/phpmyadmin/pma.sh "$PHPMYADMIN_DB_PASSWORD"

    ###
    ## Roundcube
    ###
    # Create user for roundcube and apply in config file
    run_sql "CREATE DATABASE roundcube;"
    run_sql "GRANT ALL ON roundcube.* TO roundcube@'%' IDENTIFIED BY '$ROUNDCUBE_DB_PASSWORD';"
    run_sql "USE roundcube; source /var/lib/roundcube/SQL/mysql.initial.sql;"
    sed -Ei "s|(\\\$config\['db_dsnw'\] = ').*(';)|\1mysql://roundcube:$ROUNDCUBE_DB_PASSWORD@mariadb/roundcube\2|" /conf/etc/roundcube/config.inc.php

    ###
    ## ClamAV
    ###
    if [[ "${CONTAINER_INFRA,,}" != "local" ]]; then
        # Update clamav database
        /usr/bin/freshclam
    fi

    /etc/init.d/incron restart

    # Create first backup for credentials
    /usr/local/hstc/bin/v-backup-creds
fi
