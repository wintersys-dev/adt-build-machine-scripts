#!/bin/sh

#set -x

firewall_name="${1}"
ruleset="${2}"

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

status () {
        ${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

TOKEN="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN)"
BUILD_IDENTIFIER="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILD_IDENTIFIER)"

firewall_id="$(/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s "https://api.linode.com/v4/networking/firewalls" | jq -r --arg name "${firewall_name}" --arg build "-${BUILD_IDENTIFIER}" '.data[] | select(.label | contains($name)) | select(.label | endswith($build)).id')"

if [ "${firewall_id}" = "" ] 
then
        payload=$(jq -n --arg lbl "${firewall_name}-${BUILD_IDENTIFIER}" '{label: $lbl, rules: {inbound_policy: "DROP", outbound_policy: "ACCEPT"}}')
        firewall_id="$(/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- curl -s -X POST 'https://api.linode.com/v4/networking/firewalls' --json "${payload}" | jq -r '.id')"

        if [ "$?" != "0" ] 
        then
                status "Unable to create firewall"
                exit 1        
        fi

else
        /bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s  -X PUT -H 'Content-Type: application/json' -d '{"inbound": [], "outbound": [], "inbound_policy": "DROP", "outbound_policy": "ACCEPT"}' 'https://api.linode.com/v4/networking/firewalls/'${firewall_id}'/rules'
        if [ "$?" != "0" ] 
        then
                status "Unable to update firewall rules"
                exit 1        
        fi
fi              

/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s -X PUT "https://api.linode.com/v4/networking/firewalls/${firewall_id}/rules" --json "$(jq -n --argjson rules "${ruleset}" '{inbound: $rules}')"
if [ "$?" != "0" ]   
then
        status "Unable to update firewall rules"
        exit 1          
fi                              

if ( [ "$?" = "0" ] )
then
        /bin/echo "ADT_FIREWALL_ID:${firewall_id}"
fi
