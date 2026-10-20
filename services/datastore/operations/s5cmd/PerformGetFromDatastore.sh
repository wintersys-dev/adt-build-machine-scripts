datastore_tool=""

if ( [ "`/bin/grep "^DATASTORETOOL:*" ${BUILD_HOME}/configuration/software.dat | /bin/grep s3cmd`" != "" ] )
then
        datastore_tool="/usr/bin/s3cmd"
elif ( [ "`/bin/grep "^DATASTORETOOL:*" ${BUILD_HOME}/configuration/software.dat | /bin/grep s5cmd`" != "" ] )
then
        datastore_tool="/usr/bin/s5cmd"
elif ( [ "`/bin/grep "^DATASTORETOOL:*" ${BUILD_HOME}/configuration/software.dat | /bin/grep rclone`" != "" ] )
then
        datastore_tool="/usr/bin/rclone"
fi

if ( [ "${datastore_tool}" = "/usr/bin/s3cmd" ] )
then
        host_base="`/bin/grep ^host_base /root/.s3cfg-1 | /usr/bin/awk -F'=' '{print  $NF}' | /bin/sed 's/ //g'`"
        datastore_cmd="${datastore_tool} --config=/root/.s3cfg-1 --host=https://${host_base} ls s3://"
        datastore_cmd1="${datastore_tool} --config=/root/.s3cfg-1 --host=https://${host_base} get s3://"
elif ( [ "${datastore_tool}" = "/usr/bin/s5cmd" ] )
then
        host_base="`/bin/grep ^host_base /root/.s5cfg-1 | /usr/bin/awk -F'=' '{print  $NF}' | /bin/sed 's/ //g'`"
        datastore_cmd="${datastore_tool} --credentials-file /root/.s5cfg-1 --endpoint-url https://${host_base} ls s3://"
        datastore_cmd1="${datastore_tool} --credentials-file /root/.s5cfg-1 --endpoint-url https://${host_base} cp s3://"
elif ( [ "${datastore_tool}" = "/usr/bin/rclone" ] )
then
        host_base="`/bin/grep ^endpoint /root/.config/rclone/rclone.conf-1 | /usr/bin/awk -F'=' '{print  $NF}' | /bin/sed 's/ //g'`" 
        datastore_cmd="${datastore_tool} --config /root/.config/rclone/rclone.conf-1 --s3-endpoint ${host_base}  ls s3:"
        datastore_cmd1="${datastore_tool} --config /root/.config/rclone/rclone.conf-1 --s3-endpoint ${host_base} copy s3:"
fi

if ( [ "${destination}" = "" ] )
then
        destination="."
fi

if ( [ ! -d ${destination} ] )
then
        /bin/mkdir -p ${destination}
fi

if ( [ "`${datastore_cmd}${active_bucket}/${file_to_get}`" = "" ] )
then
        /bin/echo "Key does not exist"
else
        count="0"
        while ( [ "`${datastore_cmd1}${active_bucket}/${file_to_get} ${destination} 2>&1 >/dev/null | /bin/grep -E "(ERROR|NOTICE)"`" != "" ] && [ "${count}" -lt "5" ] )
        do
                /bin/echo "An error has occured `/usr/bin/expr ${count} + 1` times in script ${0}"
                /bin/sleep 5
                count="`/usr/bin/expr ${count} + 1`"
        done
fi
