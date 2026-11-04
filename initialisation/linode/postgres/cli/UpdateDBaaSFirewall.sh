
database_id="${1}"
allow_list="${2}"

BUILD_HOME="$(/bin/cat /home/buildhome.dat)"

TOKEN="`${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN`"
export LINODE_CLI_TOKEN="${TOKEN}"

/usr/local/bin/linode-cli databases mysql-update ${database_id} --allow_list "${allow_list}" --no-defaults

if [ $? -ne 0 ] 
then
        status "Database ${database_id} firewall allow list failed to update"
        unset LINODE_CLI_TOKEN
        exit 1
fi

unset LINODE_CLI_TOKEN
