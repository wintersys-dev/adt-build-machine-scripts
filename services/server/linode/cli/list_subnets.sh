token="${1}"
vpc_id="${2}"

# Inject context variable securely for the local runtime tracking layer
export LINODE_CLI_TOKEN="${token}"

/usr/local/bin/linode-cli --no-defaults --json vpcs subnets-list ${vpc_id}

unset LINODE_CLI_TOKEN
