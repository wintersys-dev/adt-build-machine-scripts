firewall_id="${1}"
ruleset="${2}"

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

status () {
        ${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

TOKEN="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN)"

export LINODE_CLI_TOKEN="${TOKEN}"

/usr/local/bin/linode-cli firewalls rules-update --inbound "${ruleset}" "${firewall_id}"

if ( [ "$?" != "0" ] )
then
        unset LINODE_CLI_TOKEN
        status "Unable to update firewall rules"
        exit 1
fi 
