#!/bin/sh
###################################################################################
# Description: This will test of our website is online or not
# Author: Peter Winter
# Date: 08/01/2017
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
# along with The Agile Deployment Toolkit.  If not, see <http://www.gnu.org/licenses/>.
###################################################################################
###################################################################################
#set -x

ip="${1}"

if ( [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'TEXTBROWSER:lynx'`" = "1" ] )
then
        /usr/bin/lynx -dump -accept_all_cookies https://${ip}:443 2>&1 >/dev/null
        if ( [ "$?" = "0" ] )
        then
                /bin/echo "success"
        else
                /bin/echo "failure"
        fi
fi

if ( [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'TEXTBROWSER:w3m'`" = "1" ] )
then
        :
fi
