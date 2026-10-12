curl -s -H "Authorization: Bearer $LINODE_CLI_TOKEN" \
     "https://api.linode.com/v4/linode/instances" | \
     jq '[.data[] | select(.label | contains("'${server_type}'"))] | length'
