if ( [ "`curl -s -H "Authorization: Bearer $LINODE_CLI_TOKEN" \
     "https://linode.com" | \
     jq -e '.data[] | select(.label | contains("'${server_type}'")).status | select(. == "running")' >/dev/null 2>&1`" ] )
then
    /bin/echo "running"
else
    /bin/echo "not running"
fi
