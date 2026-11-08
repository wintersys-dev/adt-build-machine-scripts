token="${1}"
region="${2}"

# Inject context variable securely for the local runtime tracking layer
export LINODE_CLI_TOKEN="${token}"

/usr/local/bin/linode-cli --no-defaults --json vpcs list --region ${region}

unset LINODE_CLI_TOKEN
