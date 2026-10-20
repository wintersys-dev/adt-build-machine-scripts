#set -x

set -e

status () {
        /bin/echo "${1}" | /usr/bin/tee /dev/fd/3 2>/dev/null
        script_name="`/bin/echo ${0} | /usr/bin/awk -F'/' '{print $NF}'`"
        /bin/echo "${script_name}: ${1}" | /usr/bin/tee -a /dev/fd/4 2>/dev/null
}

if ( [ "${1}" = "" ] )
then
        status "Error: 1 argument is required."
        status "Usage: $0 <file_to_list>"
        exit 1
fi

file_to_list="${1}"

host_base="`/bin/grep ^host_base /root/.s3cfg-1 | /usr/bin/awk -F'=' '{print  $NF}' | /bin/sed 's/ //g'`" 
file_to_list="`/bin/echo ${file_to_list} | /bin/sed 's/\*.*//g'`"
/usr/bin/s3cmd --recursive --config=/root/.s3cfg-1 --host=https://${host_base} ls s3://${file_to_list}
        
if ( [ "$?" != "0" ] )
then
        status "Failed to list file ${file_to_list} from datastore
        exit 1
fi
