
#set -x
set -e

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

status () {
        /bin/echo "${1}" | /usr/bin/tee /dev/fd/3 2>/dev/null
        script_name="`/bin/echo ${0} | /usr/bin/awk -F'/' '{print $NF}'`"
        /bin/echo "${script_name}: ${1}" | /usr/bin/tee -a /dev/fd/4 2>/dev/null
}


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

/usr/bin/git clone --depth 1 https://${repository_username}${authentication_token}@bitbucket.org/${repository_ownername}/${repository_name}.git
