#!/bin/sh 
###################################################################################
# @file        PerformDeleteDatastore.sh
# @brief       Automated S3cmd Datastore Bucket Purging and Removal Driver.
# @author      Peter Winter
# @date        09/04/2021
# @version     1.1
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
#              - Routes diagnostic payloads securely to the absolute null space (>/dev/null 2>&1).
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
#set -x
set -e

status () {
    "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}"
}

BUILD_HOME="$(/bin/cat /home/buildhome.dat)"

# Verify required parameters
if [ -z "$1" ] || [ -z "$2" ]
then
    status "Error: 2 arguments are required."
    status "Usage: $0 <datastore_to_delete> <count>"
    exit 1
fi

datastore_to_delete="$1"
count="$2"

cfg_file="/root/.s3cfg-${count}"
if [ ! -f "$cfg_file" ]
then
    /bin/echo "Error: Configuration profile $cfg_file not found."
    status "Profile configuration file missing: $cfg_file"
    exit 1
fi

host_base=$(/usr/bin/grep ^host_base "$cfg_file" | /usr/bin/awk -F'=' '{print $NF}' | /usr/bin/tr -d ' ')

set +e

# 1. Purge all internal bucket contents recursively
/usr/bin/s3cmd --recursive --force --config="$cfg_file" --host="https://${host_base}" del "s3://${datastore_to_delete}" >/dev/null 2>&1
del_status=$?

if [ $del_status -ne 0 ]
then
    status "Failed to delete contents from datastore: s3://${datastore_to_delete} (Exit code: $del_status)"
    exit 1
fi

# 2. Drop the empty bucket structure completely
/usr/bin/s3cmd --config="$cfg_file" --host="https://${host_base}" rb "s3://${datastore_to_delete}" >/dev/null 2>&1
rb_status=$?

set -e

if [ $rb_status -ne 0 ]
then
    status "Failed to delete datastore bucket structure: s3://${datastore_to_delete} (Exit code: $rb_status)"
    exit 1
fi

exit 0


