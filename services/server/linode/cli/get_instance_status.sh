token="${1}"
server_id="${2}"


/usr/local/bin/linode-cli linodes view ${server_id} --text --no-headers --format status
