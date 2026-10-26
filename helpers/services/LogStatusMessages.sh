BUILD_HOME="`/bin/cat /home/buildhome.dat`"
CLOUDHOST="`/bin/cat ${BUILD_HOME}/runtime/ACTIVE_CLOUDHOST`"
BUILD_IDENTIFIER="`/bin/cat ${BUILD_HOME}/runtime/ACTIVE_BUILD_IDENTIFIER`"


out_file="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/logs/build_output_stream.log"
err_file="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/logs/build_error_stream.log"
status_file="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/logs/build_status_stream.log"


if [ -t 1 ]
then
    exec 1>> "${out_file}"
    exec 2>> "${err_file}"  
fi

#if  ( [ -t 1 ] )
#then
#    exec 1>> ${out_file}
#fi

#if  ( [ -t 2 ] )
#then
#    exec 2>> ${err_file}
#fi

#if  ( [ -t 3 ] )
#then
#    exec 3>> ${status_file}
#fi

message="${1}"

if ( [ "${message}" != "" ] )
then
    /bin/echo "${message}" | /usr/bin/tee -a "${status_file}"
fi


