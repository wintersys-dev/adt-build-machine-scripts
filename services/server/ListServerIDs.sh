#!/bin/sh
################################################################################
# Author : Peter Winter
# Date   : 13/07/2016
# Description : Lists all the id's of a server of a particular type
################################################################################
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

server_type="${1}"

BUILD_HOME="`/bin/cat /home/buildhome.dat`"
CLOUDHOST="`/bin/cat ${BUILD_HOME}/runtime/ACTIVE_CLOUDHOST`"
orchestration_tool="`/bin/grep "^ORCHESTRATION_TOOL:*" ${BUILD_HOME}/configuration/software.dat | /usr/bin/awk -F':' '{print $NF}'`"

${BUILD_HOME}/services/server/${CLOUDHOST}/${orchestration_tool}/ListServerIDs.sh "${server_type}" 








