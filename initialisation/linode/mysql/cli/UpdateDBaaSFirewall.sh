
database_id="${1}"
allow_list="${2}"
  
/usr/local/bin/linode-cli databases mysql-update ${database_id} --allow_list "${allow_list}" --no-defaults

if [ $? -ne 0 ] 
then
  status "Database ${database_id} firewall allow list failed to update"
  exit 1
fi
