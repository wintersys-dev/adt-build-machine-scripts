#!/bin/sh 

set -x


zone_name="`/bin/echo ${1} | /usr/bin/cut -d'.' -f2-`"

BUILD_HOME="`/bin/cat /home/buildhome.dat`"
DNS_USERNAME="`${BUILD_HOME}/helpers/services/GetVariableValue.sh DNS_USERNAME`"
DNS_SECURITY_KEY="`${BUILD_HOME}/helpers/services/GetVariableValue.sh DNS_SECURITY_KEY`"

if ( [ "`curl -s -X GET ""https://api.cloudflare.com/client/v4/zones?name=${zone_name}""  -H "X-Auth-Email: ${DNS_USERNAME}"  -H "X-Auth-Key: ${DNS_SECURITY_KEY}" -H "Content-Type: application/json" | /usr/bin/jq -r 'if (.result | length) > 0 then "true" else "false" end'`" = "false" ] )
then
        if ( [ "`/bin/echo ${DNS_SECURITY_KEY} | /bin/grep ':::'`" != "" ] )
        then
                api_token="`/bin/echo ${DNS_SECURITY_KEY} | /usr/bin/awk -F':::' '{print $2}'`"
                /usr/bin/curl -X POST "https://api.cloudflare.com/client/v4/zones" --header "Authorization: Bearer ${api_token}" --header "Content-Type: application/json" --data '{"name":"'${zone_name}'"}' 
        else
                /usr/bin/curl -X POST "https://api.cloudflare.com/client/v4/zones" -H "X-Auth-Email: ${DNS_USERNAME}" -H "X-Auth-Key: ${DNS_SECURITY_KEY}" -H "Content-Type: application/json" --data '{"name":"'${zone_name}'"}'
        fi
        #it takes a few seconds for the zone to be created

        while ( [ "`curl -s -X GET ""https://api.cloudflare.com/client/v4/zones?name=${zone_name}""  -H "X-Auth-Email: ${DNS_USERNAME}"  -H "X-Auth-Key: ${DNS_SECURITY_KEY}" -H "Content-Type: application/json" | /usr/bin/jq -r 'if (.result | length) > 0 then "true" else "false" end'`" = "false" ] )
        do
                /bin/sleep 5
        done
fi
