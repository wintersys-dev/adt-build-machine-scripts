#!/bin/sh
########################################################################################
# Author: Peter Winter
# Date  : 12/07/2021
# Description : This is a script which enables you to shortcut the deployment of DBaaS systems
# when using the hardcore or expedited build. You do it by setting the DATABASE_DBaaS_INSTALLATION_TYPE
# variable in the way described for each provider. When set as described for your provider,
# when you make the deployment this script will try and spin up a DBaaS system and use that. 
# Alternative you can pre-provision your DBaaS database using the GUI system if you don't want to wait
# for it to provision whilst the script is running (which for some providers can take a bit of time)
########################################################################################
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
#########################################################################################
#########################################################################################
#set -x

status () {
	${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

${BUILD_HOME}/initialisation/linode/mysql/cli/VerifiySelectedEngine.sh
if [ $? != "0" ] 
then
	status "Database Engine not successfully verified"
	exit 1
fi

database_id=$(${BUILD_HOME}/initialisation/linode/mysql/cli/ObtainDatabaseID.sh)

if [ -z "$database_id" ]
then
	${BUILD_HOME}/initialisation/linode/mysql/cli/CreateDBaaSServer.sh

	${BUILD_HOME}/initialisation/linode/mysql/cli/CheckDBaaSServerStatus.sh
	if [ $? != "0" ] 
	then
		status "Could not verify DBaaS Server status"
		exit 1
	fi
else
	status "A database ${label} with id ${database_id} is already active, not provisioning a new one"
	${BUILD_HOME}/initialisation/linode/mysql/cli/UpdateDBaaSFirewall.sh ${database_id} "0.0.0.0/0"
	if ( [ "$?" != "0" ] )
	then
		status "failed to update firewall allowed ip list"
		exit 1
	fi
fi

db_payload=$(${BUILD_HOME}/initialisation/linode/mysql/cli/ObtainDatabaseDetails.sh ${database_id} ${db_name})

if [ $? -eq 0 ] && [ -n "$db_payload" ]
then
    eval "$db_payload"
    
  #  echo "Connected to cluster: $CLUSTER_NAME"
  #  echo "Host: $DB_IDENTIFIER"
  #  echo "Port: $DB_PORT"
else
    status "Error: Failed to retrieve database details." >&2
    exit 1
fi

${BUILD_HOME}/initialisation/linode/mysql/cli/ObtainDBaaSCert.sh ${database_id}


	
