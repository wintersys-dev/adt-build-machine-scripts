BUILD_HOME="`/bin/cat /home/buildhome.dat`"
TOKEN="`${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN`"


curl -s -H "Authorization: Bearer $TOKEN" "https://api.linode.com/v4/domains" |  jq -r --arg dom "$domain_url" '.data[] | select(.domain | contains($dom)).id'
