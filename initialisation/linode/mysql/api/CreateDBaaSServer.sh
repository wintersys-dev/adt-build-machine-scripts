status () {
	${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

BUILD_HOME="`/bin/cat /home/buildhome.dat`"
DATABASE_DBaaS_INSTALLATION_TYPE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh DATABASE_DBaaS_INSTALLATION_TYPE`"
MULTI_REGION="`${BUILD_HOME}/helpers/services/GetVariableValue.sh MULTI_REGION`"
PRIMARY_REGION="`${BUILD_HOME}/helpers/services/GetVariableValue.sh PRIMARY_REGION`"
TOKEN="`${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN`"

#########################################################################################################
#DATABASE_DBaaS_INSTALLATION_TYPE="MySQL:DBAAS:<engine>:<region>:<machine_type>:<cluster_size>:<cluster_label>:<db_name>:<db_username>:<db_password>:<vpc_id>:<subnet_id>
#DATABASE_DBaaS_INSTALLATION_TYPE="MySQL:DBAAS:mysql/8:nl-ams:g6-nanode-1:1:test-cluster:testdb1:testdbuser:gdhf76gdfgsh:266632:266052"
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

/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s -X POST "https://api.linode.com/v4/databases/mysql/instances" -H "Content-Type: application/json" -d '{ "label": "'"${label}"'", "region": "'"${db_region}"'", "type": "'"${machine_type}"'", "engine": "'"${engine}"'", "cluster_size": '"${cluster_size}"', "ssl_connection": true, "allow_list": ["0.0.0.0/0"], "private_network": { "vpc_id": '"${vpc_id}"', "subnet_id": '"${subnet_id}"' } }'

              
