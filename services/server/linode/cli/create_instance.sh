
token="${1}"
instance_payload="${2}"

# Inject context variable securely for the local runtime tracking layer
export LINODE_CLI_TOKEN="${token}"

/usr/local/bin/linode-cli --no-defaults --json linodes create "${instance_payload}"

unset LINODE_CLI_TOKEN
