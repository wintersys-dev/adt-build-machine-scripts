

status () {
	${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

BUILD_HOME="`/bin/cat /home/buildhome.dat`"
DATABASE_DBaaS_INSTALLATION_TYPE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh DATABASE_DBaaS_INSTALLATION_TYPE`"
label="`/bin/echo ${DATABASE_DBaaS_INSTALLATION_TYPE} | /usr/bin/awk -F':' '{print $7}'`"
TOKEN="`${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN`"

max_attempts=50   # Maximum number of checks
sleep_interval=20 # Time to wait between checks (in seconds)
attempt=1

status "Waiting for database '$label' to become active..."

while true 
do
    db_status="`/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s "https://api.linode.com/v4/databases/mysql/instances" | jq -r '.data[] | select(.label == "'${label}'").status'`"

    if [ -z "$db_status" ]
    then
        status "Database '$label' not found or API error. Retrying..."
    elif [ "$db_status" = "active" ]
    then
        status "Database is ready and active!"
        break
    elif [ "$db_status" = "failed" ] || [ "$db_status" = "error" ]
    then
        status "Database deployment failed with status: $db_status"
        exit 1
    else
        status "Current status: '$db_status' (Attempt $attempt/${max_attempts})..."
    fi

    if [ "$attempt" -ge "${max_attempts}" ]
    then
        status "Timed out waiting for database to become active after $(/usr/bin/expr ${max_attempts} * ${sleep_interval})) seconds."
        exit 1
    fi

    attempt=$(/usr/bin/expr ${attempt} + 1)
    sleep "${sleep_interval}"
done
