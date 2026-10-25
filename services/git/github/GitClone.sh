##################################################################################
# SCRIPT      : GitClone.sh (GitHub Provider)
# AUTHOR      : Peter Winter
# DATE        : 13/06/2021
# VERSION     : 1.0.0
# DESCRIPTION : This script safely executes a shallow Git clone from GitHub. 
#               It dynamically creates a temporary `.netrc` file for secure 
#               token authentication and guarantees its removal upon completion.
#
# INTERFACE   : $0 <owner_name> <repo_name> [auth_username]
#
# PARAMETERS  :
#   $1 - repository_ownername : GitHub organization or individual profile namespace
#   $2 - repository_name      : Case-sensitive name of the target repository
#   $3 - repository_username  : (Optional) GitHub username associated with the token
#
# ENVIRONMENT VARIABLES:
#   - REPOSITORY_TOKEN        : Must be exported in the shell for authentication
#
# CONFIGURATION DEPENDENCIES:
#   - /home/buildhome.dat     : Must contain absolute path to build directory
#   - ${HOME}/.netrc          : Managed temporarily during runtime (Chmod 600)
#
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


if ( [ "${1}" = "" ] || [ "${2}" = "" ] )
then
        status "Error: 2 arguments are required and 1 optional argument"
        status "Usage: $0 <repository_ownername> <repository_name> [repository_username]"
        exit 1
fi

repository_ownername="${1}" 
repository_name="${2}" 
repository_username="${3}"

cat << EOF > ${HOME}/.netrc
machine github.com
login ${repository_username}
password ${REPOSITORY_TOKEN}
EOF

#I only use the .netrc file for git commands and I construct it and remove it every time I want to use it
#if I need a .netrc file for curl (for example) I construct a custom file name and use the custom file so there is no clash
chmod 600 ${HOME}/.netrc

/usr/bin/git clone --depth 1 https://github.com/${repository_ownername}/${repository_name}.git

if ( [ "$?" != "0" ] )
then
        status "git clone command failed with error code $?"
        exit 1
fi

/bin/rm ${HOME}/.netrc

