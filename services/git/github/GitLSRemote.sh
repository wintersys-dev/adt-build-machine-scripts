##################################################################################
# SCRIPT      : GitLSRemote.sh (GitHub Provider)
# AUTHOR      : Peter Winter
# DATE        : 16/07/2021
# VERSION     : 1.0.0
# DESCRIPTION : This script executes a remote repository lookup using git ls-remote 
#               on GitHub to check for existence and grab the HEAD reference. 
#               It manages a transient `.netrc` file securely for authentication.
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
# LICENSE AGREEMENT:
#   This file is part of The Agile Deployment Toolkit.
#   Licensed under the GNU General Public License v3 or later.
# ################################################################################


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
        status "Usage: $0  <repository_ownername> <repository_name> [repository_username]"
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

/usr/bin/git ls-remote https://github.com/${repository_ownername}/${repository_name}.git | /bin/grep 'HEAD'

error_code="$?"

if ( [ "${error_code}" != "0" ] )
then
        status "git ls-remote exited with error code ${error_code}"
        exit 1
fi

/bin/rm ${HOME}/.netrc

