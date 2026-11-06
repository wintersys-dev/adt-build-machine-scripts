
firewall_id="${1}"
ruleset="${2}"

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

status () {
        ${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

TOKEN="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN)"


/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s -X PUT "https://api.linode.com/v4/networking/firewalls/${firewall_id}/rules" --json "$(jq -n --argjson rules "${ruleset}" '{inbound: $rules}')"
if [ "$?" != "0" ]   
then
        status "Unable to update firewall rules"
        exit 1          
fi  
