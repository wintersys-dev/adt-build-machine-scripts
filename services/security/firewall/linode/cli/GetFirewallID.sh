
firewall_name="${1}"

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

status () {
        ${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

TOKEN="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN)"
BUILD_IDENTIFIER="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILD_IDENTIFIER)"

export LINODE_CLI_TOKEN="${TOKEN}"

firewall_id="`/usr/local/bin/linode-cli --json firewalls list | /usr/bin/jq -r '.[] | select (.label | contains ("'${firewall_name}'")) |  select (.label | endswith ("'-${BUILD_IDENTIFIER}'")).id'`"

if ( [ "$?" != "0" ] )
then
	unset LINODE_CLI_TOKEN
    status "Unable to get firewall ID"
    exit 1
fi
