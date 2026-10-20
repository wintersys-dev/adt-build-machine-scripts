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
        datastore_cmd="${datastore_tool} --recursive --config=/root/.s3cfg-1 --host=https://${host_base} ls s3://${active_bucket}/"
        file_to_list="`/bin/echo ${file_to_list} | /bin/sed 's/\*.*//g'`"
elif ( [ "${datastore_tool}" = "/usr/bin/s5cmd" ] )
then
        host_base="`/bin/grep ^host_base /root/.s5cfg-1 | /usr/bin/awk -F'=' '{print  $NF}' | /bin/sed 's/ //g'`" 
        datastore_cmd="${datastore_tool} --credentials-file /root/.s5cfg-1 --endpoint-url https://${host_base} ls s3://${active_bucket}/"
elif ( [ "${datastore_tool}" = "/usr/bin/rclone" ] )
then
        host_base="`/bin/grep ^endpoint /root/.config/rclone/rclone.conf-1 | /usr/bin/awk -F'=' '{print  $NF}' | /bin/sed 's/ //g'`" 
        include=""

        if ( [ "${file_to_list}" != "" ] )
        then
                include='--include "*'${file_to_list}*'"'
        fi

        datastore_cmd="${datastore_tool} --config /root/.config/rclone/rclone.conf-1 --s3-endpoint ${host_base} ${include} ls s3:${active_bucket}/"
        file_to_list=""
fi

eval ${datastore_cmd}${file_to_list}  2>/dev/null 

#| /usr/bin/awk '{print $NF}' | /usr/bin/awk -F'/' '{print $NF}' | /bin/sed '/^$/d'
