

database_id="${1}"

BUILD_HOME="`/bin/cat /home/buildhome.dat`"
CLOUDHOST="`${BUILD_HOME}/helpers/services/GetVariableValue.sh CLOUDHOST`"
BUILD_IDENTIFIER="`${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILD_IDENTIFIER`"
TOKEN="`${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN`"

export LINODE_CLI_TOKEN="${TOKEN}"
/bin/echo "`/usr/local/bin/linode-cli databases mysql-ssl-cert ${database_id} --no-headers --no-defaults --json | /usr/bin/jq -r '.[].ca_certificate' | /usr/bin/base64 --decode`" > ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/DBaaS_CERT

if [ ! -f ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/DBaaS_CERT ] || [ "$(/usr/bin/openssl x509 -in ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/DBaaS_CERT -checkend 0 -noout | /bin/grep 'Certificate will not expire')" = "" ]
then
  status "DBaaS certificate not present or invalid"
  unset LINODE_CLI_TOKEN
  exit 1
fi

unset LINODE_CLI_TOKEN
