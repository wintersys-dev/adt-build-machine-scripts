

# Input validation
if [ -z "${1}" ] 
then
        status "Error: buildmachine IP argument are required."
        status "Usage: $0 <buildmachine_ip>"
        exit 1
fi

buildmachine_ip="${1}"

server_name="$(${BUILD_HOME}/services/server/GetServerName.sh ${buildmachine_ip})"
#if ( [ "${server_name}" = "" ] )
#then
#server_name="NOT_SET"
#fi
${BUILD_HOME}/services/server/GetServerPrivateIPAddresses.sh ${server_name} 

