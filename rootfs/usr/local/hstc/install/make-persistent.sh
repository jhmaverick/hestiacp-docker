#!/bin/bash

# Make file or directory persistent
#
# 1. Recreate full file path in the /conf-start
# 2. Create symlink to /conf

path="$1" # File or directory path
create_incron_rule="${2:-no}"

full_path="$(readlink -e "$path")"
if [[ ! "$full_path" || "$(echo "$full_path" | grep -E "^(/conf|/home|/backup|/$)")" ]]; then
    echo "Invalid path."
    exit 1
fi

# Add rule in incron to recreate symlink in case it is replaced
if [[ -f "$full_path" && "${create_incron_rule,,}" == "yes" ]]; then
    echo "$full_path        IN_CLOSE_WRITE,IN_ATTRIB,IN_DELETE_SELF       /bin/bash /usr/local/hstc/bin/v-check-persistent-file \$@ \$% \$#" >> /var/spool/incron/root
fi

# Make sure the directory hierarchy exists
if [[ ! -d "$(dirname "/conf-start$full_path")" ]]; then
    mkdir -p "$(dirname "/conf-start$full_path")"
fi

# Move file to /conf-start for initialization and create a symlink pointing to /conf
mv -f "$full_path" "/conf-start$full_path"
ln -s "/conf$full_path" "$full_path"

# Save file path in the list
echo "${full_path} ${create_incron_rule}" /usr/local/container/persistent-files
