#!/bin/sh

database_id="${1}"


BUILD_HOME=$(/bin/cat /home/buildhome.dat)
DATABASE_DBaaS_INSTALLATION_TYPE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh DATABASE_DBaaS_INSTALLATION_TYPE`"
MULTI_REGION="`${BUILD_HOME}/helpers/services/GetVariableValue.sh MULTI_REGION`"
PRIMARY_REGION="`${BUILD_HOME}/helpers/services/GetVariableValue.sh PRIMARY_REGION`"
TOKEN="`${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN`"

db_name="`/bin/echo ${DATABASE_DBaaS_INSTALLATION_TYPE} | /usr/bin/awk -F':' '{print $8}'`"
db_username="`/bin/echo ${DATABASE_DBaaS_INSTALLATION_TYPE} | /usr/bin/awk -F':' '{print $9}'`"
db_password="`/bin/echo ${DATABASE_DBaaS_INSTALLATION_TYPE} | /usr/bin/awk -F':' '{print $10}'`"

if ( [ "${MULTI_REGION}" = "1" ] && [ "${PRIMARY_REGION}" = "1" ] )
then
	db_scope_prefix="public-"
else
	db_scope_prefix=""
fi

export database_id
export CLUSTER_NAME="`/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s -X GET "https://api.linode.com/v4/databases/postgresql/instances/${database_id}" | jq -r '.label'`"
export DB_IDENTIFIER="`/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s -X GET "https://api.linode.com/v4/databases/postgresql/instances/${database_id}" | jq -r '.hosts.primary'`"
export DB_USERNAME="`/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s -X GET "https://api.linode.com/v4/databases/postgresql/instances/${database_id}/credentials" | jq -r '.username'`"
export DB_PASSWORD="`/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s -X GET "https://api.linode.com/v4/databases/postgresql/instances/${database_id}/credentials" | jq -r '.password'`"
export DB_PORT="`/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s "https://api.linode.com/v4/databases/postgresql/instances/${database_id}" | jq -r '.port'`"
export DB_NAME="${db_name}"

for var_name in CLUSTER_NAME DB_IDENTIFIER DB_USERNAME DB_PASSWORD DB_PORT DB_NAME
do
    eval "var_val=\$$var_name"
    if [ -z "$var_val" ]; then
        status "Error: Required variable '$var_name' is not set or is empty."
        exit 1
    fi
done

if [ -n "${db_scope_prefix}" ]
then
    DB_IDENTIFIER=$(echo "${DB_IDENTIFIER}" | /bin/sed "s/^private-/${db_scope_prefix}/")
fi

export DB_USERNAME="${DB_USERNAME}:::${db_username}"
export DB_PASSWORD="${DB_PASSWORD}:::${db_password}"

cat <<EOF
CLUSTER_NAME='${CLUSTER_NAME}'
DB_IDENTIFIER='${DB_IDENTIFIER}'
DB_USERNAME='${DB_USERNAME}'
DB_PASSWORD='${DB_PASSWORD}'
DB_PORT='${DB_PORT}'
DB_NAME='${DB_NAME}'
EOF
