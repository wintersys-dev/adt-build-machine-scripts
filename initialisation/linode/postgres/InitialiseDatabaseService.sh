	

#if we are here then this is a postgres build
status "Your database is being provisioned, please wait....."
database_id="`/usr/local/bin/linode-cli databases postgresql-list --no-defaults --json | jq '.[] | select(.label | contains ("'${label}'")) | .id'`"

if ( [ "${database_id}" = "" ] )
then   
	#there was no existing database, so, create one
	if ( [ "${DB_INSTALL_MODE}" = "0" ] || [ "${DB_INSTALL_MODE}" = "2" ] )
	then
		status "You must have DB_INSTALL_MODE set to 1 for a newly provisioned database"
		status "Do want me to set DB_INSTALL_MODE to '1' so that the build will continue (Y|y) otherwise I will have to exit"
		response="Y"
						
		if ( [ "`${BUILD_HOME}/helpers/services/IsHardcoreBuild.sh`" != "1" ] )
		then
			read response
		fi

		if ( [ "${response}" = "y" ] || [ "${response}" = "Y" ] )
		then
			DB_INSTALL_MODE="1"
		else
			status "Can't continue with installation, DB_INSTALL_MODE not set as required"
			exit -1
		fi
	fi
	/usr/local/bin/linode-cli databases postgresql-create --no-defaults --label "${label}" --region "${db_region}" --type "${machine_type}" --cluster_size "${cluster_size}" --engine "${engine}" --ssl_connection "true" --allow_list "0.0.0.0/0" --private_network.vpc_id "${vpc_id}"  --private_network.subnet_id "${subnet_id}" ${public_access}
	database_id="`/usr/local/bin/linode-cli databases postgresql-list --no-defaults --json | jq -r '.[] | select(.label | contains ("'${label}'")) | .id'`"

	while ( [ "${database_id}" = "" ] ) 
	do
		status "Attempting to get database id...if I am looking for more than a few minutes something must be wrong"
		/bin/sleep 20
		database_id="`/usr/local/bin/linode-cli databases postgresql-list --no-defaults --json | jq -r '.[] | select(.label | contains ("'${label}'")) | .id'`"
	done

	#Wait for the database we have provisioned to become active
	status "Have got the database id which is: ${database_id}"
	status "Its now the wait for the database to become active (this can take a few minutes)"

	status="`/usr/local/bin/linode-cli databases postgresql-list --no-defaults --json | /usr/bin/jq -r '.[] | select (.id == '${database_id}').status'`"

	while ( [ "${status}" != "active" ] ) 
	do
		/bin/sleep 20
		status="`/usr/local/bin/linode-cli databases postgresql-list --no-defaults --json  | /usr/bin/jq -r '.[] | select (.id == '${database_id}').status'`"
	done
else
	#Open up during the build and tighten up afterwards
	/usr/local/bin/linode-cli databases postgresql-update ${database_id} --allow_list "0.0.0.0/0" --no-defaults 
fi

#take a note of all our configuration settings
export CLUSTER_NAME="`/usr/local/bin/linode-cli databases postgresql-list --no-defaults --json | /usr/bin/jq -r '.[] | select (.id == '${database_id}') | .label'`" 
export DB_IDENTIFIER="`/usr/local/bin/linode-cli databases postgresql-list --no-defaults --json | /usr/bin/jq -r '.[] | select (.id == '${database_id}') | .hosts.primary'`"
export DB_USERNAME="`/usr/local/bin/linode-cli databases postgresql-creds-view ${database_id} --no-defaults --json | /usr/bin/jq -r '.[].username'`"
export DB_PASSWORD="`/usr/local/bin/linode-cli databases postgresql-creds-view ${database_id} --no-defaults --json  | /usr/bin/jq -r '.[].password'`"
export DB_PORT="`/usr/local/bin/linode-cli databases postgresql-list --no-defaults --json | /usr/bin/jq -r '.[] | select (.id == '${database_id}').port'`"
export DB_NAME="${db_name}"

if ( [ "${db_scope_prefix}" != "" ] )
then
	DB_IDENTIFIER="`/bin/echo ${DB_IDENTIFIER} | /bin/sed "s/^private-/${db_scope_prefix}"`"
fi

#grab the cert, why not, we might need it
/bin/echo "`/usr/local/bin/linode-cli databases postgresql-ssl-cert ${database_id} --no-headers --no-defaults --json | /usr/bin/jq -r '.[].ca_certificate' | /usr/bin/base64 --decode`" > ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/DBaaS_CERT

