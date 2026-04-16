#!/bin/sh
########################################################################################################
# Author: Peter Winter
# Date  : 13/07/2016
# Description : You can use this script to remove buckets from your datastore. If you run this script
# it wil ask you which buckets you want to delete in turn. This can be much faster than manually attending to each 
# bucket if you have a lot of buckets to delete
########################################################################################################
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

if ( [ ! -f  ./CleanupDatastore.sh ] )
then
        /bin/echo "Sorry, this script has to be run from the helpers subdirectory"
        exit
fi

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

/bin/echo "Which datastore service are you using? 1) Digital Ocean 2) Exoscale 3) Linode 4) Vultr. Please Enter the number for your cloudhost"
read response
if ( [ "${response}" = "1" ] )
then
        DATASTORE_PROVIDER="digitalocean"
elif ( [ "${response}" = "2" ] )
then
        DATASTORE_PROVIDER="exoscale"
elif ( [ "${response}" = "3" ] )
then
        DATASTORE_PROVIDER="linode"
elif ( [ "${response}" = "4" ] )
then
        DATASTORE_PROVIDER="vultr"
else
        /bin/echo "Unrecognised  cloudhost. Exiting ...."
        exit
fi

if ( [ "${1}" = "all" ] )
then
        /bin/echo "You are asking to list and consider for deletion all of the buckets in your datastore. This is risky as mistakes might delete unintended data"
        /bin/echo "But seeing as you have passed the parameter 'all' I will presume you know what you are doing. Double check all that is offered for deletion before typing 'Y'"
        /bin/echo "Press <enter> to continue"
        read x
        buckets=`${BUILD_HOME}/services/datastore/operations/ListDatastore.sh "all" | /usr/bin/awk '{print $NF}' | /bin/sed 's,s3://,,'`
else
        buckets=`${BUILD_HOME}/services/datastore/operations/ListDatastore.sh "all" | /usr/bin/awk '{print $NF}' | /bin/sed 's,s3://,,' | /bin/grep "authip-adt-allowed"`
fi

for bucket in ${buckets}
do
        /bin/echo "Have found bucket: ${bucket} do you want to delete it, (Y|N)"
        read response

        if ( [ "${response}" = "y" ] || [ "${response}" = "Y" ] )
        then
                ${BUILD_HOME}/services/datastore/operations/DeleteDatastore.sh "${bucket}" "distributed"
        fi
done
