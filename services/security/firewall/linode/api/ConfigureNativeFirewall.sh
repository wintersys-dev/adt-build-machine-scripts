#!/bin/sh


TOKEN="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN)"
BUILD_IDENTIFIER="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILD_IDENTIFIER)"

firewall_id="`/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s 'https://api.linode.com/v4/networking/firewalls' | jq -r '.data[] | select(.label | contains("'${firewall_name}'")) | select(.label | endswith("'-${BUILD_IDENTIFIER}'")).id'`"
if ( [ "$?" != "0" ] )
then
        status "Unable to get firewall id"
        exit 1
fi

if ( [ "${firewall_id}" = "" ] )
then
        firewall_id="`/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s -X POST -H 'Content-Type: application/json' -d '{"label": "'${firewall_name}-${BUILD_IDENTIFIER}'", "rules": {"inbound_policy": "DROP", "outbound_policy": "ACCEPT"}}' 'https://api.linode.com/v4/networking/firewalls' | jq -r '.id'`"
        if ( [ "$?" != "0" ] )
        then
                status "Unable to get create firewall"
                exit 1
        fi
else
        /bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s  -X PUT -H 'Content-Type: application/json' -d '{"inbound": [], "outbound": [], "inbound_policy": "DROP", "outbound_policy": "ACCEPT"}' 'https://api.linode.com/v4/networking/firewalls/'${firewall_id}'/rules'
        if ( [ "$?" != "0" ] )
        then
                status "Unable to update firewall rules"
                exit 1        fi
fi              
                
/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s -X PUT -H 'Content-Type: application/json' -d '{"inbound": '"${ruleset}"'}'  'https://api.linode.com/v4/networking/firewalls/'${firewall_id}'/rules'
if ( [ "$?" != "0" ] )  
then
        status "Unable to update firewall rules"
        exit 1          fi                              

if ( [ "$?" = "0" ] )
then
        /bin/echo "ADT_FIREWALL_ID:${firewall_id}"
fi
