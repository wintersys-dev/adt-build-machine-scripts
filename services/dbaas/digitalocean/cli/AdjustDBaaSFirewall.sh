#!/bin/sh

status () {
	${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

BUILD_HOME="`/bin/cat /home/buildhome.dat`"
DATABASE_DBaaS_INSTALLATION_TYPE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh DATABASE_DBaaS_INSTALLATION_TYPE`"
VPC_IP_RANGE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh VPC_IP_RANGE`"

cluster_name="`/bin/echo ${DATABASE_DBaaS_INSTALLATION_TYPE} | /usr/bin/awk -F':' '{print $8}'`"

cluster_id="`/usr/local/bin/doctl database list -o json | /usr/bin/jq -r '.[] | select (.name == "'${cluster_name}'").id'`"
if ( [ "$?" != "0" ] )
then
        status "Failed to get the cluster ID"
        exit 1
fi

/usr/local/bin/doctl databases firewalls replace ${cluster_id} --rule ip_addr:${VPC_IP_RANGE}
if ( [ "$?" != "0" ] )
then
        status "Failed to set allowed ip addresses for DBaaS"
        exit 1
fi            
