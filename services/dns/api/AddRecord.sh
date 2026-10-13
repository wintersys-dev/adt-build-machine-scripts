set -x

status () {
        /bin/echo "${1}" | /usr/bin/tee /dev/fd/3 2>/dev/null
        script_name="`/bin/echo ${0} | /usr/bin/awk -F'/' '{print $NF}'`"
        /bin/echo "${script_name}: ${1}" | /usr/bin/tee -a /dev/fd/4 2>/dev/null
}

BUILD_HOME="`/bin/cat /home/buildhome.dat`"
TOKEN="`${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN`"

if ( [ "${1}" = "" ] )
then
        status "Error: 3 arguments are  required."
        status "Usage: $0 <domain> <ip> <dns>" 
        exit 1
fi

subdomain="`/bin/echo ${1} | /usr/bin/awk -F'.' '{print $1}'`"
domain_url="`/bin/echo ${1} | /usr/bin/cut -d'.' -f2-`"
ip="${2}"
dns="${3}"


domain_id="`curl -s -H "Authorization: Bearer $TOKEN" "https://api.linode.com/v4/domains" |  jq -r --arg dom "$domain_url" '.data[] | select(.domain | contains($dom)).id'`"
if ( [ "$?" != "0" ] )
then
  exit 1
fi

curl -s -X POST -H "Authorization: Bearer $TOKEN"  -H "Content-Type: application/json"  -d '{"type":"A","name":"'"${subdomain}"'","target":"'"${ip}"'","ttl_sec":60}'  "https://api.linode.com/v4/domains/${domain_id}/records"
if ( [ "$?" != "0" ] )
then
  exit 1
fi
