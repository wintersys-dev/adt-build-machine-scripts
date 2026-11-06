


/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s  -X PUT -H 'Content-Type: application/json' -d '{"inbound": [], "outbound": [], "inbound_policy": "DROP", "outbound_policy": "ACCEPT"}' 'https://api.linode.com/v4/networking/firewalls/'${firewall_id}'/rules'
if [ "$?" != "0" ] 
then
  status "Unable to update firewall rules"  
  exit 1        
fi
