#!/bin/bash

# Checks what type of run to do, initializes volumes if it's a first run, and restores system credentials

source "/usr/local/hstc/func/env-file.sh"

if [[ -f /var/run/hestiacp-startup.conf && ! "$(ls -A /conf)" && "$DEV_MODE" != "yes" ]]; then
    echo -e "\nWARNING:"
    echo -e "The \"/conf\" directory is empty but the container has already been started."
    echo -e "If the directory change was intentional, recreate the container and the data will be recreated."
    echo -e "If the cleanup was unintentional, check for data loss and restore the last backup."
    exit 1
fi

# Load build variables
env_read "/usr/local/hstc/build.conf"

HESTIA_VERSION="$(env_get_value /conf-start/usr/local/hestia/conf/hestia.conf "VERSION")"
CONTAINER_VERSION="$(env_get_value /usr/local/hestia/conf/hstc.conf "CONTAINER_VERSION")"

echo "-- HestiaCP Version: $HESTIA_VERSION"
echo "-- Image Version: $HSTC_IMAGE_VERSION"
if [[ -n "$CONTAINER_VERSION" && "$CONTAINER_VERSION" != "$HSTC_IMAGE_VERSION" ]]; then
    echo "-- Container Version: $CONTAINER_VERSION"
fi

# Check if the container was recreated or if it is the first running
if [[ -z "$(ls -A /conf)" ]]; then
    echo "-- First running detected"
    echo "   The startup will initializing the volumes and apply the necessary settings."
    echo

    echo "Initializing volumes..."
    rsync -uaz /conf-start/ /conf/
    rsync -uaz /home-start/ /home/

    env_add /var/run/hestiacp-startup.conf "FIRST_RUNNING" "yes"
    env_add /var/run/hestiacp-startup.conf "CONTAINER_RECREATED" "yes"

    env_add /usr/local/hestia/conf/hstc.conf "CONTAINER_VERSION" "$HSTC_IMAGE_VERSION"
    env_add /usr/local/hestia/conf/hstc.conf "CONTAINER_CREATE_DATE" "$(date +'%Y-%m-%d %H:%M:%S')"
elif [[ ! -f /var/run/hestiacp-startup.conf ]]; then
    echo "-- Container recreation detected."
    echo "   The startup will apply the necessary settings."

    env_add /var/run/hestiacp-startup.conf "FIRST_RUNNING" ""
    env_add /var/run/hestiacp-startup.conf "CONTAINER_RECREATED" "yes"
else
    env_add /var/run/hestiacp-startup.conf "FIRST_RUNNING" ""
    env_add /var/run/hestiacp-startup.conf "CONTAINER_RECREATED" ""
fi

chmod 600 /var/run/hestiacp-startup.conf

echo

restore_cred() {
    file_name="$1"

    if [[ -f "/conf/creds/$file_name" ]]; then
        while read -r line; do
            user="$(echo "$line" | sed -En "s|^([^:]*):.*|\1|p")"

            # Remove existing users from cred
            if [[ "$(grep -E "^$user:" "/etc/$file_name")" ]]; then
                sed -i "/^$user:/d" "/etc/$file_name"
            fi
        done <"/conf/creds/$file_name"

        # Cleanup file to prevent duplicated lines and retore
        cat "/conf/creds/$file_name" | awk '!seen[$0]++' >>"/etc/$file_name"

        echo "$file_name restored"
    fi
}

# Restore users credentials
/etc/init.d/incron stop >/dev/null # Stop incron to prevent infinite loop
restore_cred "passwd"
restore_cred "shadow"
restore_cred "group"
restore_cred "gshadow"
echo

/etc/init.d/rsyslog start
/etc/init.d/incron start
