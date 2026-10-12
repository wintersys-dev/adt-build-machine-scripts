curl -s -H "Authorization: Bearer $LINODE_CLI_TOKEN" \
     "https://linode.com" 2>/dev/null | \
     jq -r '.data[] | select(.label | contains("'${server_type}'")).ipv4[]' 2>/dev/null
