#!/bin/sh
######################################################################################
# Author: Peter Winter
# Date :  9/4/2016
# Description: Implement the moving of an object within a datastore
######################################################################################
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
#######################################################################################
#######################################################################################
#set -x

original_object="$1"
new_object="$2"
count="$3"


host_base="`/bin/grep ^host_base /root/.s3cfg-1 | /usr/bin/awk -F'=' '{print  $NF}' | /bin/sed 's/ //g'`" 
/usr/bin/s3cmd --config=/root/.s3cfg-${count} --host=https://${host_base} mv s3://${original_object} s3://${new_object}

if ( [ "$?" != "0" ] )
then
        status "Failed to move object ${original_object} to object ${new_object}"
        exit 1
fi
