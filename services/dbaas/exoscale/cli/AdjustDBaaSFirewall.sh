#!/bin/sh

status () {
	${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

BUILD_HOME="`/bin/cat /home/buildhome.dat`"
DATABASE_DBaaS_INSTALLATION_TYPE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh DATABASE_DBaaS_INSTALLATION_TYPE`"
VPC_IP_RANGE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh VPC_IP_RANGE`"
        
database_details="`/bin/echo ${DATABASE_DBaaS_INSTALLATION_TYPE} | /bin/sed 's/^.*DBAAS://g'`"
database_region="`/bin/echo ${database_details} | /usr/bin/awk -F':' '{print $2}'`"
database_type="`/bin/echo "${DATABASE_DBaaS_INSTALLATION_TYPE}" | /usr/bin/awk -F':' '{print $1}'`"

if ( [ "${database_type}" = "MySQL" ] )
then
        /usr/bin/yes | /usr/bin/exo dbaas update --zone ${database_region} ${DB_NAME} --mysql-ip-filter="0.0.0.0/0"
        if ( [ "$?" != "0" ] )
        then
                status "Failed to update allowed ip addresses DBaaS"
                exit 1
        fi
elif ( [ "${database_type}" = "Postgres" ] )
then
        /usr/bin/yes | /usr/bin/exo dbaas update --zone ${database-region} ${DB_NAME} --pg-ip-filter="0.0.0.0/0"
        if ( [ "$?" != "0" ] )
        then
                status "Failed to update allowed ip addresses DBaaS"
                exit 1
        fi
 fi
