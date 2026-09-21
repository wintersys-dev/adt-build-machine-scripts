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
set -x

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

website="${1}"

checked="0"
if ( [ "`/bin/grep "^TEXTBROWSER:*" ${BUILD_HOME}/configuration/software.dat | /bin/grep lynx`" != "" ] )
then
        checked="1"
        /bin/echo "FORCE_SSL_PROMPT:YES" > /tmp/cfg.txt
        timeout 23 /usr/bin/lynx -cfg=/tmp/cfg.txt -dump https://${website} 2>&1 >/dev/null
        status="$?"
        /bin/rm /tmp/cfg.txt
elif ( [ "`/bin/grep "^TEXTBROWSER:*" ${BUILD_HOME}/configuration/software.dat | /bin/grep w3m`" != "" ] )
then
        checked="1"
        error="`/usr/bin/yes | timeout 23 /usr/bin/w3m -dump -o ssl_verify_server=0  https://${website} | /bin/grep 'error'`"
        /usr/bin/yes | timeout 23 /usr/bin/w3m -dump -o ssl_verify_server=0  https://${website}
        status="$?"
        if ( [ "${error}" != "" ] )
        then
                status="1"
        fi
elif ( [ "`/bin/grep "^TEXTBROWSER:*" ${BUILD_HOME}/configuration/software.dat | /bin/grep elinks`" != "" ] )
then
        checked="1"
        error="`/usr/bin/yes | timeout 23 /usr/bin/elinks -dump -o ssl_verify_server=0  https://${website} | /bin/grep 'error'`"
        /usr/bin/yes | timeout 23 /usr/bin/elinks -dump -o ssl_verify_server=0  https://${website}
        status="$?"
        if ( [ "${error}" != "" ] )
        then
                status="1"
        fi
fi

if ( [ "${status}" = "0" ] && [ "${checked}" = "1" ] )
then
        /bin/echo "success"
else
        /bin/echo "failure"
fi
