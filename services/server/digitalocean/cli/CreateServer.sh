#!/bin/sh
###################################################################################
# Author : Peter Winter
# Date   : 13/07/2016
# Description : This script will spin up a new server of the size, region and os
# specified  on the hosting provider, cloudhost, of choice.
###################################################################################
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
####################################################################################
####################################################################################
#set -x

server_size="${1}"
server_name="${2}"

BUILD_HOME="`/bin/cat /home/buildhome.dat`"
CLOUDHOST="`/bin/cat ${BUILD_HOME}/runtime/ACTIVE_CLOUDHOST`"
BUILD_IDENTIFIER="`/bin/cat ${BUILD_HOME}/runtime/ACTIVE_BUILD_IDENTIFIER`"

BUILDOS="`${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILDOS`"
BUILDOS_VERSION="`${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILDOS_VERSION`"
REGION="`${BUILD_HOME}/helpers/services/GetVariableValue.sh REGION`"
VPC_IP_RANGE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh VPC_IP_RANGE`"
VPC_NAME="`${BUILD_HOME}/helpers/services/GetVariableValue.sh VPC_NAME`"
ACTIVE_FIREWALL="`${BUILD_HOME}/helpers/services/GetVariableValue.sh ACTIVE_FIREWALLS`"
ALGORITHM="`${BUILD_HOME}/helpers/services/GetVariableValue.sh ALGORITHM`"
BUILD_FROM_SNAPSHOT="`${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILD_FROM_SNAPSHOT`"
OS_CHOICE="`${BUILD_HOME}/services/server/GetOperatingSystemVersion.sh ${CLOUDHOST} ${BUILDOS} ${BUILDOS_VERSION} | /bin/sed "s/'//g"`"

if ( [ "`/bin/echo ${server_name} | /bin/grep -E "\-as-"`" != "" ] )
then


	if ( [ -f  ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/autoscaler.yaml ] )
	then
		server_name_match="`/bin/grep "^hostname: " ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/autoscaler.yaml | /usr/bin/awk '{print $NF}'`"
		/bin/sed -i "s/XXXXAUTOSCALER_HOSTNAMEXXXX/${server_name}/g" ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/autoscaler.yaml
		/bin/sed -i "s/${server_name_match}/${server_name}/g" ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/autoscaler.yaml
		
			cloud_config="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/autoscaler.yaml"
	fi
elif ( [ "`/bin/echo ${server_name} | /bin/grep -E "^ws-"`" != "" ] )
then
	if ( [ -f  ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/webserver.yaml ] )
	then
		server_name_match="`/bin/echo ${server_name} | /usr/bin/awk -F'-' 'NF{NF--};1' | /bin/sed 's/ /-/g'`"
		/bin/sed -i "s/XXXXWEBSERVER_HOSTNAMEXXXX/${server_name}/g" ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/webserver.yaml
		/bin/sed -i "s/${server_name_match}.*$/${server_name}/g" ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/webserver.yaml
		
			cloud_config="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/webserver.yaml"
	fi
elif ( [ "`/bin/echo ${server_name} | /bin/grep -E "^db-"`" != "" ] )
then
	if ( [ -f  ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/database.yaml ] )
	then
		/bin/sed -i "s/XXXXDATABASE_HOSTNAMEXXXX/${server_name}/g" ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/database.yaml

			cloud_config="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/database.yaml"
	fi
elif ( [ "`/bin/echo ${server_name} | /bin/grep -E "\-auth-"`" != "" ] )
then
	if ( [ -f  ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/authenticator.yaml ] )
	then
		server_name_match="`/bin/grep "^hostname: " ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/authenticator.yaml | /usr/bin/awk '{print $NF}'`"
		/bin/sed -i "s/XXXXAUTHENTICATOR_HOSTNAMEXXXX/${server_name}/g" ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/authenticator.yaml
		/bin/sed -i "s/${server_name_match}/${server_name}/g" ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/authenticator.yaml

			cloud_config="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/authenticator.yaml"
	fi
elif ( [ "`/bin/echo ${server_name} | /bin/grep -E "\-rp-"`" != "" ] )
then
	if ( [ -f  ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/reverseproxy.yaml ] )
	then		
		server_name_match="`/bin/grep "^hostname: " ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/reverseproxy.yaml | /usr/bin/awk '{print $NF}'`"
		/bin/sed -i "s/XXXXREVERSEPROXY_HOSTNAMEXXXX/${server_name}/g" ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/reverseproxy.yaml
		/bin/sed -i "s/${server_name_match}/${server_name}/g" ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/reverseproxy.yaml
		
			cloud_config="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/reverseproxy.yaml"
	fi
fi

if ( [ "`/bin/echo ${server_name} | /bin/grep -E "\-as-"`" != "" ] )
then
	machine_type="adt-autoscaler"
	if ( [ "${BUILD_FROM_SNAPSHOT}" = "1" ] && [ -f ${BUILD_HOME}/runtime/wholemachinesnapshots/${WEBSITE_URL}/snapshots/snapshot_ids.dat ] )
	then
		snapshot_id="`/bin/grep autoscaler ${BUILD_HOME}/runtime/wholemachinesnapshots/${WEBSITE_URL}/snapshots/snapshot_ids.dat | /usr/bin/awk -F':' '{print $NF}'`"
 	fi
elif ( [ "`/bin/echo ${server_name} | /bin/grep -E "^ws-"`" != "" ] )
then
	machine_type="adt-webserver"
	if (  [ "${BUILD_FROM_SNAPSHOT}" = "1" ] && [ -f ${BUILD_HOME}/runtime/wholemachinesnapshots/${WEBSITE_URL}/snapshots/snapshot_ids.dat ] )
	then
		snapshot_id="`/bin/grep webserver ${BUILD_HOME}/runtime/wholemachinesnapshots/${WEBSITE_URL}/snapshots/snapshot_ids.dat | /usr/bin/awk -F':' '{print $NF}'`"
		${BUILD_HOME}/helpers/services/SetVariableValue.sh SNAPSHOT_ID=${snapshot_id}
 	fi
elif ( [ "`/bin/echo ${server_name} | /bin/grep -E "^db-"`" != "" ] )
then
	machine_type="adt-database"
	if (  [ "${BUILD_FROM_SNAPSHOT}" = "1" ] && [ -f ${BUILD_HOME}/runtime/wholemachinesnapshots/${WEBSITE_URL}/snapshots/snapshot_ids.dat ] )
	then
		snapshot_id="`/bin/grep database ${BUILD_HOME}/runtime/wholemachinesnapshots/${WEBSITE_URL}/snapshots/snapshot_ids.dat | /usr/bin/awk -F':' '{print $NF}'`"
 	fi
elif ( [ "`/bin/echo ${server_name} | /bin/grep -E "\-auth-"`" != "" ] )
then
	machine_type="adt-authenticator"
	if (  [ "${BUILD_FROM_SNAPSHOT}" = "1" ] && [ -f ${BUILD_HOME}/runtime/wholemachinesnapshots/${WEBSITE_URL}/snapshots/snapshot_ids.dat ] )
	then
		snapshot_id="`/bin/grep authenticator ${BUILD_HOME}/runtime/wholemachinesnapshots/${WEBSITE_URL}/snapshots/snapshot_ids.dat | /usr/bin/awk -F':' '{print $NF}'`"
 	fi
elif ( [ "`/bin/echo ${server_name} | /bin/grep -E "\-rp-"`" != "" ] )
then
	machine_type="adt-reverseproxy"
	if (  [ "${BUILD_FROM_SNAPSHOT}" = "1" ] && [ -f ${BUILD_HOME}/runtime/wholemachinesnapshots/${WEBSITE_URL}/snapshots/snapshot_ids.dat ] )
	then
		snapshot_id="`/bin/grep reverseproxy ${BUILD_HOME}/runtime/wholemachinesnapshots/${WEBSITE_URL}/snapshots/snapshot_ids.dat | /usr/bin/awk -F':' '{print $NF}'`"
 	fi
fi

	if ( [ ! -f ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/SSH_KEY_ASSIGNED ] )
	then
		/bin/touch ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/SSH_KEY_ASSIGNED
		key_id="`/usr/local/bin/doctl compute ssh-key list -o json | /usr/bin/jq -r '.[] | select ( .name == "AGILE_TOOLKIT_PUBLIC_KEY-'${BUILD_IDENTIFIER}'" ).id'`"
		if ( [ "${key_id}" != "" ] )
		then
			/usr/local/bin/doctl compute ssh-key delete ${key_id} --force
		fi

		/usr/local/bin/doctl compute ssh-key create "AGILE_TOOLKIT_PUBLIC_KEY-${BUILD_IDENTIFIER}" --public-key "`/bin/cat ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/keys/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER}.pub`"

	fi

	while ( [ "`/usr/local/bin/doctl compute ssh-key list -o json | /usr/bin/jq '.[] | select (.name == "AGILE_TOOLKIT_PUBLIC_KEY-'${BUILD_IDENTIFIER}'").id'`" = "" ] )
	do
		/bin/sleep 2
	done

	key_id="`/usr/local/bin/doctl compute ssh-key list -o json | /usr/bin/jq '.[] | select (.name == "AGILE_TOOLKIT_PUBLIC_KEY-'${BUILD_IDENTIFIER}'").id'`" 

	if ( [ "${key_id}" = "" ] )
	then
		/bin/touch /tmp/END_IT_ALL
	fi

	if ( [ "`/usr/local/bin/doctl vpcs list -o json | /usr/bin/jq -r '.[] | select (.region == "'${REGION}'") | select (.name == ("'${VPC_NAME}'")).id'`" = "" ] )
	then
		/usr/local/bin/doctl vpcs create --name "${VPC_NAME}" --region "${REGION}" --ip-range "${VPC_IP_RANGE}"
	fi

	vpc_id="`/usr/local/bin/doctl vpcs list -o json | /usr/bin/jq -r '.[] | select (.region == "'${REGION}'") | select (.name == ("'${VPC_NAME}'")).id'`"

	image="--image ${OS_CHOICE}"
	if ( [ "${BUILD_FROM_SNAPSHOT}" = "1" ] )
	then
		image="--image ${snapshot_id}"
  	fi

	/usr/local/bin/doctl compute droplet create "${server_name}" --ssh-keys "${key_id}" --size "${server_size}" ${image} --region "${REGION}"  --vpc-uuid "${vpc_id}" --user-data-file "${cloud_config}"

	${BUILD_HOME}/services/security/firewall/ConfigureNativeFirewall.sh "${machine_type}" 
