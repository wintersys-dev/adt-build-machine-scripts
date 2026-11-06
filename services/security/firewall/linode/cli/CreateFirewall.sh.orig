
firewall_name="${1}"

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

status () {
        ${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

TOKEN="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN)"
BUILD_IDENTIFIER="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILD_IDENTIFIER)"

export LINODE_CLI_TOKEN="${TOKEN}"

firewall_id="`/usr/local/bin/linode-cli firewalls create --json --label "${firewall_name}-${BUILD_IDENTIFIER}" --rules.inbound_policy DROP   --rules.outbound_policy ACCEPT | /usr/bin/jq -r '.[].id'`"
       
if ( [ "$?" != "0" ] )
then
	unset LINODE_CLI_TOKEN
	status "Unable to create firewall"
	exit 1
fi
