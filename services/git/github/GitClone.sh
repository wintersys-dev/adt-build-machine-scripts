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
        status "Error: 3 arguments are required and 1 optional argument"
        status "Usage: $0 <repository_username> <repository_ownername> <repository_name> [authentication_token]"
        exit 1
fi

repository_username="${1}"
repository_ownername="${2}" 
repository_name="${3}" 
authentication_token="${4}" 

/usr/bin/git clone --depth 1 https://${repository_username}${authentication_token}@github.com/${repository_ownername}/${repository_name}.git
