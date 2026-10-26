BUILD_HOME="`/bin/cat /home/buildhome.dat`"
CLOUDHOST="`/bin/cat ${BUILD_HOME}/runtime/ACTIVE_CLOUDHOST`"
BUILD_IDENTIFIER="`/bin/cat ${BUILD_HOME}/runtime/ACTIVE_BUILD_IDENTIFIER`"

# Assign colors dynamically using standard octal escapes
blue="`/bin/echo '\033[34m'`"
orange="`/bin/echo '\033[38;5;208m'`" 
red="`/bin/echo '\033[31m'`"
yellow="`/bin/echo '\033[33m'`"
green="`/bin/echo '\033[32m'`"
reset="`/bin/echo '\033[0m'`"

if ( [ "${2}" != "" ] )
then
    if ( [ "${2}" = "blue" ] )
    then
        colour="${blue}"
    elif ( [ "${2}" = "orange" ] )
    then
        colour="${orange}"
    elif ( [ "${2}" = "red" ] )
    then
        colour="${red}"
    elif ( [ "${2}" = "yellow" ] )
    then
        colour="${yellow}"
    elif ( [ "${2}" = "green" ] )
    then
        colour="${green}"
    fi
else
    colour=""
    reset=""
fi
        
status_file="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/logs/build_status_stream.log"

message="${1}"

if ( [ "${message}" != "" ] )
then
    /bin/echo "${clour}${message}${reset}" | /usr/bin/tee -a "${status_file}"
fi


