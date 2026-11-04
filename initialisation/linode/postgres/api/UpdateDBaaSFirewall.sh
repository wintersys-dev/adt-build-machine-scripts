database_id="${1}"
allow_list="${2}"

BUILD_HOME="$(/bin/cat /home/buildhome.dat)"

TOKEN="`${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN`"

/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s -X PUT "https://api.linode.com/v4/databases/postgresql/instances/${database_id}" -H "Content-Type: application/json"  -d '{"allow_list": ["0.0.0.0/0"]}'

if [ $? -ne 0 ] 
then
        status "Database ${database_id} firewall allow list failed to update"
        exit 1
fi
