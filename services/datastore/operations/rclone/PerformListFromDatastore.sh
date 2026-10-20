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

host_base="`/bin/grep ^endpoint /root/.config/rclone/rclone.conf-1 | /usr/bin/awk -F'=' '{print  $NF}' | /bin/sed 's/ //g'`" 
include=""

if ( [ "${file_to_list}" != "" ] )
then
        include='--include "*'${file_to_list}*'"'
fi
 
/usr/bin/rclone --config /root/.config/rclone/rclone.conf-1 --s3-endpoint ${host_base} ${include} ls s3:${file_to_list}  2>&1 >/dev/null

if ( [ "$?" != "0" ] )
then
        status "Failed to list file ${file_to_list} from datastore"
        exit 1
fi
