BUILD_HOME="`/bin/cat /home/buildhome.dat`"
CLOUDHOST="`${BUILD_HOME}/helpers/services/GetVariableValue.sh CLOUDHOST`"
BUILD_IDENTIFIER="`${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILD_IDENTIFIER`"

sourcefile="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/scaling/scaling.conf"

if ( [ ! -f  ./AdjustScaling.sh ] )
then
	/bin/echo "Sorry, this script has to be run from the ${BUILD_HOME}/helpers/services subdirectory"
	exit
fi

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

if ( [ "`${BUILD_HOME}/helpers/services/GetVariableValue.sh DEPLOYMENT_MODE`" != "PRODUCTION" ] )
then
	/bin/echo "You are not in PRODUCTION mode, cannot set scaling parameters"
	exit
fi

/bin/echo "Please enter the number of webservers you want to be provisioned and active"
read no_webservers

case "${no_webservers}" in
    # Check if empty or contains anything other than digits
    ''|*[!0-9]*) 
        /bin/echo "Error: Number of webservers must be a positive integer." 
		;;
    *) 
        # Check if the no_webservers is within the 1-${MAX_WEBSERVERS} range
        if ( [ "${no_webservers}" -ge "1" ] && [ "${no_webservers}" -le "${MAX_WEBSERVERS}" ] )
		then
            /bin/echo "Valid number of webservers set: ${no_webservers}"
        else
            /bin/echo "Error: number of webservers must be between 1 and ${MAX_WEBSERVERS}"
			exit
        fi
        ;;
esac
#Put the number of webservers into the scaling file
/bin/echo "${no_webservers}" > ${sourcefile}

${BUILD_HOME}/helpers/scaling/TestIfScalingAllowed.sh

