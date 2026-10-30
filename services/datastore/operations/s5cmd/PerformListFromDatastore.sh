#!/bin/sh 
###################################################################################
# @file        PerformListFromDatastore.sh
# @brief       Automated S5cmd Datastore Object File Content Listing and Parsing Driver.
# @author      Peter Winter
# @date        09/04/2021
# @version     1.0
#
# @details     This script automates granular object content listing tasks to parse and
#              inspect specific file payloads within an S3 datastore using s5cmd. It 
#              extracts the storage host configuration from the primary master s5cmd 
#              profile map. The utility queries the target S3 path and isolates individual 
#              target file basenames cleanly using text extraction layers.
#
# @param       $1  [Required] Target S3 bucket pathway or file pattern to inspect.
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
#              - Anchors specific file object parsing queries to the core master profile context.
#              - Shunts unexpected connection diagnostic information into quiet null targets (2>/dev/null).
#              - Anchors core text manipulation and query engines strictly to system partitions (/bin, /usr/bin).
#
# @exit        0  Success: Target object names were resolved and output successfully.
# @exit        1  Failure: Missing parameters or an error state thrown by the extraction pipeline.
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
        status "Usage: $0 <file_to_list>"
        exit 1
fi

file_to_list="${1}"

host_base="`/bin/grep ^host_base /root/.s5cfg-1 | /usr/bin/awk -F'=' '{print  $NF}' | /bin/sed 's/ //g'`" 
/usr/bin/s5cmd --credentials-file /root/.s5cfg-1 --endpoint-url https://${host_base} ls s3://${file_to_list}  | /usr/bin/awk '{print $NF}' 2>/dev/null

if ( [ "$?" != "0" ] )
then
        status "Failed to list file ${file_to_list} from datastore"
        exit 1
fi

