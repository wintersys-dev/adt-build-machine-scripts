#!/bin/sh

database_id="${1}"
db_name="${2}"

MULTI_REGION="`${BUILD_HOME}/helpers/services/GetVariableValue.sh MULTI_REGION`"
PRIMARY_REGION="`${BUILD_HOME}/helpers/services/GetVariableValue.sh PRIMARY_REGION`"

if ( [ "${MULTI_REGION}" = "1" ] && [ "${PRIMARY_REGION}" = "1" ] )
then
	db_scope_prefix="public-"
else
	db_scope_prefix=""
fi

export database_id
CLUSTER_NAME=$(/usr/local/bin/linode-cli databases mysql-list --no-defaults --json 2>/dev/null | /usr/bin/jq -r '.[] | select(.id == (env.database_id | tonumber)) | .label')
DB_IDENTIFIER=$(/usr/local/bin/linode-cli databases mysql-list --no-defaults --json 2>/dev/null | /usr/bin/jq -r '.[] | select(.id == (env.database_id | tonumber)) | .hosts.primary')
DB_USERNAME=$(/usr/local/bin/linode-cli databases mysql-creds-view "${database_id}" --no-defaults --json 2>/dev/null | /usr/bin/jq -r '.[].username')
DB_PASSWORD=$(/usr/local/bin/linode-cli databases mysql-creds-view "${database_id}" --no-defaults --json 2>/dev/null | /usr/bin/jq -r '.[].password')
DB_PORT=$(/usr/local/bin/linode-cli databases mysql-list --no-defaults --json 2>/dev/null | /usr/bin/jq -r '.[] | select(.id == (env.database_id | tonumber)).port')
DB_NAME="${db_name}"

if [ -n "${db_scope_prefix}" ]
then
    DB_IDENTIFIER=$(echo "${DB_IDENTIFIER}" | /bin/sed "s/^private-/${db_scope_prefix}/")
fi

cat <<EOF
CLUSTER_NAME='${CLUSTER_NAME}'
DB_IDENTIFIER='${DB_IDENTIFIER}'
DB_USERNAME='${DB_USERNAME}'
DB_PASSWORD='${DB_PASSWORD}'
DB_PORT='${DB_PORT}'
DB_NAME='${DB_NAME}'
EOF
