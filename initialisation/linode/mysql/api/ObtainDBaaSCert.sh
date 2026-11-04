

set -x
status () {
        ${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

database_id="${1}"

BUILD_HOME="`/bin/cat /home/buildhome.dat`"
CLOUDHOST="`${BUILD_HOME}/helpers/services/GetVariableValue.sh CLOUDHOST`"
BUILD_IDENTIFIER="`${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILD_IDENTIFIER`"
TOKEN="`${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN`"

/bin/echo "`/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s "https://api.linode.com/v4/databases/mysql/instances/${database_id}/ssl" | jq -r '.ca_certificate' | base64 --decode`" > "${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/DBaaS_CERT"

if [ ! -f ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/DBaaS_CERT ] || [ "$(/usr/bin/openssl x509 -in ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/DBaaS_CERT -checkend 0 -noout | /bin/grep 'Certificate will not expire')" = "" ]
then
  status "DBaaS certificate not present or invalid"
  exit 1
fi
