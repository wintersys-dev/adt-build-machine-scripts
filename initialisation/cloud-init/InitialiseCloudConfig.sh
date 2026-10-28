machine_type="${1}"
machine_type_upper="`/bin/echo ${1} | /usr/bin/tr '[:lower:]' '[:upper:]'`"

BUILD_HOME="`/bin/cat /home/buildhome.dat`"
CLOUDHOST="`/bin/cat ${BUILD_HOME}/runtime/ACTIVE_CLOUDHOST`"
BUILD_IDENTIFIER="`/bin/cat ${BUILD_HOME}/runtime/ACTIVE_BUILD_IDENTIFIER`"

if ( [ -f  ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/${machine_type}.yaml ] )
then
        server_name_match="`/bin/grep "^hostname: " ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/${machine_type}.yaml | /usr/bin/awk '{print $NF}'`"
        /bin/sed -i "s/XXXX${machine_type_upper}_HOSTNAMEXXXX/${server_name}/g" ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/${machine_type}.yaml
        /bin/sed -i "s/${server_name_match}/${server_name}/g" ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/${machine_type}.yaml
        cloud_config="`/bin/cat ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/${machine_type}.yaml`"
fi
