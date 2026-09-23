BUILD_HOME="`/bin/cat /home/buildhome.dat`"
CLOUDHOST="`${BUILD_HOME}/helpers/services/GetVariableValue.sh CLOUDHOST`"
BUILD_IDENTIFIER="`${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILD_IDENTIFIER`"
REGION="`${BUILD_HOME}/helpers/services/GetVariableValue.sh REGION`"


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

if ( [ -f ${sourcefile} ] )
then
	/bin/rm ${sourcefile}
fi

start_index="1"
no_autoscalers="`${BUILD_HOME}/services/server/NumberOfServers.sh "as-${REGION}-${BUILD_IDENTIFIER}" ${CLOUDHOST}`"

span="`/usr/bin/expr ${no_webservers} - ${start_index} + 1`"
base="`/usr/bin/expr ${span} / ${no_autoscalers}`"
remainder="`/usr/bin/expr ${span} % ${no_autoscalers}`"

current_start="${start_index}"
count="0"

while ( [ "${count}" -lt "${no_autoscalers}" ] )
do
    if ( [ "${count}" -lt "${remainder}" ] )
    then
        current_size="`/usr/bin/expr ${base} + 1`"
    else
        current_size="${base}"
    fi

    if ( [ "${current_size}" -gt "0" ] )
    then
        current_end="`/usr/bin/expr ${current_start} + ${current_size}`"
        /bin/echo "Autoscaler `/usr/bin/expr ${count} + 1` is responsible for provisioning `/usr/bin/expr ${current_end} - ${current_start}` webservers" >> ${sourcefile}
        current_start="`/usr/bin/expr ${current_end} + 1`"
    fi

    count="`/usr/bin/expr ${count} + 1`"
done



${BUILD_HOME}/helpers/scaling/TestIfScalingAllowed.sh

