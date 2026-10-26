
#set -x
set -e

status () {
	${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

BUILD_HOME="`/bin/cat /home/buildhome.dat`"


if ( [ "${1}" = "" ] || [ "${2}" = "" ] || [ "${3}" = "" ] || [ "${4}" = "" ] )
then
        status "Error: 4 arguments are required"
        status "Usage: $0 <authentication_token> <repository_username> <repository_ownername> <repository_name>"
        exit 1
fi

authentication_token="${1}" 
repository_username="${2}"
repository_ownername="${3}" 
repository_name="${4}" 

/usr/bin/git ls-remote https://${repository_username}${authentication_token}@gitlab.com/${repository_ownername}/${repository_name}.git | /bin/grep 'HEAD'
