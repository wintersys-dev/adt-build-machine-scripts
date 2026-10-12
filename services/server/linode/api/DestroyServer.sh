


if [ "${server_ip}" != "" ]
then
    # 1. Lookup server ID by IP via API
    server_id="$(curl -s -H "Authorization: Bearer $LINODE_CLI_TOKEN" \
        "https://api.linode.com/v4/linode/instances" | \
        jq -r '.data[] | select(.ipv4[] == "'${server_ip}'").id')"
    
  #  if [ "${server_id}" = "" ]
  #  then
  #      # Fallback script lookup
  #      server_ip="$(${BUILD_HOME}/services/server/GetServerPublicIPAddressByIP.sh ${server_ip})"
  #      
  #      # 2. Retry lookup with fallback IP via API
  #      server_id="$(curl -s -H "Authorization: Bearer $LINODE_CLI_TOKEN" \
  #          "https://api.linode.com/v4/linode/instances" | \
  #          jq -r '.data[] | select(.ipv4[] == "'${server_ip}'").id')"
  #  fi
    
    if [ "${server_id}" != "" ]
    then
        # 3. API Shutdown command (POST /v4/linode/instances/{id}/shutdown)
        curl -s -X POST -H "Authorization: Bearer $LINODE_CLI_TOKEN" \
            "https://api.linode.com/v4/linode/instances/${server_id}/shutdown" > /dev/null
            
        # 4. API Delete command (DELETE /v4/linode/instances/{id})
        curl -s -X DELETE -H "Authorization: Bearer $LINODE_CLI_TOKEN" \
            https://api.linode.com/v4/linode/instances/${server_id}" > /dev/null
    fi
fi
