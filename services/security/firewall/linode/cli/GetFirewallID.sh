



firewall_id="`/usr/local/bin/linode-cli --json firewalls list | /usr/bin/jq -r '.[] | select (.label | contains ("'${firewall_name}'")) |  select (.label | endswith ("'-${BUILD_IDENTIFIER}'")).id'`"

if ( [ "$?" != "0" ] )
then
	unset LINODE_CLI_TOKEN
    status "Unable to get firewall ID"
    exit 1
fi
