#!/bin/sh

status () {
	${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

BUILD_HOME="`/bin/cat /home/buildhome.dat`"
TOKEN="`${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN`"
DATABASE_DBaaS_INSTALLATION_TYPE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh DATABASE_DBaaS_INSTALLATION_TYPE`"
VPC_IP_RANGE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh VPC_IP_RANGE`"

database_type="`/bin/echo ${DATABASE_DBaaS_INSTALLATION_TYPE} | /usr/bin/awk -F':' '{print $1}'`"
label="`/bin/echo ${DATABASE_DBaaS_INSTALLATION_TYPE} | /usr/bin/awk -F':' '{print $7}'`"

if ( [ "${database_type}" = "MySQL" ] )
then
  database_id="`/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s https://api.linode.com/v4/databases/mysql/instances | jq -r --arg lbl "$label" '.data[] | select(.label == $lbl) | .id'`"
  if ( [ "$?" != "0" ] )
  then
    status "Failed to get the database id"
    exit 1
  fi
  /bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s -X PUT "https://api.linode.com/v4/databases/mysql/instances/${database_id}" -H "Content-Type: application/json"  -d '{"allow_list": ["'${VPC_IP_RANGE}'"]}'
  if ( [ "$?" != "0" ] )
  then
    status "Failed to set allowed ip addresses for DBaaS"
    exit 1
  fi
elif ( [ "${database_type}" = "Postgres" ] )
then    
  database_id="`/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s https://api.linode.com/v4/databases/postgresql/instances | jq -r --arg lbl "$label" '.data[] | select(.label == $lbl) | .id'`"

  if ( [ "$?" != "0" ] )
  then
    status "Failed to get the database id"
    exit 1
  fi
  /bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s -X PUT "https://api.linode.com/v4/databases/postgresql/instances/${database_id}" -H "Content-Type: application/json"  -d '{"allow_list": ["'${VPC_IP_RANGE}'"]}'
  if ( [ "$?" != "0" ] )
  then
    status "Failed to set allowed ip addresses for DBaaS"
    exit 1
  fi
fi
  
