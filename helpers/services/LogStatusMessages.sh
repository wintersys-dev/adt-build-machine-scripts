BUILD_HOME="`/bin/cat /home/buildhome.dat`"
CLOUDHOST="`/bin/cat ${BUILD_HOME}/runtime/ACTIVE_CLOUDHOST`"
BUILD_IDENTIFIER="`/bin/cat ${BUILD_HOME}/runtime/ACTIVE_BUILD_IDENTIFIER`"

# Assign colors dynamically using standard octal escapes
blue="`/bin/echo -e '\033[34m'`"
purple="`/bin/echo -e '\033[35m'`"
red="`/bin/echo -e '\033[31m'`"
yellow="`/bin/echo -e '\033[33m'`"
green="`/bin/echo -e '\033[32m'`"
reset="`/bin/echo -e '\033[0m'`"

figlet="0"
if ( [ "${2}" != "" ] )
then
    if ( [ "${2}" = "blue" ] )
    then
        colour="${blue}"
    elif ( [ "${2}" = "purple" ] )
    then
        colour="${purple}"
    elif ( [ "${2}" = "red" ] )
    then
        colour="${red}"
    elif ( [ "${2}" = "yellow" ] )
    then
        colour="${yellow}"
    elif ( [ "${2}" = "green" ] )
    then
        colour="${green}"
    elif ( [ "${2}" = "figlet" ] )
    then
        figlet="1"
    fi
else
    colour=""
    reset=""
fi
        
status_file="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/logs/build_status_stream.log"

message="${1}"

if ( [ "${message}" != "" ] )
then
    if ( [ "${figlet}" = "0" ] )
    then
        /bin/echo "${colour}${message}${reset}" | /usr/bin/tee -a "${status_file}"
    else
        /usr/bin/figlet "${message}" | /usr/bin/tee -a "${status_file}"
    fi
fi


