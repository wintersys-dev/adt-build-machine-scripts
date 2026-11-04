
status () {
	${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

available_engines=$(/usr/local/bin/linode-cli databases engines --json | jq -r '.[].id' 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$available_engines" ]; then
    status "Failed to obtain list of available engines"
    exit 1
fi

if ! echo "$available_engines" | /bin/grep -q -w "${engine}"; then
    status "The database engine you have selected is not available please correct and re deploy"
    exit 1
fi

echo "$available_engines"
