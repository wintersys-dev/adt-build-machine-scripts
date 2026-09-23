set -x

BUILD_HOME="`/bin/cat /home/buildhome.dat`"
SSH_PORT="`${BUILD_HOME}/helpers/services/GetVariableValue.sh SSH_PORT`"
CLOUDHOST="`${BUILD_HOME}/helpers/services/GetVariableValue.sh CLOUDHOST`"
BUILD_IDENTIFIER="`${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILD_IDENTIFIER`"
MACHINE_PUBLIC_KEYS="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/keys/${machine_type}_${ip}keys"
ALGORITHM="`${BUILD_HOME}/helpers/services/GetVariableValue.sh ALGORITHM`"
SERVER_USER="`/bin/cat ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/credentials/SERVERUSER`"

machine_type="autoscaler"
machine_type_token="as"

if ( [ ! -f ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/scaling/scaling.conf ] )
then
        exit
else
        sourcefile="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/scaling/scaling.conf"
        /bin/cp ${sourcefile} ${sourcefile)-incoming
fi

token_to_match="${machine_type_token}-`${BUILD_HOME}/helpers/services/GetVariableValue.sh REGION`-${BUILD_IDENTIFIER}"

if ( [ -f ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/VPC-ACTIVE ] )
then
        ips="`${BUILD_HOME}/services/server/GetServerPrivateIPAddresses.sh ${token_to_match} ${CLOUDHOST} ${BUILD_HOME}`"
else
        ips="`${BUILD_HOME}/services/server/GetServerIPAddresses.sh ${token_to_match} ${CLOUDHOST} ${BUILD_HOME}`"
fi


for ip in ${ips}
do
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

		scaling_disabled="`/usr/bin/ssh -o ConnectTimeout=5 -o ConnectionAttempts=2 -o UserKnownHostsFile=${MACHINE_PUBLIC_KEYS} -o StrictHostKeyChecking=yes -p ${SSH_PORT} -i ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/keys/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${SERVER_USER}@${ip} "/usr/bin/test -f /home/${SERVER_USER}/runtime/scaling/SCALING_DISABLED && /bin/echo 'SCALING_DISABLED'"`" 

		if ( [ "${scaling_disabled}" = "SCALING_DISABLED" ] )
		then
			/bin/echo "Scaling  is disabled at the moment I have to bail"
			exit
		fi
done
