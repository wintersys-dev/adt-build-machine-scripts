BUILD_HOME="`/bin/cat /home/buildhome.dat`"
CLOUDHOST="`/bin/cat ${BUILD_HOME}/runtime/ACTIVE_CLOUDHOST`"
BUILD_IDENTIFIER="`/bin/cat ${BUILD_HOME}/runtime/ACTIVE_BUILD_IDENTIFIER`"

        
initial_status_file="/root/logs/initial_build_status_stream.log"

message="${1}"

if ( [ "${message}" != "" ] )
then
  /bin/echo "${colour}${message}${reset}" | /usr/bin/tee -a "${initial_status_file}"
fi
