#set -x
status () {
        ${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

BUILD_HOME="`/bin/cat /home/buildhome.dat`"
DATABASE_DBaaS_INSTALLATION_TYPE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh DATABASE_DBaaS_INSTALLATION_TYPE`"
TOKEN="`${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN`"
engine="`/bin/echo ${DATABASE_DBaaS_INSTALLATION_TYPE} | /usr/bin/awk -F':' '{print $3}'`"

available_engines="`/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s "https://api.linode.com/v4/databases/engines" | jq -r '.data[].id'`"

if [ $? -ne 0 ] || [ -z "$available_engines" ]
then
        status "Failed to obtain list of available engines"
        exit 1
fi

if ! echo "$available_engines" | /bin/grep -q -w "${engine}"
then
        status "The database engine you have selected is not available please correct and re deploy"
        exit 1
fi
