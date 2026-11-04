status () {
	${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

BUILD_HOME="`/bin/cat /home/buildhome.dat`"
DATABASE_DBaaS_INSTALLATION_TYPE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh DATABASE_DBaaS_INSTALLATION_TYPE`"
MULTI_REGION="`${BUILD_HOME}/helpers/services/GetVariableValue.sh MULTI_REGION`"
PRIMARY_REGION="`${BUILD_HOME}/helpers/services/GetVariableValue.sh PRIMARY_REGION`"
TOKEN="`${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN`"

#########################################################################################################
#DATABASE_DBaaS_INSTALLATION_TYPE="Postgres:DBAAS:<engine>:<region>:<machine_type>:<cluster_size>:<cluster_label>:<db_name>:<db_username>:<db_password>:<vpc_id>:<subnet_id>
#DATABASE_DBaaS_INSTALLATION_TYPE="Postgres:DBAAS:postgresql/14.4:nl-ams:g6-nanode-1:1:test-cluster:testdb1:testdbuser:gdhf76gdfgsh:266632:266052"
#########################################################################################################

#extract the database's configuration detaila from DATABASE_DBaaS_INSTALLATION_TYPE
engine="`/bin/echo ${DATABASE_DBaaS_INSTALLATION_TYPE} | /usr/bin/awk -F':' '{print $3}'`"
cluster_size="`/bin/echo ${DATABASE_DBaaS_INSTALLATION_TYPE} | /usr/bin/awk -F':' '{print $6}'`" 
db_region="`/bin/echo ${DATABASE_DBaaS_INSTALLATION_TYPE} | /usr/bin/awk -F':' '{print $4}'`"
machine_type="`/bin/echo ${DATABASE_DBaaS_INSTALLATION_TYPE} | /usr/bin/awk -F':' '{print $5}'`"
label="`/bin/echo ${DATABASE_DBaaS_INSTALLATION_TYPE} | /usr/bin/awk -F':' '{print $7}'`"
vpc_id="`/bin/echo ${DATABASE_DBaaS_INSTALLATION_TYPE} | /usr/bin/awk -F':' '{print $11}'`"
subnet_id="`/bin/echo ${DATABASE_DBaaS_INSTALLATION_TYPE} | /usr/bin/awk -F':' '{print $12}'`"

if ( [ "${MULTI_REGION}" = "1" ] && [ "${PRIMARY_REGION}" = "1" ] )
then
  public_access="--private_network.public_access true"
else
  public_access="--private_network.public_access false"
fi

export LINODE_CLI_TOKEN="${TOKEN}"
              
/usr/local/bin/linode-cli databases mysql-create --no-defaults --label "${label}" --region "${db_region}" --type "${machine_type}" --cluster_size "${cluster_size}" --engine "${engine}" --ssl_connection true --allow_list "0.0.0.0/0" --private_network.vpc_id "${vpc_id}"  --private_network.subnet_id "${subnet_id}" ${public_access}

if [ $? -ne 0 ] 
then
	status "Failed to provision DBaaS server"
	unset LINODE_CLI_TOKEN
	exit 1
fi
unset LINODE_CLI_TOKEN
