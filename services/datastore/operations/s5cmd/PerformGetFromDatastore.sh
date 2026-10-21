#set -x

set -e

status () {
        /bin/echo "${1}" | /usr/bin/tee /dev/fd/3 2>/dev/null
        script_name="`/bin/echo ${0} | /usr/bin/awk -F'/' '{print $NF}'`"
        /bin/echo "${script_name}: ${1}" | /usr/bin/tee -a /dev/fd/4 2>/dev/null
}

if ( [ "${1}" = "" ] || [ "${2}" = "" ] )
then
        status "Error: 2 arguments are required."
        status "Usage: $0 <file_to_get> <destination>"
        exit 1
fi

file_to_get="${1}"
destination="${2}"

host_base="`/bin/grep ^host_base /root/.s5cfg-1 | /usr/bin/awk -F'=' '{print  $NF}' | /bin/sed 's/ //g'`"
/usr/bin/s5cmd --credentials-file /root/.s5cfg-1 --endpoint-url https://${host_base} cp s3://${file_to_get} ${destination}  2>/dev/null

if ( [ "$?" != "0" ] )
then
        status "Failed to get file ${file_to_get} from datastore"
        exit 1
fi
