#!/bin/sh
#################################################################################
# Description: Ths script will work out what kind of application you are deploying
# from a backup stored in your datastore
# Author: Peter Winter
# Date: 02/01/2017
#################################################################################
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
###################################################################################
###################################################################################
#set -x

status () {
	/bin/echo "${1}" | /usr/bin/tee /dev/fd/3 2>/dev/null
	script_name="`/bin/echo ${0} | /usr/bin/awk -F'/' '{print $NF}'`"
	/bin/echo "${script_name}: ${1}" | /usr/bin/tee -a /dev/fd/4 2>/dev/null
}

BUILD_HOME="`/bin/cat /home/buildhome.dat`" 
CLOUDHOST="`${BUILD_HOME}/helpers/GetVariableValue.sh CLOUDHOST`"
BUILD_IDENTIFIER="`${BUILD_HOME}/helpers/GetVariableValue.sh BUILD_IDENTIFIER`"
DIRECTORIES_TO_MOUNT="`${BUILD_HOME}/helpers/GetVariableValue.sh DIRECTORIES_TO_MOUNT`"
DATABASE_INSTALLATION_TYPE="`${BUILD_HOME}/helpers/GetVariableValue.sh DATABASE_INSTALLATION_TYPE`"
DATABASE_DBaaS_INSTALLATION_TYPE="`${BUILD_HOME}/helpers/GetVariableValue.sh DATABASE_DBaaS_INSTALLATION_TYPE`"
interrogation_home="${BUILD_HOME}/interrogation"

APPLICATION=""

if ( [ ! -f ${interrogation_home}/dbe.dat ] )
then
	status "NOTICE: couldn't detect the database type for your application"
else
	if ( [ "`/bin/grep Maria ${interrogation_home}/dbe.dat`" != "" ] )
	then
		db_type="sql"
	fi
	if ( [ "`/bin/grep MySQL ${interrogation_home}/dbe.dat`" != "" ] )
	then
		db_type="sql"
	fi
	if ( [ "`/bin/grep Postgres ${interrogation_home}/dbe.dat`" != "" ] )
	then
		db_type="postgres"
	fi
fi

if ( [ ! -f ${interrogation_home}/applicationDB.sql ] && [ ! -f ${interrogation_home}/applicationDB.psql ] )
then
	status "NOTICE: Can't find a suitable database dump file for your application"
	status "Press <enter> to acknowledge and accept <ctrl-c> to exit and investigate"
	read x
fi

if ( [ -f ${interrogation_home}/applicationDB.sql ] && [ "${db_type}" != "sql" ] )
then
	status "It seems like there is a mismatch between the type of database and thw webroot type"
	/bin/touch /tmp/END_IT_ALL
fi

if ( [  "${DATABASE_INSTALLATION_TYPE}" = "MySQL" ] || [  "${DATABASE_INSTALLATION_TYPE}" = "Maria" ] || [ "`/bin/echo "${DATABASE_DBaaS_INSTALLATION_TYPE}" | /bin/grep 'MySQL'`" != "" ] ) 
then
	if ( [ "${db_type}" != "sql" ] )
	then
		status "It seems like there is a mismatch between the type of database you are installing and the database type that is configured in the template"
		/bin/touch /tmp/END_IT_ALL
	fi
fi


if ( [ -f ${interrogation_home}/applicationDB.psql ] && [ "${db_type}" != "postgres" ] )
then
	status "It seems like there is a mismatch between the type of database and thw webroot type"
	/bin/touch /tmp/END_IT_ALL
fi

if ( [  "${DATABASE_INSTALLATION_TYPE}" = "Postgres" ] || [ "`/bin/echo "${DATABASE_DBaaS_INSTALLATION_TYPE}" | /bin/grep 'Postgres'`" != "" ] )
then
	if ( [ "${db_type}" != "postgres" ] )
	then
		status "It seems like there is a mismatch between the type of database you are installing and the database type that is configured in the template"
		/bin/touch /tmp/END_IT_ALL
	fi
fi

if ( [ -f ${interrogation_home}/dba.dat ] )
then
	detected_application="`/bin/cat ${interrogation_home}/dba.dat | /usr/bin/tr '[:upper:]' '[:lower:]'`"
	/bin/touch ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/APPLICATION:${detected_application}
	APPLICATION="${detected_application}"
	status "Discovered you are deploying ${detected_application} from a datastore backup with ${db_type} database type"
	status "Press the <enter> key to accept as true"

	if ( [ "`${BUILD_HOME}/helpers/IsHardcoreBuild.sh`" != "1" ] )
	then
		read x
	fi
else
	status "Error, cannot find dba.dat file in your backup archive"
	/bin/touch /tmp/END_IT_ALL
fi
		
if ( [ -f ${interrogation_home}/dbp.dat ] )
then
	/bin/cp ${interrogation_home}/dbp.dat ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}
	${BUILD_HOME}/services/datastore/operations/PutToDatastore.sh "config" "${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/dbp.dat" "root" "distributed" "no"
else
	status "Error, cannot find dbp.dat file in your backup archive"
	/bin/touch /tmp/END_IT_ALL
fi

/bin/rm -r ${interrogation_home}

if ( [ "${APPLICATION}" = "" ] )
then
	status "Couldn't find a recognised application type. If you are sure you are OK with this, hit <enter> otherwise <ctrl-c> and have a look into what is going on"
	if ( [ "`${BUILD_HOME}/helpers/IsHardcoreBuild.sh`" != "1" ] )
	then
		read x
	fi
fi
