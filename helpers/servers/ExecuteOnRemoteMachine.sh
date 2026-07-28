#!/bin/sh
######################################################################################################################################################
# Author: Peter Winter
# Date  : 13/07/2016
# Description : This script will connect you to your machine type via ssh and run the command passed as a parameter
######################################################################################################################################################
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

if ( [ ! -f  ./ExecuteOnRemoteMachine.sh ] )
then
        /bin/echo "Sorry, this script has to be run from the ${BUILD_HOME}/helpers/servers subdirectory"
        exit
fi

command="${1}"

if ( [ "${command}" = "" ] )
then
        /bin/echo "Sorry, this script needs to be passed a command"
        exit
elif ( [ "${command}" = "shutdown" ] )
then
        /bin/echo "This process will shutdown the machines you  select next, are you good with that, if so, press <enter>"
        read x
elif ( [ "${command}" = "reboot" ] )
then
        /bin/echo "This process will reboot the machines you  select next, are you good with that, if so, press <enter>"
        read x
elif ( [ "${command}" = "backup" ] || [ "${command}" = "backup-db" ] )
then
        if ( [ "${command}" = "backup" ] )
        then
                /bin/echo "You are asking me to make a backup of your application I need to know which perodicity you want, please enter one of: hourly daily weekly monthly bimonthly"        
                read period
        fi

        if ( [ "${command}" = "backup-db" ] )
        then
                /bin/echo "You are asking me to make a backup of your datbase I need to know which perodicity you want, please enter one of: hourly daily weekly monthly bimonthly"        
                read period
        fi

        if ( [ "`/bin/echo hourly daily weekly monthly bimonthly | /bin/grep "${period}"`" = "" ] )
        then
                /bin/echo "That's not a valid period"
                exit
        fi
elif ( [ "${command}" = "baseline" ] || [ "${command}" = "baseline-db" ] )
then
        if ( [ "${command}" = "baseline" ] )
        then
                /bin/echo "You are asking me to make a baseline of your application I need you to give me a the unique identifier of the empty repository you have prepared"
                /bin/echo "For example, if your repository is testwebsite-webroot-sourcecode-baseline then you need to enter 'testwebsite' at the prompt below"
                /bin/echo "Please enter the identifier now:"
                read identifier
        fi
        if ( [ "${command}" = "baseline-db" ] )
        then
                /bin/echo "You are asking me to make a baseline of your application database I need you to give me a the unique identifier of the empty repository you have prepared"
                /bin/echo "For example, if your repository is testwebsite-db-baseline then you need to enter 'testwebsite' at the prompt below"
                /bin/echo "Please enter the identifier now:"
                read identifier
        fi  
fi

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

if ( [ "${command}" != "backup" ] && [ "${command}" != "backup-db" ] )
then
        /bin/echo "Which class of machine do you want to execute a command on? 1:Authenticator(s), 2:Autoscaler(s), 3:ReverseProxy(s), 4:Webserver(s), 5:Database, 6: All Machines?"
        /bin/echo "Please enter 1, 2,3,4,5 or 6"
        read response
else
        if ( [ "${command}" = "backup" ] )
        then
                response="4"
        elif ( [ "${command}" = "backup-db" ] )
        then
                response="5" 
        fi
fi

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

execute_on_all="0"
ip_selected="0"
response="N"
response1="N"
if ( [ "`/bin/echo ${ips} | /usr/bin/wc -w`" = "1" ] )
then
        MACHINE_IP="${ips}"
else
        if ( [ "${command}" != "backup" ] && [ "${command}" != "backup-db" ] )
        then
                /bin/echo "Do you want to execute your command on all your ${machine_type} machines? (Y|y)"
                read response
                if ( [ "${response}" = "y" ] || [ "${response}" = "Y" ] )
                then
                        execute_on_all="1"         
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
        else
                if ( [ "${command}" = "backup" ] )
                then
                        no_webservers="`/bin/echo ${ips} | /usr/bin/wc -w`"
                        /bin/echo "There is ${no_webservers} running please enter which webserver number you want to make a back up of, in the range 1-${no_webservers}"
                        read webserver_no
                        if ( ! [ "${webserver_no}" -eq "${webserver_no}" ] ) 2>/dev/null 
                        then
                                /bin/echo "Sorry integers only"
                                exit
                        elif ( [ "${webserver_no}" -lt "1" ] || [ "${webserver_no}" -gt "${no_webservers}" ] )
                        then
                                /bin/echo "That's outside the range of machine indexes"
                                exit
                        fi
                elif ( [ "${command}" = "backup-db" ] )
                then
                        webserver_no="1"
                fi
                MACHINE_IP="`/bin/echo ${ips} | /usr/bin/cut -d " " -f ${webserver_no}`"
        fi
fi

if ( [ "${execute_on_all}" = "0" ] )
then
        MACHINE_IPS="${MACHINE_IP}"
fi


for MACHINE_IP in ${MACHINE_IPS}
do
        SERVER_USERNAME="`/bin/cat ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/credentials/SERVERUSER`"
        SERVER_USER_PASSWORD="`/bin/cat ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/credentials/SERVERUSERPASSWORD`"
        SUDO="DEBIAN_FRONTEND=noninteractive /bin/echo ${SERVER_USER_PASSWORD} | /usr/bin/sudo -S "
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
        /bin/echo "Executing command on machine with IP address ${MACHINE_IP}"
        /bin/echo 

        if ( [ "${command}" = "shutdown" ] )
        then
                /usr/bin/ssh -o ConnectTimeout=5 -o ConnectionAttempts=2 -o UserKnownHostsFile=${MACHINE_PUBLIC_KEYS} -o StrictHostKeyChecking=yes -p ${SSH_PORT} -i ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/keys/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${SERVER_USERNAME}@${MACHINE_IP} "${SUDO} /home/${SERVER_USERNAME}/webserver/TakeWebserverOffline.sh"
                /usr/bin/ssh -o ConnectTimeout=5 -o ConnectionAttempts=2 -o UserKnownHostsFile=${MACHINE_PUBLIC_KEYS} -o StrictHostKeyChecking=yes -p ${SSH_PORT} -i ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/keys/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${SERVER_USERNAME}@${MACHINE_IP} "${SUDO} /home/${SERVER_USERNAME}/utilities/housekeeping/ShutdownThisMachine.sh halt"
        elif ( [ "${command}" = "reboot" ] )
        then
                /usr/bin/ssh -o ConnectTimeout=5 -o ConnectionAttempts=2 -o UserKnownHostsFile=${MACHINE_PUBLIC_KEYS} -o StrictHostKeyChecking=yes -p ${SSH_PORT} -i ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/keys/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${SERVER_USERNAME}@${MACHINE_IP} "${SUDO} /usr/sbin/shutdown -r now"
        elif ( [ "${command}" = "backup" ] )
        then
                /usr/bin/ssh -o ConnectTimeout=5 -o ConnectionAttempts=2 -o UserKnownHostsFile=${MACHINE_PUBLIC_KEYS} -o StrictHostKeyChecking=yes -p ${SSH_PORT} -i ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/keys/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${SERVER_USERNAME}@${MACHINE_IP} "${SUDO} /home/${SERVER_USERNAME}/application/backup/Backup.sh ${period} ${BUILD_IDENTIFIER}"
        elif ( [ "${command}" = "backup-db" ] )
        then
                /usr/bin/ssh -o ConnectTimeout=5 -o ConnectionAttempts=2 -o UserKnownHostsFile=${MACHINE_PUBLIC_KEYS} -o StrictHostKeyChecking=yes -p ${SSH_PORT} -i ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/keys/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${SERVER_USERNAME}@${MACHINE_IP} "${SUDO} /home/${SERVER_USERNAME}/application/backup/Backup.sh ${period} ${BUILD_IDENTIFIER}"
        elif ( [ "${command}" = "baseline" ] )
        then
                /usr/bin/ssh -o ConnectTimeout=5 -o ConnectionAttempts=2 -o UserKnownHostsFile=${MACHINE_PUBLIC_KEYS} -o StrictHostKeyChecking=yes -p ${SSH_PORT} -i ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/keys/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${SERVER_USERNAME}@${MACHINE_IP} "${SUDO} /home/${SERVER_USERNAME}/application/baseline/CreateBaseline.sh ${identifier}"
        elif ( [ "${command}" = "baseline-db" ] )
        then
                /usr/bin/ssh -o ConnectTimeout=5 -o ConnectionAttempts=2 -o UserKnownHostsFile=${MACHINE_PUBLIC_KEYS} -o StrictHostKeyChecking=yes -p ${SSH_PORT} -i ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/keys/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${SERVER_USERNAME}@${MACHINE_IP} "${SUDO} /home/${SERVER_USERNAME}/application/baseline/CreateDBBaseline.sh ${identifier}"
        elif ( [ "${command}" = "prevent-webserver-temination" ] )
        then
                /usr/bin/ssh -o ConnectTimeout=5 -o ConnectionAttempts=2 -o UserKnownHostsFile=${MACHINE_PUBLIC_KEYS} -o StrictHostKeyChecking=yes -p ${SSH_PORT} -i ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/keys/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${SERVER_USERNAME}@${MACHINE_IP} "${SUDO} /bin/touch /home/${SERVER_USERNAME}/runtime/PREVENT_WEBSERVER_TERMINATIONS"
        elif ( [ "${command}" = "reenable-webserver-temination" ] )
        then
                /usr/bin/ssh -o ConnectTimeout=5 -o ConnectionAttempts=2 -o UserKnownHostsFile=${MACHINE_PUBLIC_KEYS} -o StrictHostKeyChecking=yes -p ${SSH_PORT} -i ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/keys/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${SERVER_USERNAME}@${MACHINE_IP} "${SUDO} /bin/rm /home/${SERVER_USERNAME}/runtime/PREVENT_WEBSERVER_TERMINATIONS"
        else
                /usr/bin/ssh -o ConnectTimeout=5 -o ConnectionAttempts=2 -o UserKnownHostsFile=${MACHINE_PUBLIC_KEYS} -o StrictHostKeyChecking=yes -p ${SSH_PORT} -i ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/keys/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${SERVER_USERNAME}@${MACHINE_IP} "${command}"
        fi
done
