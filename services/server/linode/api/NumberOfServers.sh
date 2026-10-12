curl -s -H "Authorization: Bearer $LINODE_CLI_TOKEN" \
     "https://linode.com" | \
     jq "[.data[] | select(.label | contains(\"${server_type}\"))] | length"
