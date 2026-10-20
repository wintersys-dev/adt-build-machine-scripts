#!/bin/sh

status () {
        /bin/echo "${1}" | /usr/bin/tee /dev/fd/3 2>/dev/null
        script_name="`/bin/echo ${0} | /usr/bin/awk -F'/' '{print $NF}'`"
        /bin/echo "${script_name}: ${1}" | /usr/bin/tee -a /dev/fd/4 2>/dev/null
}

BUILD_HOME="`/bin/cat /home/buildhome.dat`"
TOKEN="`${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN`"
DATABASE_DBaaS_INSTALLATION_TYPE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh DATABASE_DBaaS_INSTALLATION_TYPE`"
VPC_IP_RANGE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh VPC_IP_RANGE`"

database_type="`/bin/echo ${DATABASE_DBaaS_INSTALLATION_TYPE} | /usr/bin/awk -F':' '{print $1}'`"
label="`/bin/echo ${DATABASE_DBaaS_INSTALLATION_TYPE} | /usr/bin/awk -F':' '{print $7}'`"

if ( [ "${database_type}" = "MySQL" ] )
then
  database_id="`/usr/local/bin/linode-cli databases mysql-list --no-defaults --json | jq -r '.[] | select(.label | contains ("'${label}'")) | .id'`"
  if ( [ "$?" != "0" ] )
  then
    status "Failed to get the database id"
    exit 1
  fi
  /usr/local/bin/linode-cli databases mysql-update ${database_id} --allow_list ${VPC_IP_RANGE} --no-defaults
  if ( [ "$?" != "0" ] )
  then
    status "Failed to set allowed ip addresses for DBaaS"
    exit 1
  fi
elif ( [ "${database_type}" = "Postgres" ] )
then    
  database_id="`/usr/local/bin/linode-cli databases postgresql-list --no-defaults --json | /usr/bin/jq '.[] | select(.label | contains ("'${label}'")) | .id'`"
  if ( [ "$?" != "0" ] )
  then
    status "Failed to get the database id"
    exit 1
  fi
  /usr/local/bin/linode-cli databases mysql-update ${database_id} --allow_list ${VPC_IP_RANGE} --no-defaults 
  if ( [ "$?" != "0" ] )
  then
    status "Failed to set allowed ip addresses for DBaaS"
    exit 1
  fi
fi
