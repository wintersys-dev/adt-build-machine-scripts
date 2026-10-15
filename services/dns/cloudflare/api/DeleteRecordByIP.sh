#!/bin/sh

website_url="${1}"
ip="${2}"

DNS_USERNAME="`${HOME}/utilities/config/ExtractConfigValue.sh 'DNSUSERNAME'`"
DNS_SECURITY_KEY="`${HOME}/utilities/config/ExtractConfigValue.sh 'DNSSECURITYKEY'`"
DNS_CHOICE="`${HOME}/utilities/config/ExtractConfigValue.sh 'DNSCHOICE'`"

zone_name="`/bin/echo ${website_url} | /usr/bin/awk -F'.' '{$1=""}1' | /bin/sed 's/^ //g' | /bin/sed 's/ /./g'`"
zone_id="`${HOME}/services/dns/GetZoneID.sh "${zone_name}" "${DNS_USERNAME}" "${DNS_SECURITY_KEY}" "${DNS_CHOICE}"`"

if ( [ "`/bin/echo ${DNS_SECURITY_KEY} | /bin/grep ':::'`" != "" ] )
then
        api_token="`/bin/echo ${DNS_SECURITY_KEY} | /usr/bin/awk -F':::' '{print $2}'`"
        record_id="`/usr/bin/curl "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" --header "Authorization: Bearer ${api_token}" --header "Content-Type: application/json" | /usr/bin/jq -r '.result[]  | select (.content == "'${ip}'").id'`"
        /usr/bin/curl -X DELETE "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${record_id}" --header "Authorization: Bearer ${api_token}" --header "Content-Type: application/json"
else
        auth_key="${DNS_SECURITY_KEY}"
        record_id="`/usr/bin/curl "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" -H "X-Auth-Email: ${email}" -H "X-Auth-Key: ${auth_key}" -H "Content-Type: application/json" | /usr/bin/jq -r '.result[]  | select (.content == "'${ip}'").id'`"
        /usr/bin/curl -X DELETE "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${record_id}" -H "X-Auth-Email: ${email}"  -H "X-Auth-Key: ${auth_key}" -H "Content-Type: application/json"
fi
