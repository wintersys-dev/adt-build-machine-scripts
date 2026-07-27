#!/bin/sh
##########################################################################################################
# Author: Peter Winter
# Date  : 13/07/2016
# Description : This script will copy a file to a selected directory on a remote machine
##########################################################################################################
# License Agreement:
# This file is part of The Agile Deployment Toolkit.
# The Agile Deployment Toolkit is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# The Agile Deployment Toolkit is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with The Agile Deployment Toolkit.  If not, see <http://www.gnu.org/licenses/>.
#######################################################################################################
#######################################################################################################
#set -x

if ( [ ! -f  ./CopyToRemoteMachine.sh ] )
then
        /bin/echo "Sorry, this script has to be run from the ${BUILD_HOME}/helpers/servers subdirectory"
        exit
fi

sourcefile="${1}"

if ( [ "${sourcefile}" = "" ] )
then
        /bin/echo "Please tell me the full path to the location of the file you wish to copy to the remote machine for example, ${BUILD_HOME}/migrationdirectory/archive.tar.gz"
        read sourcefile
        while ( [ "`/bin/ls ${sourcefile}`" = "" ] )
        do
                /bin/echo "Sorry, can't find that file please tell me again"
                /bin/echo "Please tell me the full path to the location of the file you wish to copy to the remote machine for example, ${BUILD_HOME}/migrationdirectory/archive.tar.gz"
                read sourcefile
        done
fi 

/bin/echo "Please enter the full path to the directory you would like to copy the file to on the remove machine. The user ${SERVER_USER} must have write permission"
read remotedir

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

/bin/echo "Which class of machine do you want to execute a command on? 1:Authenticator(s), 2:Autoscaler(s), 3:ReverseProxy(s), 4:Webserver(s), 5:Database 6:All Machines?"
/bin/echo "Please enter 1, 2,3,4,5 or 6"
read response

if ( [ "`/bin/echo 1 2 3 4 5 6 | /bin/grep ${response}`" = "" ] )
then
        /bin/echo "That's not a valid option"
        exit
fi

if ( [ "${response}" = "1" ] )
then
        machine_type="authenticator"
        machine_type_token="auth"
elif ( [ "${response}" = "2" ] )
then
        machine_type="autoscaler"
        machine_type_token="as"
elif ( [ "${response}" = "3" ] )
then
        machine_type="reverseproxy"
        machine_type_token="rp"
elif ( [ "${response}" = "4" ] )
then
        machine_type="webserver"
        machine_type_token="ws"
elif ( [ "${response}" = "5" ] )
then
        machine_type="database"
        machine_type_token="db"
elif ( [ "${response}" = "6" ] )
then
        machine_type="machine"
        machine_type_token=""
fi

/bin/echo "Which Cloudhost are you using? 1) Digital Ocean 2) Exoscale 3) Linode 4) Vultr. Please Enter the number for your cloudhost"
read response

if ( [ "${response}" = "1" ] )
then
        CLOUDHOST="digitalocean"
elif ( [ "${response}" = "2" ] )
then
        CLOUDHOST="exoscale"
elif ( [ "${response}" = "3" ] )
then
        CLOUDHOST="linode"
elif ( [ "${response}" = "4" ] )
then
        CLOUDHOST="vultr"
else
        /bin/echo "Unrecognised  cloudhost. Exiting ...."
        exit
fi

if ( [ "${CLOUDHOST}" != "`/bin/cat ${BUILD_HOME}/runtime/ACTIVE_CLOUDHOST`" ] )
then
        /bin/echo "Your chosen cloudhost provider is different to your active cloudhost provider on this build machine"
        /bin/echo "Do you want to set your chosen cloudhost to be the active cloudhost provider (Y|y)"
        read response
        if ( [ "${response}" = "Y" ] || [ "${response}" = "y" ] )
        then
                /bin/echo "${CLOUDHOST}" > ${BUILD_HOME}/runtime/ACTIVE_CLOUDHOST
        fi
fi

/bin/echo "What is the build identifier you want to connect to?"
/bin/echo "You have these builds to choose from: "

/bin/ls ${BUILD_HOME}/runtime/${CLOUDHOST}

/bin/echo "Please enter the name of the build of the server you wish to connect with"
read BUILD_IDENTIFIER
/bin/echo "${BUILD_IDENTIFIER}" > ${BUILD_HOME}/runtime/ACTIVE_BUILD_IDENTIFIER

if ( [ "${CLOUDHOST}" = "vultr" ] )
then
        export VULTR_API_KEY="`/bin/cat ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/TOKEN`"
fi

token_to_match="${machine_type_token}-`${BUILD_HOME}/helpers/services/GetVariableValue.sh REGION`-${BUILD_IDENTIFIER}"

if ( [ -f ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/VPC-ACTIVE ] )
then
        ips="`${BUILD_HOME}/services/server/GetServerPrivateIPAddresses.sh ${token_to_match} ${CLOUDHOST} ${BUILD_HOME}`"
else
        ips="`${BUILD_HOME}/services/server/GetServerIPAddresses.sh ${token_to_match} ${CLOUDHOST} ${BUILD_HOME}`"
fi

if ( [ "${ips}" = "" ] )
then
        /bin/echo "There doesn't seem to be any ${machine_type}s running"
        exit
fi

copy_to_all="0"
ip_selected="0"
response="N"
response1="N"
if ( [ "`/bin/echo ${ips} | /usr/bin/wc -w`" = "1" ] )
then
        MACHINE_IP="${ips}"
else
        /bin/echo "Do you want to execute your command on all your  ${machine_type} machines? (Y|y)"
        read response
        if ( [ "${response}" = "y" ] || [ "${response}" = "Y" ] )
        then
                copy_to_all="1"         
                MACHINE_IPS="${ips}"
        else
                /bin/echo "OK, which ${machine_type} would you like to connect to?"
                count="1"
                for ip in ${ips}
                do
                        if ( [ "${ip_selected}" = "0" ] )
                        then
                                /bin/echo "${count}:   ${ip}"
                                /bin/echo "Press Y/N to connect..."
                                read response1

                                if ( [ "${response1}" = "Y" ] || [ "${response1}" = "y" ] )
                                then
                                        MACHINE_IP=${ip}
                                        ip_selected="1"
                                fi
                                count="`/usr/bin/expr ${count} + 1`"
                        fi
                done
                if ( [ "${response1}" = "N" ] )
                then
                        exit
                fi
        fi
fi

if ( [ "${copy_to_all}" = "0" ] )
then
        MACHINE_IPS="${MACHINE_IP}"
fi


for MACHINE_IP in ${MACHINE_IPS}
do
        SERVER_USER="`/bin/cat ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/credentials/SERVERUSER`"
        SSH_PORT="`${BUILD_HOME}/helpers/services/GetVariableValue.sh SSH_PORT`"
        MACHINE_PUBLIC_KEYS="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/keys/${machine_type}_${MACHINE_IP}keys"

        if ( [ ! -f ${MACHINE_PUBLIC_KEYS} ] )
        then
                /usr/bin/ssh-keyscan  -p ${SSH_PORT} ${MACHINE_IP} > ${MACHINE_PUBLIC_KEYS}    
        fi

        if ( [ "`/bin/cat ${MACHINE_PUBLIC_KEYS}`" = "" ] )
        then
                /bin/echo "Couldn't initiate ssh key scan please try again (make sure the machine is online"
                /bin/rm ${MACHINE_PUBLIC_KEYS}
                exit
        fi

        if ( [ ! -f ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/build_environment ] )
        then
                ALGORITHM="rsa"
        else
                ALGORITHM="`${BUILD_HOME}/helpers/services/GetVariableValue.sh ALGORITHM`"
        fi

        /bin/echo
        /bin/echo "Copying file ${sourcefile} to machine with IP address:  ${MACHINE_IP}"
        /bin/echo 

        /usr/bin/scp -o ConnectTimeout=5 -o ConnectionAttempts=2 -o UserKnownHostsFile=${MACHINE_PUBLIC_KEYS} -o StrictHostKeyChecking=yes -P ${SSH_PORT} -i ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/keys/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${sourcefile} ${SERVER_USER}@${MACHINE_IP}:${remotedir}

done
