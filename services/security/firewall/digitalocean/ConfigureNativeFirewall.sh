secure_port="443"
if ( [ "${AUTHENTICATOR_TYPE}" = "wire-guard" ] && [ "${firewall_name}" = "adt-reverseproxy" ]  )
then
        secure_port="`/usr/bin/expr ${SSH_PORT} + 1`"
fi

if ( [ "`/bin/echo ${firewall_name} | /bin/grep "adt-authenticator"`" != "" ] )
then
        firewall_rules="`linode_firewall_rules "${firewall_name}" "${authenticator_firewall_ports}"`"
        rule_vpc_ssh='{"addresses":{"ipv4":["'${VPC_IP_RANGE}'"]},"action":"ACCEPT","protocol":"TCP","ports":"'${SSH_PORT}'"}'
        rule_icmp='{"addresses":{"ipv4":["0.0.0.0/0"]},"action":"ACCEPT","protocol":"ICMP"}'

        rule_build_machine=""
        if ( [ "${BUILD_MACHINE_VPC}" = "0" ] )
        then
                rule_build_machine='{"addresses":{"ipv4":["'${build_machine_ip}/32'"]},"action":"ACCEPT","protocol":"TCP","ports":"'${SSH_PORT}'"}'
        fi

        ruleset=""
        if ( [ "${rule_build_machine}" != "" ] )
        then
                ruleset="${rule_build_machine},"
        fi

        ruleset="${ruleset}${rule_vpc_ssh},${rule_icmp}${firewall_rules}"
fi

if ( [ "`/bin/echo ${firewall_name} | /bin/grep "adt-autoscaler"`" != "" ] )
then
        firewall_rules="`linode_firewall_rules "${firewall_name}" "${autoscaler_firewall_ports}"`"
        rule_vpc_ssh='{"addresses":{"ipv4":["'${VPC_IP_RANGE}'"]},"action":"ACCEPT","protocol":"TCP","ports":"'${SSH_PORT}'"}'
        rule_icmp='{"addresses":{"ipv4":["0.0.0.0/0"]},"action":"ACCEPT","protocol":"ICMP"}'
        rule_build_machine=""
        if ( [ "${BUILD_MACHINE_VPC}" = "0" ] )
        then
                rule_build_machine='{"addresses":{"ipv4":["'${build_machine_ip}/32'"]},"action":"ACCEPT","protocol":"TCP","ports":"'${SSH_PORT}'"}'
        fi

        ruleset=""
        if ( [ "${rule_build_machine}" != "" ] )
        then
                ruleset="${rule_build_machine},"
        fi
        ruleset="${ruleset}${rule_vpc_ssh},${rule_icmp}${firewall_rules}"
fi

if ( [ "`/bin/echo ${firewall_name} | /bin/grep "adt-reverseproxy"`" != "" ] )
then
        firewall_rules="`linode_firewall_rules "${firewall_name}" "${reverseproxy_firewall_ports}"`"

        rule_secure_port_udp=""
        if ( [ "${AUTHENTICATOR_TYPE}" = "wire-guard" ] )
        then
                rule_secure_port_udp='{"addresses":{"ipv4":["0.0.0.0/0"]},"action":"ACCEPT","protocol":"UDP","ports":"'${secure_port}'"}'
        fi

        if ( [ "${all_dns_proxy_ips}" = "" ] )
        then
                rule_secure_port_tcp='{"addresses":{"ipv4":["0.0.0.0/0"]},"action":"ACCEPT","protocol":"TCP","ports":"'${secure_port}'"}'
        else
                rule_secure_port_tcp='{"addresses":{"ipv4":['${all_dns_proxy_ips}']},"action":"ACCEPT","protocol":"TCP","ports":"'${secure_port}'"}'
        fi

        rule_vpc_ssh='{"addresses":{"ipv4":["'${VPC_IP_RANGE}'"]},"action":"ACCEPT","protocol":"TCP","ports":"'${SSH_PORT}'"}'

        rule_build_machine=""
        rule_build_machine_ssl=""
        if ( [ "${BUILD_MACHINE_VPC}" = "0" ] )
        then
                rule_build_machine='{"addresses":{"ipv4":["'${build_machine_ip}/32'"]},"action":"ACCEPT","protocol":"TCP","ports":"'${SSH_PORT}'"}'
                if ( [ "${NO_REVERSE_PROXIES}" != "0" ] )
                then
                        rule_build_machine_ssl='{"addresses":{"ipv4":["'${build_machine_ip}/32'"]},"action":"ACCEPT","protocol":"TCP","ports":"443"}'
                fi
        fi
        rule_icmp='{"addresses":{"ipv4":["0.0.0.0/0"]},"action":"ACCEPT","protocol":"ICMP"}'
        ruleset=""
        if ( [ "${rule_secure_port_udp}" != "" ] )
        then
                ruleset="${rule_secure_port_udp},"
        fi

        if ( [ "${rule_build_machine}" != "" ] )
        then
                ruleset="${ruleset}${rule_build_machine},"
        fi

        if ( [ "${rule_build_machine_ssl}" != "" ] )
        then
                ruleset="${ruleset}${rule_build_machine_ssl},"
        fi

        ruleset="${ruleset}${rule_secure_port_tcp},${rule_vpc_ssh},${rule_icmp}${firewall_rules}"
fi

if ( [ "`/bin/echo ${firewall_name} | /bin/grep "adt-webserver"`" != "" ] )
then
        firewall_rules="`linode_firewall_rules "${firewall_name}" "${webserver_firewall_ports}"`"

        if ( [ "${all_dns_proxy_ips}" = "" ] )
        then
                if ( [ "${NO_REVERSE_PROXIES}" = "0" ] )
                then
                        rule_secure_port_tcp='{"addresses":{"ipv4":["0.0.0.0/0"]},"action":"ACCEPT","protocol":"TCP","ports":"'${secure_port}'"}'
                else
                        rule_secure_port_tcp='{"addresses":{"ipv4":["'${VPC_IP_RANGE}'"]},"action":"ACCEPT","protocol":"TCP","ports":"'${secure_port}'"}'
                fi
        else
                if  ( [ "${NO_REVERSE_PROXIES}" = "0" ] )
                then
                        rule_secure_port_tcp='{"addresses":{"ipv4":['${all_dns_proxy_ips}']},"action":"ACCEPT","protocol":"TCP","ports":"'${secure_port}'"}'
                else
                        rule_secure_port_tcp='{"addresses":{"ipv4":["'${VPC_IP_RANGE}'"]},"action":"ACCEPT","protocol":"TCP","ports":"'${secure_port}'"}'
                fi
        fi

        rule_vpc_ssh='{"addresses":{"ipv4":["'${VPC_IP_RANGE}'"]},"action":"ACCEPT","protocol":"TCP","ports":"'${SSH_PORT}'"}'

        rule_build_machine=""
        rule_build_machine_ssl=""
        if ( [ "${BUILD_MACHINE_VPC}" = "0" ] )
        then
                rule_build_machine='{"addresses":{"ipv4":["'${build_machine_ip}/32'"]},"action":"ACCEPT","protocol":"TCP","ports":"'${SSH_PORT}'"}'
                if ( [ "${NO_REVERSE_PROXIES}" = "0" ] )
                then
                        rule_build_machine_ssl='{"addresses":{"ipv4":["'${build_machine_ip}/32'"]},"action":"ACCEPT","protocol":"TCP","ports":"443"}'
                fi
        fi
        rule_icmp='{"addresses":{"ipv4":["0.0.0.0/0"]},"action":"ACCEPT","protocol":"ICMP"}'

        if ( [ "${rule_build_machine}" != "" ] )
        then
                ruleset="${ruleset}${rule_build_machine},"
        fi

        if ( [ "${rule_build_machine_ssl}" != "" ] )
        then
                ruleset="${ruleset}${rule_build_machine_ssl},"
        fi

        ruleset="${ruleset}${rule_secure_port_tcp},${rule_vpc_ssh},${rule_icmp}${firewall_rules}"

fi

if ( [ "`/bin/echo ${firewall_name} | /bin/grep "adt-database"`" != "" ] )
then
        firewall_rules="`linode_firewall_rules "${firewall_name}" "${database_firewall_ports}"`"
        rule_vpc_ssh='{"addresses":{"ipv4":["'${VPC_IP_RANGE}'"]},"action":"ACCEPT","protocol":"TCP","ports":"'${SSH_PORT}'"}'
        rule_vpc_db='{"addresses":{"ipv4":["'${VPC_IP_RANGE}'"]},"action":"ACCEPT","protocol":"TCP","ports":"'${DB_PORT}'"}'
        rule_icmp='{"addresses":{"ipv4":["0.0.0.0/0"]},"action":"ACCEPT","protocol":"ICMP"}'

        rule_build_machine=""
        if ( [ "${BUILD_MACHINE_VPC}" = "0" ] )
        then
                rule_build_machine='{"addresses":{"ipv4":["'${build_machine_ip}/32'"]},"action":"ACCEPT","protocol":"TCP","ports":"'${SSH_PORT}'"}'
        fi

        ruleset=""
        if ( [ "${rule_build_machine}" != "" ] )
        then
                ruleset="${rule_build_machine},"
        fi

        ruleset="${ruleset}${rule_vpc_ssh},${rule_vpc_db},${rule_icmp}${firewall_rules}"
fi

ruleset='['${ruleset}']'

firewall_id="`/usr/local/bin/linode-cli --json firewalls list | /usr/bin/jq -r '.[] | select (.label | contains ("'${firewall_name}'")) |  select (.label | endswith ("'-${BUILD_IDENTIFIER}'")).id'`"

if ( [ "${firewall_id}" = "" ] )
then
        firewall_id="`/usr/local/bin/linode-cli firewalls create --json --label "${firewall_name}-${BUILD_IDENTIFIER}" --rules.inbound_policy DROP   --rules.outbound_policy ACCEPT | /usr/bin/jq -r '.[].id'`"
else
        /usr/local/bin/linode-cli firewalls rules-update --inbound '[]' --outbound '[]' --inbound_policy DROP --outbound_policy ACCEPT ${firewall_id}
fi

/usr/local/bin/linode-cli firewalls rules-update  --inbound ${ruleset} ${firewall_id}

if ( [ "$?" = "0" ] )
then
        /bin/echo "ADT_FIREWALL_ID:${firewall_id}"
fi
