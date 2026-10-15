website_url="${1}"

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

DNS_USERNAME="`${BUILD_HOME}/helpers/services/GetVariableValue.sh DNS_USERNAME`"
DNS_SECURITY_KEY="`${BUILD_HOME}/helpers/services/GetVariableValue.sh DNS_SECURITY_KEY`"
DNS_CHOICE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh DNS_CHOICE`"


zone_name="`/bin/echo ${website_url} | /usr/bin/cut -d'.' -f2-`"
zone_id="`${BUILD_HOME}/services/dns/GetZoneID.sh "${zone_name}"`"

if ( [ "${zoneid}" = "" ] )
then
        ${BUILD_HOME}/services/dns/CreateZone.sh  "${website_url}"
        zoneid="`${BUILD_HOME}/services/dns/GetZoneID.sh "${zone_name}"`"
fi

if ( [ "`/bin/echo ${DNS_SECURITY_KEY} | /bin/grep ':::'`" != "" ] )
then
        api_token="`/bin/echo ${DNS_SECURITY_KEY} | /usr/bin/awk -F':::' '{print $2}'`"
        /usr/bin/curl -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records?type=A&name=${website_url}"  -H "Authorization: Bearer ${api_token}" -H "Content-Type: application/json" | /usr/bin/jq -r '.result[].content'
else
        /usr/bin/curl -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records?type=A&name=${website_url}"  -H "X-Auth-Email: ${DNS_USERNAME}" -H "X-Auth-Key: ${DNS_SECURITY_KEY}" -H "Content-Type: application/json" | /usr/bin/jq -r '.result[].content'
fi
