#!/bin/sh

record_id="${1}"

DNS_USERNAME="`${BUILD_HOME}/helpers/services/GetVariableValue.sh DNS_USERNAME`"
DNS_SECURITY_KEY="`${BUILD_HOME}/helpers/services/GetVariableValue.sh DNS_SECURITY_KEY`"
DNS_CHOICE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh DNS_CHOICE`"

zone_name="`/bin/echo ${website_url} | /usr/bin/awk -F'.' '{$1=""}1' | /bin/sed 's/^ //g' | /bin/sed 's/ /./g'`"
zone_id="`${HOME}/services/dns/GetZoneID.sh "${zone_name}" "${DNS_USERNAME}" "${DNS_SECURITY_KEY}" "${DNS_CHOICE}"`"

if ( [ "`/bin/echo ${DNS_SECURITY_KEY} | /bin/grep ':::'`" != "" ] )
then
        api_token="`/bin/echo ${DNS_SECURITY_KEY} | /usr/bin/awk -F':::' '{print $2}'`"
        /usr/bin/curl -X DELETE "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${record_id}" --header "Authorization: Bearer ${api_token}" --header "Content-Type: application/json"
else
        auth_key="${DNS_SECURITY_KEY}"
        /usr/bin/curl -X DELETE "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${record_id}" -H "X-Auth-Email: ${email}"  -H "X-Auth-Key: ${auth_key}" -H "Content-Type: application/json"
fi
