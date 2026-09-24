#!/bin/sh

set -x

machine_type="autoscaler"
machine_type_token="as"

BUILD_HOME="`/bin/cat /home/buildhome.dat`"
SSH_PORT="`${BUILD_HOME}/helpers/services/GetVariableValue.sh SSH_PORT`"
CLOUDHOST="`${BUILD_HOME}/helpers/services/GetVariableValue.sh CLOUDHOST`"
BUILD_IDENTIFIER="`${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILD_IDENTIFIER`"
ALGORITHM="`${BUILD_HOME}/helpers/services/GetVariableValue.sh ALGORITHM`"
SERVER_USER="`/bin/cat ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/credentials/SERVERUSER`"
MACHINE_PUBLIC_KEYS="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/keys/${machine_type}_${ip}keys"

ip="${1}"

if ( [ ! -f ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/scaling/scaling.conf ] )
then
        exit
else
        sourcefile="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/scaling/scaling.conf"
        /bin/cp ${sourcefile} ${sourcefile}-incoming
fi

if ( [ ! -f ${MACHINE_PUBLIC_KEYS} ] )
then
        /usr/bin/ssh-keyscan  -p ${SSH_PORT} ${ip} > ${MACHINE_PUBLIC_KEYS}
fi

if ( [ "`/bin/cat ${MACHINE_PUBLIC_KEYS}`" = "" ] )
then
        /bin/echo "Couldn't initiate ssh key scan please try again (make sure the machine is online"
        /bin/rm ${MACHINE_PUBLIC_KEYS}
        exit
fi
/usr/bin/ssh -o ConnectTimeout=5 -o ConnectionAttempts=2 -o UserKnownHostsFile=${MACHINE_PUBLIC_KEYS} -o StrictHostKeyChecking=yes -p ${SSH_PORT} -i ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/keys/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${SERVER_USER}@${ip} "/bin/mkdir -p /home/${SERVER_USER}/runtime/scaling" 2>/dev/null
/usr/bin/scp -o ConnectTimeout=5 -o ConnectionAttempts=2 -o UserKnownHostsFile=${MACHINE_PUBLIC_KEYS} -o StrictHostKeyChecking=yes -P ${SSH_PORT} -i ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/keys/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${sourcefile}-incoming ${SERVER_USER}@${ip}:/home/${SERVER_USER}/runtime/scaling
