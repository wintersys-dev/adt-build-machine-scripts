


	server_name="$(${BUILD_HOME}/services/server/GetServerName.sh ${server_ip})"
	if ( [ "${server_name}" = "" ] )
	then
		server_name="NOT_SET"
	fi
	${BUILD_HOME}/services/server/GetServerPrivateIPAddresses.sh ${server_name}
