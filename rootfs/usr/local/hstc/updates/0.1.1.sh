#!/usr/bin/env bash

if [[ -e /conf/etc/nginx/conf.d/domains/01_caching_pool.conf ]]; then
    mv -f /conf/etc/nginx/conf.d/domains/01_caching_pool.conf /conf/etc/nginx/conf.d/pre-domains/01_caching_pool.conf
fi
