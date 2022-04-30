ARG HESTIACP_SOURCE=base

FROM debian:buster AS hestiacp-base

LABEL maintainer="João Henrique <joao_henriquee@outlook.com>"

ENV DEBIAN_FRONTEND=noninteractive \
    APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1 \
    RUN_IN_CONTAINER=1

RUN apt-get -y update \
    && apt-get -y upgrade \
    && apt-get -y install --no-install-recommends liblwp-protocol-https-perl wget curl locales git zip unzip \
        sudo apt-utils build-essential libpam-pwdfile libwww-perl rsyslog sysv-rc-conf software-properties-common \
        iptables iproute2 dnsutils iputils-ping net-tools strace lsof dsniff runit-systemd cron incron rsync file \
        jq acl openssl openvpn vim htop geoip-database dirmngr gnupg zlib1g-dev lsb-release apt-transport-https \
        ca-certificates perl libperl-dev libgd3 libgd-dev libgeoip1 libgeoip-dev geoip-bin libxml2 libxml2-dev \
        libxslt1.1 libxslt1-dev libxslt-dev lftp libmaxminddb0 libmaxminddb-dev mmdb-bin python python3 python-pip \
        python3-pip isync gawk socat nmap \
    && test -L /sbin/chkconfig || ln -sf /usr/sbin/sysv-rc-conf /sbin/chkconfig \
    && test -L /sbin/nologin || ln -sf /usr/sbin/nologin /sbin/nologin \
    && rm -rf /var/lib/apt/lists/*

RUN sed -ie 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
    && locale-gen en_US.UTF-8 \
    && dpkg-reconfigure locales \
    && update-locale LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8 LC_ALL=en_US.UTF-8 LC_CTYPE=en_US.UTF-8

ENV GTK_IM_MODULE=cedilla QT_IM_MODULE=cedilla \
    LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 LC_CTYPE=en_US.UTF-8 LANGUAGE=en_US.UTF-8


# Get systemctl script from docker systemctl replacement to avoid problems with systemd in docker
# https://github.com/gdraheim/docker-systemctl-replacement
RUN dsr_tag="v1.5.4505"; \
    wget https://raw.githubusercontent.com/gdraheim/docker-systemctl-replacement/${dsr_tag}/files/docker/systemctl3.py -O /usr/bin/systemctl \
    && chmod +x /usr/bin/systemctl \
    && test -L /bin/systemctl || ln -sf /usr/bin/systemctl /bin/systemctl \
    && wget https://raw.githubusercontent.com/gdraheim/docker-systemctl-replacement/${dsr_tag}/files/docker/journalctl3.py -O /usr/bin/journalctl \
    && chmod +x /usr/bin/journalctl \
    && test -L /bin/journalctl || ln -sf /usr/bin/journalctl /bin/journalctl


###
## Use local Hestia repository to build image
###
# Note: This process can increase the final image size and is only recommended during development.
# For production images, give preference to installation by cloning from the repository.
FROM hestiacp-base AS hestiacp-local

COPY hestiacp /tmp/hestiacp


###
## Install and cofigure Hestia
##
## * Clone the repository and perform a checkout for the chosen version tag;
## * Create an installer for docker making the necessary changes to run the installation;
## * Compile Hestia packages;
## * Run the installer with the compiled packages.
###
FROM hestiacp-$HESTIACP_SOURCE AS hestiacp-installed

ARG HESTIACP_REPOSITORY=https://github.com/hestiacp/hestiacp.git
ARG HESTIACP_BRANCH

ARG MULTIPHP_VERSIONS
ARG MARIADB_CLIENT_VERSION
# When a new version of zlib is released, the old one is removed and the build is broken.
# This argument makes it possible to change the version without having to update the autocompile script.
ARG ZLIB_VERSION

COPY rootfs/usr/local/hstc/install/generate-docker-installer.sh /tmp/generate-docker-installer.sh

# Clones the official repository if the local has not been added
RUN if [ ! -d /tmp/hestiacp ]; then \
        cd /tmp; \
        git clone $HESTIACP_REPOSITORY hestiacp; \
    fi \
    && cd /tmp/hestiacp \
    && if [ -n "$HESTIACP_BRANCH" ]; then \
        git checkout "$HESTIACP_BRANCH"; \
    fi \
# Apply changes to docker
    && bash /tmp/generate-docker-installer.sh /tmp/hestiacp \
### Temporary
    && if [ -n "$ZLIB_VERSION" ]; then \
        sed -Ei "s|^ZLIB_V=.*|ZLIB_V='$ZLIB_VERSION'|" /tmp/hestiacp/src/hst_autocompile.sh; \
    fi \
### Compile Hestia Packages
    && cd /tmp/hestiacp/src \
    && bash ./hst_autocompile.sh --all --noinstall --keepbuild '~localsrc' \
### Install Hestia
    && cd /tmp/hestiacp/install \
    && bash ./hst-install-debian-docker.sh --apache no --phpfpm yes --multiphp yes --vsftpd yes --proftpd no \
        --named yes --mysql yes --postgresql no --exim yes --dovecot yes --sieve yes --clamav yes --spamassassin yes \
        --iptables yes --fail2ban yes --quota yes --api yes --interactive no --port 8083 \
        --hostname server.hestiacp.localhost --email admin@example.com --password admin --lang en \
        --with-debs /tmp/hestiacp-src/deb/ --force \
# Remove the installation log from the root dir to keep it accessible after volumes are created
    && mv /root/hst_install_backups /opt/hst_install_backups \
# Cleanup image
#    && rm -rf /etc/apt/sources.list.d/* \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/*

ENV HESTIA=/usr/local/hestia \
    PATH=/usr/local/hestia/bin:$PATH

# Check if changes on Hestia were lost
RUN if grep "reload-or-restart" /usr/local/hestia/bin/v-restart-service; then \
        echo "Hestia's changes were lost"; \
        exit 1; \
    fi \
# Generate a diff log from the installer
    && diff /usr/local/hestia/install/hst-install-debian.sh /usr/local/hestia/install/hst-install-debian-docker.sh | tee /opt/hst_install_backups/installer-diff.txt >/dev/null \
# Remove autoupdate cron
    && /usr/local/hestia/bin/v-delete-cron-hestia-autoupdate \
# Remove buttons from Hestia update page
    && sed -i "/type=\"checkbox\"/d" /usr/local/hestia/web/templates/pages/list_updates.html \
    && sed -Ei "/href=\"<\?=\\\$btn_url\;\?>\"/d" /usr/local/hestia/web/templates/pages/list_updates.html \
# Block updates of Hestia packages in APT
    && apt-mark hold hestia \
    && apt-mark hold hestia-nginx \
    && apt-mark hold hestia-php \
# Removes all scripts that can update Hestia
    && echo 'exit' > /usr/local/hestia/bin/v-add-cron-hestia-autoupdate \
    && echo 'exit' > /usr/local/hestia/bin/v-delete-cron-hestia-autoupdate \
    && echo 'exit' > /usr/local/hestia/bin/v-update-sys-hestia \
    && echo 'exit' > /usr/local/hestia/bin/v-update-sys-hestia-all \
    && echo 'exit' > /usr/local/hestia/bin/v-update-sys-hestia-git \
# Checks if File Manager was installed with Hestia
    && if [ ! -d /usr/local/hestia/web/fm ]; then \
        /usr/local/hestia/bin/v-add-sys-filemanager; \
    fi \
# Removes dangerous functions that may cause some problems when running in the container
    && echo "" > /usr/local/hestia/bin/v-add-sys-filemanager \
    && echo "" > /usr/local/hestia/bin/v-delete-sys-filemanager \
    && echo "" > /usr/local/hestia/bin/v-add-sys-roundcube \
    && echo "" > /usr/local/hestia/bin/v-add-sys-rainloop \
    && echo "" > /usr/local/hestia/bin/v-add-sys-pma-sso \
    && echo "" > /usr/local/hestia/bin/v-delete-sys-pma-sso \
    && echo "" > /usr/local/hestia/bin/v-add-web-php \
    && echo "" > /usr/local/hestia/bin/v-delete-web-php


# Get "my_init" script from phusion baseimage
# https://github.com/phusion/baseimage-docker
RUN wget https://raw.githubusercontent.com/phusion/baseimage-docker/focal-1.0.0/image/bin/my_init -O /bin/my_init \
    && chmod +x /bin/my_init \
    && mkdir -p /etc/my_init.d


###
## HSTC configuration
###

FROM hestiacp-installed AS hestiacp-container

COPY rootfs /
ENV PATH=/usr/local/hstc/bin:$PATH

# Save build settings
ARG HSTC_IMAGE_VERSION
RUN echo "HSTC_IMAGE_VERSION=$HSTC_IMAGE_VERSION" >> /usr/local/hstc/build.conf \
    && echo "HESTIA_IMAGE_BUILD_DATE=$(date +'%Y-%m-%d\ %H:%M:%S')" >> /usr/local/hstc/build.conf \
# Apply necessary rewrites in Hestia
    && bash /usr/local/hstc/install/hestia-rewrite.sh \
# Create directories that will be used by volumes
    && mkdir -p /backup \
    && mkdir -p /conf

CMD ["/bin/my_init"]
EXPOSE 80 443 8083 3306 25 465 587 2525 143 993 110 995 53/udp 53/tcp 953/tcp 20 21 12000-12100 22222
VOLUME ["/conf", "/home", "/backup", "/var/log", "/var/cache/nginx", "/var/lib/clamav"]
WORKDIR /


###
## Configure persistent data.
##
## You can build the image by skipping this part and continue the build in another Dockerfile.
## Ex: ./docker-helper image-build stable --target=hestiacp-container
###
FROM hestiacp-container AS hestiacp

RUN bash /usr/local/hstc/install/add-default-persistent-files.sh
