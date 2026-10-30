#!/bin/sh 
###################################################################################
# @file        PerformListDatastore.sh
# @brief       Automated S5cmd Datastore Directory Structural Listing Driver.
# @author      Peter Winter
# @date        09/04/2021
# @version     1.0
#
# @details     This script automates directory structural parsing tasks to discover if a
#              target S3 datastore bucket exists, or maps out all active instances using s5cmd.
#              It extracts the cloud storage endpoint path from the primary master s5cmd profile.
#              If the target parameter matches "all", it lists all structural blocks; otherwise,
#              it targets a strict exact match using localized string filtering constraints.
#
# @param       $1  [Required] The target datastore name to search for, or "all" to map everything.
#
# @env         BUILD_HOME              Sourced application root tracking pathway string.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking the active application root path.
#              - /root/.s5cfg-1 base master workspace profile for endpoint and credential routing.
#              - LogStatusMessages.sh framework helper module for centralized runtime tracking.
#              - /usr/bin/s5cmd parallel S3 command-line execution tool binary.
#
# @security    
#              - Anchors target validation queries exclusively to the core master account configuration map.
#              - Suppresses unhandled communication exceptions silently inside internal channels (2>/dev/null).
#              - Forces script evaluation tasks to execute out of verified system partitions (/bin, /usr/bin).
#
# @exit        0  Success: Target datastores were successfully listed or confirmed to exist.
# @exit        1  Failure: Missing parameters or the target datastore structure was not discovered.
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
# along with The Agile Deployment Toolkit.  If not, see <http://gnu.org>.
######################################################################################
######################################################################################
#set -x

set -e

status () {
	${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

if ( [ "${1}" = "" ] )
then
        status "Error: 1 argument is required."
        status "Usage: $0 <datastore_to_list>"
        exit 1
fi

datastore_to_list="${1}"

flag="-x"
if ( [ "${datastore_to_list}" = "all" ] )
then
        datastore_to_list=""
        flag=""
fi

host_base="`/bin/grep ^host_base /root/.s5cfg-1 | /usr/bin/awk -F'=' '{print  $NF}' | /bin/sed 's/ //g'`"
/usr/bin/s5cmd --credentials-file /root/.s5cfg-1 --endpoint-url https://${host_base} ls | awk '{print $NF}'| sed -e 's|s3://||' -e 's|/.*||' | /bin/grep ${flag} "${datastore_to_list}" 2>/dev/null

if ( [ "$?" != "0" ] )
then
        status "Failed to list datastore ${datastore_to_list}"
        exit 1
fi
