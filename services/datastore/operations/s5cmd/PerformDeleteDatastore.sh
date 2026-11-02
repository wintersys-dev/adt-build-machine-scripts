#!/bin/sh 
###################################################################################
# @file        PerformDeleteDatastore.sh
# @brief       Automated S5cmd Datastore Bucket Purging and Removal Driver.
# @author      Peter Winter
# @date        09/04/2021
# @version     1.0
#
# @details     This script automates the complete destruction and removal of an S3
#              cloud datastore bucket using the high-performance s5cmd utility. It 
#              dynamically extracts the target host base endpoint from a numbered s5cmd 
#              configuration profile. The driver checks for and purges all internal 
#              object contents via wildcard matching before executing a final 
#              remove-bucket (rb) transaction against the endpoint.
#
# @param       $1  [Required] The exact name of the S3 datastore bucket to purge and delete.
# @param       $2  [Required] Integer ID used to select the indexed s5cmd configuration profile.
#
# @env         BUILD_HOME              Sourced application root tracking pathway string.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking the active application root path.
#              - /root/.s5cfg-${count} workspace credentials file for endpoint and credential routing.
#              - LogStatusMessages.sh framework helper module for centralized runtime tracking.
#              - /usr/bin/s5cmd parallel S3 command-line execution tool binary.
#
# @security    
#              - Requires root-level access privileges to inspect and evaluate specific configuration profiles.
#              - Routes structural cleanup diagnostic outputs safely away to internal null streams (>/dev/null 2>&1).
#              - Forces tool maps to run exclusively from static, validated platform partitions (/bin, /usr/bin).
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

if [ -z "$1" ] || [ -z "$2" ]
then
    status "Error: 2 arguments are required."
    status "Usage: $0 <datastore_to_delete> <count>"
    exit 1
fi

datastore_to_delete="$1"
count="$2"

cfg_file="/root/.s5cfg-${count}"
if [ ! -f "$cfg_file" ]
then
    /bin/echo "Error: Configuration profile $cfg_file not found."
    status "Profile configuration file missing: $cfg_file"
    exit 1
fi

host_base=$(/usr/bin/grep ^host_base "$cfg_file" | /usr/bin/awk -F'=' '{print $NF}' | /usr/bin/tr -d ' ')

set +e

s5_objects=$(/usr/bin/s5cmd --credentials-file "$cfg_file" --endpoint-url "https://${host_base}" ls "s3://${datastore_to_delete}/*" 2>/dev/null)

if [ -n "$s5_objects" ]
then
    /usr/bin/s5cmd --credentials-file "$cfg_file" --endpoint-url "https://${host_base}" rm "s3://${datastore_to_delete}/*" >/dev/null 2>&1
    rm_status=$?
    
    if [ $rm_status -ne 0 ]
    then
        status "Failed to delete contents of datastore s3://${datastore_to_delete} (Exit code: $rm_status)"
        exit 1
    fi
fi

/usr/bin/s5cmd --credentials-file "$cfg_file" --endpoint-url "https://${host_base}" rb "s3://${datastore_to_delete}" >/dev/null 2>&1
rb_status=$?

set -e

if [ $rb_status -ne 0 ]
then
    status "Failed to delete datastore bucket structure s3://${datastore_to_delete} (Exit code: $rb_status)"
    exit 1
fi

exit 0


