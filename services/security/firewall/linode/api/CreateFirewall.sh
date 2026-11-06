firewall_name="${1}"

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

status () {
        ${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

TOKEN="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN)"
BUILD_IDENTIFIER="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILD_IDENTIFIER)"

payload=$(jq -n --arg lbl "${firewall_name}-${BUILD_IDENTIFIER}" '{label: $lbl, rules: {inbound_policy: "DROP", outbound_policy: "ACCEPT"}}')
/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- curl -s -X POST 'https://api.linode.com/v4/networking/firewalls' --json "${payload}" | jq -r '.id'

if [ "$?" != "0" ] 
then
        status "Unable to create firewall"
        exit 1        
fi
