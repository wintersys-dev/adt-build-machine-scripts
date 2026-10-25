#!/bin/sh
##################################################################################
# SCRIPT      : GitLSRemote.sh
# AUTHOR      : Peter Winter
# DATE        : 16/07/2016
# VERSION     : 1.0.0
# DESCRIPTION : This script acts detects if a named repository exists for the given
#               provider and owner
#
# INTERFACE   : $0 <provider> <owner_name> <repo_name> [auth_username]
#
# PARAMETERS  :
#   $1 - repository_provider  : Hosting vendor string (e.g., github, gitlab)
#   $2 - repository_ownername : Organization or profile namespace account name
#   $3 - repository_name      : Case-sensitive project target repository name
#   $4 - repository_username  : (Optional) Account credential token/user for auth
#
# CONFIGURATION DEPENDENCIES:
#   - /home/buildhome.dat     : Must contain absolute path to build directory
#   - Sub-driver wrapper path : ${BUILD_HOME}/services/git/<provider>/GitLSRemote.sh
#
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
#####################################################################################
#####################################################################################
#set -x
set -e

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

status () {
        /bin/echo "${1}" | /usr/bin/tee /dev/fd/3 2>/dev/null
        script_name="`/bin/echo ${0} | /usr/bin/awk -F'/' '{print $NF}'`"
        /bin/echo "${script_name}: ${1}" | /usr/bin/tee -a /dev/fd/4 2>/dev/null
}


if ( [ "${1}" = "" ] || [ "${2}" = "" ] || [ "${3}" = "" ] )
then
        status "Error: 3 arguments are required and 1 optional argumment"
        status "Usage: $0 <repository_provider> <repository_ownername> <repository_name> [repository_username]"
        exit 1
fi

repository_provider="${1}"
repository_ownername="${2}"
repository_name="${3}"
repository_username="${4}"

${BUILD_HOME}/services/git/${repository_provider}/GitLSRemote.sh "${repository_ownername}" "${repository_name}" "${repository_username}" 
if ( [ "$?" != "0" ] )
then
        status "GitLSRemote.sh returned an error code"
        exit 1
fi

