

token="${1}"
sever_id="${2}"

# Inject context variable securely for the local runtime tracking layer
export LINODE_CLI_TOKEN="${token}"

/usr/local/bin/linode-cli linodes ips-list ${server_id}

unset LINODE_CLI_TOKEN
