
token="${1}"
vpc_payload="${2}"

# Inject context variable securely for the local runtime tracking layer
export LINODE_CLI_TOKEN="${token}"

/usr/local/bin/linode-cli --no-defaults --json vpcs create "${vpc_payload}"

unset LINODE_CLI_TOKEN
