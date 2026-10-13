set -x

BUILD_HOME="`/bin/cat /home/buildhome.dat`"
TOKEN="`${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN`"

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
