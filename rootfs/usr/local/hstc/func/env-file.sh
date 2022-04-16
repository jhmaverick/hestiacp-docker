#!/bin/bash

# Add or update variable to env file.
#
# $1 - Path to env file.
# $2 - Variable name.
# $3 - Variable value.
env_add() {
    file="$1"
    name="$2"
    valor="$3"

    if [[ ! "$file" || ! "$name" ]]; then
        return
    fi

    if [[ -f "$file" && "$(grep -E "^${name}=" "$file")" ]]; then
        # Escape single quotes
        valor=${valor//\'/\'\\\'\'}
        # Escape Regex for sed
        valor="$(echo "$valor" | sed "s|[\`~!@#$%^&*()_=+{}\|;:\"',<.>/?-]|\\\&|g")"

        sed -Ei "s|(^$name=).*|\1'$valor'|" "$file"
    else
        # Make sure the directory exists
        [[ ! -d "$(dirname "$file")" ]] && mkdir -p "$(dirname "$file")"

        # Escape single quotes
        valor=${valor//\'/\'\\\'\'}
        # Escapa caracteres que devem ser mantidos para não ser necessário usar aspas
        #valor="$(echo "$valor" | sed "s|[\`#$&()\|;:\"'<> ]|\\\&|g")"

        echo -en "${name}='${valor}'\n" >>"$file"
    fi
}

# Include all variable from file with "export" arg.
#
# $1 - Path to env file.
env_read() {
    file="$1"

    if [[ "$file" && -f "$file" ]]; then
        source <(sed -E -n "s/[^#]+/export &/ p" "$file")
    fi
}

# Get variable value from env file.
#
# $1 - Path to env file.
# $2 - Variable name.
env_get_value() {
    file="$1"
    name="$2"

    if [[ "$file" && -f "$file" ]]; then
        source <(sed -E -n 's/[^#]+/local VAR_CHECK_&/ p' "$file")

        VALOR="$(eval 'echo $VAR_CHECK_'${name})"
        [[ "$VALOR" && "$VALOR" != '$' ]] && echo "$VALOR"
    fi
}

# Delete variable from env file.
#
# $1 - Path to env file.
# $2 - Variable name.
env_remove() {
    file="$1"
    name="$2"

    if [[ "$file" && -f "$file" && "$name" ]]; then
        sed -i "/^$name=/d" "$file"
    fi
}
