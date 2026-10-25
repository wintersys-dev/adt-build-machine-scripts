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
        status "Error: 3 arguments are required"
        status "Usage: $0 <repository_username> <repository_ownername> <repository_name>"
        exit 1
fi

repository_username="${1}"
repository_ownername="${2}" 
repository_name="${3}" 
#repository_token="${4}"

cat << EOF > ${HOME}/.netrc
machine github.com
login ${repository_username}
password ${REPOSITORY_TOKEN}
EOF

#I only use the .netrc file for git commands and I construct it and remove it every time I want to use it
#if I need a .netrc file for curl (for example) I construct a custom file name and use the custom file so there is no clash
chmod 600 ${HOME}/.netrc

/usr/bin/git ls-remote https://github.com/${repository_ownername}/${repository_name}.git | /bin/grep 'HEAD'

/bin/rm ${HOME}/.netrc

