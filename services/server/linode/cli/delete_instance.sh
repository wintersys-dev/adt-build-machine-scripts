
token="${1}"
sever_id="${2}"

/usr/local/bin/linode-cli --no-defaults --json linodes delete "${server_id}"
