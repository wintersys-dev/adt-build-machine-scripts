/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s -X PUT "https://api.linode.com/v4/networking/firewalls/${firewall_id}/rules" --json "$(jq -n --argjson rules "${ruleset}" '{inbound: $rules}')"
if [ "$?" != "0" ]   
then
        status "Unable to update firewall rules"
        exit 1          
fi  
