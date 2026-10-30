#!/bin/sh 
###################################################################################
# @file        PerformDeleteDatastore.sh
# @brief       Automated S3cmd Datastore Bucket Purging and Removal Driver.
# @author      Peter Winter
# @date        09/04/2021
# @version     1.0
#
# @details     This script automates the complete destruction and removal of an S3
#              cloud datastore bucket using the s3cmd utility. It dynamically extracts
#              the target host base endpoint from a numbered s3cmd configuration profile.
#              The driver performs a recursive forced deletion of all internal object 
#              payloads before executing a final remove-bucket transaction against the 
#              endpoint.
#
# @param       $1  [Required] The exact name of the S3 datastore bucket to purge and delete.
# @param       $2  [Required] Integer ID used to select the indexed s3cmd configuration profile.
#
# @env         BUILD_HOME              Sourced application root tracking pathway string.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking the active application root path.
#              - /root/.s3cfg-${count} workspace configuration file for endpoint and credential routing.
#              - LogStatusMessages.sh framework helper module for centralized runtime tracking.
#              - /usr/bin/s3cmd command-line tool for managing Amazon S3 and compatible storage providers.
#
# @security    
#              - Requires root-level access privileges to inspect and evaluate specific configuration profiles.
#              - Routes diagnostic payloads securely to the absolute null space (2>&1 >/dev/null).
#              - Binds operational tools explicitly to full filesystem binary paths (/bin, /usr/bin).
#
# @exit        0  Success: Target cloud datastore contents and bucket structure were fully dropped.
# @exit        1  Failure: Missing parameters or an error returned during deletion/removal routines.
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


if ( [ "${1}" = "" ] || [ "${2}" = "" ] )
then
        status "Error: 2 arguments are required."
        status "Usage: $0 <datastore_to_delete> <count>"
        exit 1
fi

datastore_to_delete="${1}"
count="${2}"

host_base="`/bin/grep ^host_base /root/.s3cfg-${count} | /usr/bin/awk -F'=' '{print  $NF}' | /bin/sed 's/ //g'`" 
/usr/bin/s3cmd --recursive --force --config=/root/.s3cfg-${count} --host=https://${host_base} del s3://${datastore_to_delete}  2>&1 >/dev/null

if ( [ "$?" != "0" ] )
then
        status "Failed to delete contents from datastore"
        exit 1
fi
/usr/bin/s3cmd --recursive --force --config=/root/.s3cfg-${count} --host=https://${host_base} rb s3://${datastore_to_delete}  2>&1 >/dev/null

if ( [ "$?" != "0" ] )
then
        status "Failed to delete datastore"
        exit 1
fi

