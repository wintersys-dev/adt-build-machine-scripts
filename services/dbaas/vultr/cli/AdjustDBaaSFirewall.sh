#!/bin/sh

status () {
	${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

BUILD_HOME="`/bin/cat /home/buildhome.dat`"
DATABASE_DBaaS_INSTALLATION_TYPE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh DATABASE_DBaaS_INSTALLATION_TYPE`"
VPC_IP_RANGE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh VPC_IP_RANGE`"
        
        
cluster_name="`/bin/echo ${DATABASE_DBaaS_INSTALLATION_TYPE} | /usr/bin/awk '{print $8}'`"
cluster_id="`/usr/local/bin/doctl database list -o json | /usr/bin/jq -r '.[] | select (.name == "'${cluster_name}'").id'`"
if ( [ "$?" != "0" ] )
then
        status "Failed to get cluster id"
        exit 1
fi
/usr/bin/vultr database update ${cluster_id} --trusted-ips="${VPC_IP_RANGE}"
if ( [ "$?" != "0" ] )
then
        status "Failed to update allowed ip addresses DBaaS"
        exit 1
fi

