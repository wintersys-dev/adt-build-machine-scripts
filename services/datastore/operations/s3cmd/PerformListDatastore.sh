#!/bin/sh 
####################################################################################
# Author: Peter Winter
# Date :  9/4/2021
# Description: Implement the listing and filtering of datastores
#######################################################################################
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
#set -e

status () {
        /bin/echo "${1}" | /usr/bin/tee /dev/fd/3 2>/dev/null
        script_name="`/bin/echo ${0} | /usr/bin/awk -F'/' '{print $NF}'`"
        /bin/echo "${script_name}: ${1}" | /usr/bin/tee -a /dev/fd/4 2>/dev/null
}

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

host_base="`/bin/grep ^host_base /root/.s3cfg-1 | /usr/bin/awk -F'=' '{print  $NF}' | /bin/sed 's/ //g'`"
/usr/bin/s3cmd --config="/root/.s3cfg-1" --host="https://${host_base}" ls | awk '{print $NF}'| sed -e 's|s3://||' -e 's|/.*||'  | /bin/grep ${flag} "${datastore_to_list}" 2>/dev/null

if ( [ "$?" != "0" ] )
then
        echo "Failed to list datastore"
        exit 1
fi
