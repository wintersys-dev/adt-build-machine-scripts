#!/bin/sh
########################################################################################################
# Author: Peter Winter
# Date  : 13/01/2022
# Description : This script will make your webroot(s) mutable or immutable
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

if ( [ ! -f  ./SetWebrootsToImmutable.sh ] )
then
        /bin/echo "Sorry, this script has to be run from the ${BUILD_HOME}/helpers/securitysubdirectory"
        exit
fi

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

/bin/echo "Which cloudhost service are you using? 1) Digital Ocean 2) Exoscale 3) Linode 4) Vultr. Please Enter the number for your cloudhost"
read response
if ( [ "${response}" = "1" ] )
then
        CLOUDHOST="digitalocean"
elif ( [ "${response}" = "2" ] )
then
        CLOUDHOST="exoscale"
elif ( [ "${response}" = "3" ] )
then
        CLOUDHOST="linode"
elif ( [ "${response}" = "4" ] )
then
        CLOUDHOST="vultr"
else
        /bin/echo "Unrecognised  cloudhost. Exiting ...."
        exit
fi

/bin/echo "Please enter the name of the build of the server you wish to connect with"
/bin/ls ${BUILD_HOME}/runtime/${CLOUDHOST}
read BUILD_IDENTIFIER

/bin/echo "Do you want to make your webroot(s) 1) Mutable or 2)Immutable"
read response

while ( [ "`/bin/echo 1 2 | /bin/grep ${response}`" = "" ] )
do
        /bin/echo "That's not a valid response please enter 1 or 2"
        read response
done

if ( [ "${response}" = "1" ] )
then
        marker_file="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/MUTABLE-WEBROOT"
else
        marker_file="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/IMMUTABLE-WEBROOT"
fi

/bin/touch ${marker_file}

if ( [ "${response}" = "1" ] )
then
        if ( [ "`${BUILD_HOME}/services/datastore/operations/ListFromDatastore.sh "config" "IMMUTABLE-WEBROOT"`" != "" ] )
        then
                ${BUILD_HOME}/services/datastore/operations/DeleteFromDatastore.sh "config" "IMMUTABLE-WEBROOT" "local"
        fi
elif ( [ "${response}" = "2" ] )
then
        if ( [ "`${BUILD_HOME}/services/datastore/operations/ListFromDatastore.sh "config" "MUTABLE-WEBROOT"`" != "" ] )
        then
                ${BUILD_HOME}/services/datastore/operations/DeleteFromDatastore.sh "config" "MUTABLE-WEBROOT" "local"
        fi
fi

${BUILD_HOME}/services/datastore/operations/PutToDatastore.sh "config" "${marker_file}" "root" "distributed" "no"

/bin/echo "Marker file ${marker_file} written to datastore"

if ( [ -f ${marker_file} ] )
then
        /bin/rm ${marker_file}
fi
