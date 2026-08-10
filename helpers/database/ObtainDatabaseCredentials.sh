#!/bin/sh

BUILD_HOME="`/bin/cat /home/buildhome.dat`"
CLOUDHOST="`${BUILD_HOME}/helpers/services/GetVariableValue.sh CLOUDHOST`"
REGION="`${BUILD_HOME}/helpers/services/GetVariableValue.sh REGION`"
DB_PORT="`${BUILD_HOME}/helpers/services/GetVariableValue.sh DB_PORT`"


/bin/echo "What is the build identifier you want to obtain database credentials for?"
/bin/echo "You have these builds to choose from: "

/bin/ls ${BUILD_HOME}/runtime/${CLOUDHOST}

if ( [ "${1}" != "" ] )
then
        BUILD_IDENTIFIER="${1}"         
else
        /bin/echo "Please enter the name of the build of the server you wish to connect with"
        read BUILD_IDENTIFIER
fi

/bin/echo "######################################################################################################################################################"
/bin/echo "The database public IP address is: `${BUILD_HOME}/services/server/GetServerIPAddresses.sh "db-${REGION}-${BUILD_IDENTIFIER}" "${CLOUDHOST}"`"
/bin/echo "The database private IP address is: `${BUILD_HOME}/services/server/GetServerPrivateIPAddresses.sh "db-${REGION}-${BUILD_IDENTIFIER}" "${CLOUDHOST}"` (try this one first from your application if it timesout, try the public one)"
/bin/echo "The database port is ${DB_PORT}"

if ( [ -f ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/build_environment ] )
then
        /bin/grep "^DB_NAME" ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/build_environment | /bin/sed 's/DB_NAME=/Database name: /'
        /bin/grep "^DB_PASSWORD" ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/build_environment | /bin/sed 's/DB_PASSWORD=/Database password: /'
        /bin/grep "^DB_USERNAME" ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/build_environment | /bin/sed 's/DB_USERNAME=/Database username: /'
else
        /bin/echo "Database credentials not available"
fi
/bin/echo "######################################################################################################################################################"
