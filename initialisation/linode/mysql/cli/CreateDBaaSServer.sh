
                
                


/usr/local/bin/linode-cli databases mysql-create --no-defaults --label "${label}" --region "${db_region}" --type "${machine_type}" --cluster_size "${cluster_size}" --engine "${engine}" --ssl_connection true --allow_list "0.0.0.0/0" --private_network.vpc_id "${vpc_id}"  --private_network.subnet_id "${subnet_id}" ${public_access}
