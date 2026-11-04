set -x
status () {
        ${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

BUILD_HOME="`/bin/cat /home/buildhome.dat`"
DATABASE_DBaaS_INSTALLATION_TYPE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh DATABASE_DBaaS_INSTALLATION_TYPE`"
TOKEN="`${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN`"
label="`/bin/echo ${DATABASE_DBaaS_INSTALLATION_TYPE} | /usr/bin/awk -F':' '{print $7}'`"

export LINODE_CLI_TOKEN="${TOKEN}"
database_id=$(/usr/local/bin/linode-cli databases postgresql-list --no-defaults --json | jq --arg lbl "$label" '.[] | select(.label | contains($lbl)) | .id' 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$database_id" ]
then
        status "Database ID not available for label ${label}"
        unset LINODE_CLI_TOKEN
        exit 1
fi

unset LINODE_CLI_TOKEN
/bin/echo ${database_id}
