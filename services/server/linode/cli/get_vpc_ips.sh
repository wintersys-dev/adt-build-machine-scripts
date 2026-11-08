
# Inject context variable securely for the local runtime tracking layer
export LINODE_CLI_TOKEN="${token}"

/usr/local/bin/linode-cli vpcs ips-all-list --filterable '{"region": "'$region'"}'

unset LINODE_CLI_TOKEN
