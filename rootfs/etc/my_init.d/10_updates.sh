#!/bin/bash

# Update persistent data
#
# The update will only be performed if the image version is higher than the one stored in the "/usr/local/hestia/conf/hstc.conf"

source /usr/local/hstc/func/env-file.sh

update_persistent_dir() {
    local dir_path="$1"
    dir_path="$(echo "$dir_path" | sed -E "s|/*$||")"

    # Checks if the directory exists in the new image
    if [[ -n "$dir_path" && -d "/conf-start$dir_path" ]]; then
        # Force the trailing slash to ensure the files in the directory will be synced and not it
        rsync -a "/conf-start$dir_path/" "/conf$dir_path"
#        if [[ -d "/conf$dir_path" ]]; then
#            cp -af "/conf-start$dir_path"/* "/conf$dir_path"
#        else
#            cp -af "/conf-start$dir_path" "/conf$dir_path"
#        fi
    fi
}

env_read /usr/local/hstc/build.conf
env_read /var/run/hestiacp-startup.conf

if [[ "$FIRST_RUNNING" != "yes" && "$CONTAINER_RECREATED" == "yes" ]]; then
    # Get current version of files in volume
    CURRENT_HSTC_VERSION="$(env_get_value /usr/local/hestia/conf/hstc.conf "CONTAINER_VERSION")"
    CHECK_HSTC_VERSION="$(/usr/local/hstc/bin/v-version-compare "$HSTC_IMAGE_VERSION" "$CURRENT_HSTC_VERSION" ">")"
    if [[ "$CHECK_HSTC_VERSION" == "1" ]]; then
        echo "-- The volumes files will be synchronized with the ones in the image"
        echo "Current version: $CURRENT_HSTC_VERSION"
        echo "Updating files to version: $HSTC_IMAGE_VERSION..."

        # Update version number in Hestia conf
        CURRENT_HESTIA_VERSION=$(sed -En "s|^VERSION='(.*)'|\1|p" /conf/usr/local/hestia/conf/hestia.conf)
        NEW_HESTIA_VERSION=$(sed -En "s|^VERSION='(.*)'|\1|p" /conf-start/usr/local/hestia/conf/hestia.conf)
        if [[ "$NEW_HESTIA_VERSION" ]]; then
            env_add /usr/local/hestia/conf/hestia.conf "VERSION" "$NEW_HESTIA_VERSION"
        fi

        export CURRENT_HSTC_VERSION CURRENT_HESTIA_VERSION NEW_HESTIA_VERSION

        # Update persistent data
        update_persistent_dir /usr/local/hestia/data/api
        update_persistent_dir /usr/local/hestia/data/packages
        update_persistent_dir /usr/local/hestia/data/templates/mail/nginx
        update_persistent_dir /usr/local/hestia/data/templates/web/nginx
        update_persistent_dir /usr/local/hestia/data/templates/web/php-fpm
        update_persistent_dir /usr/local/hestia/data/templates/dns
        update_persistent_dir /usr/local/hestia/data/templates/web/unassigned
        update_persistent_dir /usr/local/hestia/data/templates/web/skel
        update_persistent_dir /usr/local/hestia/data/templates/web/suspend
        cp -af /conf-start/var/spool/cron/crontabs/root /var/spool/cron/crontabs/root

        # Check for new versions of php
        for php_path in /conf-start/etc/php/*; do
            php_version="$(basename -- "$php_path")"

            if [[ ! -d "/conf/etc/php/${php_version}" ]]; then
                cp -a "/conf-start/etc/php/${php_version}" "/conf/etc/php/${php_version}"
            fi
        done

        # Update users packages
        for package in /conf/usr/local/hestia/data/packages/*.pkg; do
            package_name="$(basename -- "$package")"
            package_name="${package_name%.*}"

            /usr/local/hestia/bin/v-update-user-package "$package_name"
        done

        # Run updates from container
        #
        # Some of the updates from Hestia's "upgrades" directory already exist in the container, so they need to be filtered
        # to ensure that only updates related to persistent data will be performed
        if [[ -d /usr/local/hstc/updates && "$(ls -A /usr/local/hstc/updates)" ]]; then
            update_list="$(/usr/local/hstc/bin/v-version-list "$CURRENT_HSTC_VERSION" /usr/local/hstc/updates)"
            for i in $update_list; do
                version="$(basename -- "$i")"
                version="${version%.*}"
                echo "- Running updates from version $version..."
                bash "$i"
                echo "Version $version updates completed"
            done
        fi

        # Update version number in the container conf
        env_add /usr/local/hestia/conf/hstc.conf "CONTAINER_VERSION" "$HSTC_IMAGE_VERSION"
    else
        echo -e "The file system is up to date!" >&2
        exit
    fi
fi
