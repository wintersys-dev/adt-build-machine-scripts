#!/bin/sh

BUILD_HOME="`/bin/cat /home/buildhome.dat`"
CLOUDHOST="`${BUILD_HOME}/helpers/services/GetVariableValue.sh CLOUDHOST`"
BUILD_IDENTIFIER="`${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILD_IDENTIFIER`"
REGION="`${BUILD_HOME}/helpers/services/GetVariableValue.sh REGION`"

MAX_WEBSERVERS="20"

sourcefile="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/scaling/scaling.conf"
authorised_to_scale_file="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/scaling/authorised_to_scale.conf"

machine_type="autoscaler"
machine_type_token="as"

if ( [ ! -f  ./AdjustScaling.sh ] )
then
        /bin/echo "Sorry, this script has to be run from the ${BUILD_HOME}/helpers/services subdirectory"
        exit
fi

if ( [ ! -f ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/scaling ] )
then
        /bin/mkdir -p ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/scaling
fi

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
        exit
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

token_to_match="${machine_type_token}-`${BUILD_HOME}/helpers/services/GetVariableValue.sh REGION`-${BUILD_IDENTIFIER}"

if ( [ -f ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/VPC-ACTIVE ] )
then
        ips="`${BUILD_HOME}/services/server/GetServerPrivateIPAddresses.sh ${token_to_match} ${CLOUDHOST} ${BUILD_HOME}`"
else
        ips="`${BUILD_HOME}/services/server/GetServerIPAddresses.sh ${token_to_match} ${CLOUDHOST} ${BUILD_HOME}`"
fi

/bin/cp /dev/null ${authorised_to_scale_file}

for ip in ${ips}
do
        if ( [ "`${BUILD_HOME}/helpers/scaling/TestIfScalingAllowed.sh ${ip}`" = "SCALING_ENABLED" ] )
        then
                /bin/echo "${ip}" >> ${authorised_to_scale_file}
        fi
done

if ( [ "`/usr/bin/wc -l ${authorised_to_scale_file} | /usr/bin/awk '{print $1}'`" = "${no_autoscalers}" ] )
then
        for ip in `/bin/cat ${authorised_to_scale_file}`
        do
                ${BUILD_HOME}/helpers/scaling/UpdateAutoscalersWithScalingConfig.sh ${ip}
        done
else
        /bin/echo "Not all your autoscalers are allowing scaling events right now"
fi

