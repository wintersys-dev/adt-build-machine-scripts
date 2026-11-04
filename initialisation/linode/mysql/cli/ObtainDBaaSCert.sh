

database_id="${1}"

BUILD_HOME="`/bin/cat /home/buildhome.dat`"
CLOUDHOST="`${BUILD_HOME}/helpers/services/GetVariableValue.sh CLOUDHOST`"
BUILD_IDENTIFIER="`${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILD_IDENTIFIER`"

/bin/echo "`/usr/local/bin/linode-cli databases mysql-ssl-cert ${database_id} --no-headers --no-defaults --json | /usr/bin/jq -r '.[].ca_certificate' | /usr/bin/base64 --decode`" > ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/DBaaS_CERT
