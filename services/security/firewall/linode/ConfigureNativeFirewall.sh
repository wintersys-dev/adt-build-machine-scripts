#!/bin/sh
#: Name:        ConfigureNativeFirewall.sh
#: Purpose:     Constructs role-specific Linode firewall JSON rulesets and applies them via the active orchestration tool.
#: Author:      Peter Winter
#: Date:        16/11/2026
#: Version:     1.0
#:
#: Usage:       ConfigureNativeFirewall.sh "<firewall_name>"
#:              ConfigureNativeFirewall.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] The architectural role name (e.g. adt-authenticator, adt-webserver)
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - ${BUILD_HOME}/configuration/firewall.dat
#:   - ${BUILD_HOME}/configuration/software.dat
#:   - LogStatusMessages.sh
#:   - GetVariableValue.sh
#:   - GetBuildMachineIP.sh
#:   - GetProxyDNSIPs.sh
#:   - Provider orchestration scripts (get_firewall_id.sh, create_firewall.sh, reset_firewall.sh, update_firewall.sh)
#:   - External binaries: cat, echo, grep, cut, sed, awk, ipcalc, jq
#:
#: Exit Codes:
#:   0          Native firewall provisioned/updated and ADT_FIREWALL_ID:<id> emitted on stdout
#:   1          Missing arguments, unreadable config files, invalid JSON ruleset, or downstream execution failure
###################################################################################
# License Agreement:
# This file is part of The Wintersys Agile Deployment Toolkit.
# The Agile Deployment Toolkit is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# The Agile Deployment Toolkit is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with The Agile Deployment Toolkit.  If not, see <http://gnu.org>.
####################################################################################

# Exit immediately if any command exits with a non-zero status
set -e

# Render self-extracting help documentation when -h or --help is supplied
if [ "${1}" = "-h" ] || [ "${1}" = "--help" ]
then
        /usr/bin/grep '^#:' "$0" | /usr/bin/cut -c 4-
        exit 0
fi

# Resolve the toolkit root directory from the system tracking file
if [ -r /home/buildhome.dat ]
then
        BUILD_HOME="$(/bin/cat /home/buildhome.dat)"
else
        /bin/echo "Application root configuration file missing at /home/buildhome.dat" >&2
        exit 1
fi

# Route status log entries to the centralized logging utility
status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}" 2>/dev/null
}

# Parse pipe-delimited port definitions (<port>|ipv4|<proto>|<cidr>) from firewall.dat into Linode JSON rules
linode_firewall_rules()
{
        f_ports="${1}"
        f_rules=""

        for firewall_port_token in ${f_ports}
        do
                ip_family="$(/bin/echo "${firewall_port_token}" | /usr/bin/awk -F'|' '{print $2}')"
                if [ "${ip_family}" = "ipv4" ]
                then
                        port="$(/bin/echo "${firewall_port_token}" | /usr/bin/awk -F'|' '{print $1}')"
                        ip_address="$(/bin/echo "${firewall_port_token}" | /usr/bin/awk -F'|' '{print $4}')"

                        # Validate CIDR/IP syntax via ipcalc before generating JSON rules
                        if [ -n "${port}" ] && [ -n "${ip_address}" ] && ! /usr/bin/ipcalc "${ip_address}" 2>/dev/null | /usr/bin/grep -q "INVALID"
                        then
                                new_entry='{"addresses":{"ipv4":["'"${ip_address}"'"]},"action":"ACCEPT","protocol":"TCP","ports":"'"${port}"'"},{"addresses":{"ipv4":["'"${ip_address}"'"]},"action":"ACCEPT","protocol":"UDP","ports":"'"${port}"'"}'
                                if [ -n "${f_rules}" ]
                                then
                                        f_rules="${f_rules},${new_entry}"
                                else
                                        f_rules="${new_entry}"
                                fi
                        fi
                fi
        done

        /bin/echo "${f_rules}"
}

# Validate required positional arguments
if [ -z "${1}" ]
then
        status "Error: 1 argument is required."
        status "Usage: $0 <firewall_name>"
        exit 1
fi

firewall_name="${1}"
# Retrieve deployment context variables and build machine IP address
CLOUDHOST="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" CLOUDHOST)"
BUILD_IDENTIFIER="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" BUILD_IDENTIFIER)"
BUILD_MACHINE_VPC="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" BUILD_MACHINE_VPC)"
SSH_PORT="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" SSH_PORT)"
DB_PORT="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DB_PORT)"
VPC_IP_RANGE="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" VPC_IP_RANGE)"
NO_REVERSE_PROXIES="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" NO_REVERSE_PROXIES)"
AUTHENTICATOR_TYPE="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" AUTHENTICATOR_TYPE)"
build_machine_ip="$("${BUILD_HOME}/helpers/services/GetBuildMachineIP.sh")"
full_firewall_name="${firewall_name}-${BUILD_IDENTIFIER}"

if [ -z "${CLOUDHOST}" ] || [ -z "${BUILD_IDENTIFIER}" ] || [ -z "${SSH_PORT}" ] || [ -z "${VPC_IP_RANGE}" ]
then
        status "Error: Failed to fetch required network or deployment context variables."
        exit 1
fi

# Load role-specific custom port definitions from firewall.dat if present
authenticator_firewall_ports=""
autoscaler_firewall_ports=""
reverseproxy_firewall_ports=""
webserver_firewall_ports=""
database_firewall_ports=""

firewall_dat="${BUILD_HOME}/configuration/firewall.dat"
if [ -r "${firewall_dat}" ]
then
        authenticator_firewall_ports="$(/usr/bin/awk -F':' '/^AUTHENTICATORPORTS/ {print $2}' "${firewall_dat}")"
        autoscaler_firewall_ports="$(/usr/bin/awk -F':' '/^AUTOSCALERPORTS/ {print $2}' "${firewall_dat}")"
        reverseproxy_firewall_ports="$(/usr/bin/awk -F':' '/^REVERSEPROXYPORTS/ {print $2}' "${firewall_dat}")"
        webserver_firewall_ports="$(/usr/bin/awk -F':' '/^WEBSERVERPORTS/ {print $2}' "${firewall_dat}")"
        database_firewall_ports="$(/usr/bin/awk -F':' '/^DATABASEPORTS/ {print $2}' "${firewall_dat}")"
fi

# Fetch DNS proxy IP ranges (e.g. Cloudflare) for ingress HTTPS allowlisting
if [ "${firewall_name}" = "adt-authenticator" ]
then
        all_dns_proxy_ips="$("${BUILD_HOME}/services/dns/GetProxyDNSIPs.sh" "yes")"
else
        all_dns_proxy_ips="$("${BUILD_HOME}/services/dns/GetProxyDNSIPs.sh" "no")"
fi

# Initialize individual rule segments
firewall_rules=""
rule_vpc_ssh=""
rule_vpc_db=""
rule_vpc_ssl=""
rule_ssl=""
rule_wireguard=""
rule_build_machine=""
rule_build_machine_ssl=""
rule_icmp=""

# Build ingress rules tailored to the target infrastructure role
case "${firewall_name}" in
        *adt-authenticator*)
                firewall_rules="$(linode_firewall_rules "${authenticator_firewall_ports}")"
                rule_vpc_ssh='{"addresses":{"ipv4":["'"${VPC_IP_RANGE}"'"]},"action":"ACCEPT","protocol":"TCP","ports":"'"${SSH_PORT}"'"}'
                rule_icmp='{"addresses":{"ipv4":["0.0.0.0/0"]},"action":"ACCEPT","protocol":"ICMP"}'

                if [ -r "${firewall_dat}" ] && /usr/bin/grep "^AUTHENTICATORPORTS:" "${firewall_dat}" | /usr/bin/grep -q "cloudflare" && [ -n "${all_dns_proxy_ips}" ]
                then
                        rule_ssl='{"addresses":{"ipv4":['"${all_dns_proxy_ips}"']},"action":"ACCEPT","protocol":"TCP","ports":"443"},{"addresses":{"ipv4":['"${all_dns_proxy_ips}"']},"action":"ACCEPT","protocol":"UDP","ports":"443"}'
                fi

                if [ "${BUILD_MACHINE_VPC}" = "0" ]
                then
                        rule_build_machine='{"addresses":{"ipv4":["'"${build_machine_ip}/32"'"]},"action":"ACCEPT","protocol":"TCP","ports":"'"${SSH_PORT}"'"}'
                fi
                ;;
        *adt-autoscaler*)
                firewall_rules="$(linode_firewall_rules "${autoscaler_firewall_ports}")"
                rule_vpc_ssh='{"addresses":{"ipv4":["'"${VPC_IP_RANGE}"'"]},"action":"ACCEPT","protocol":"TCP","ports":"'"${SSH_PORT}"'"}'
                rule_icmp='{"addresses":{"ipv4":["0.0.0.0/0"]},"action":"ACCEPT","protocol":"ICMP"}'

                if [ "${BUILD_MACHINE_VPC}" = "0" ]
                then
                        rule_build_machine='{"addresses":{"ipv4":["'"${build_machine_ip}/32"'"]},"action":"ACCEPT","protocol":"TCP","ports":"'"${SSH_PORT}"'"}'
                fi
                ;;
        *adt-reverseproxy*)
                firewall_rules="$(linode_firewall_rules "${reverseproxy_firewall_ports}")"

                if [ "${AUTHENTICATOR_TYPE}" = "wire-guard" ]
                then
                        secure_port="$((SSH_PORT + 1))"
                        rule_wireguard='{"addresses":{"ipv4":["0.0.0.0/0"]},"action":"ACCEPT","protocol":"UDP","ports":"'"${secure_port}"'"},{"addresses":{"ipv4":["0.0.0.0/0"]},"action":"ACCEPT","protocol":"TCP","ports":"'"${secure_port}"'"}'
                else
                        if [ -r "${firewall_dat}" ] && /usr/bin/grep "^REVERSEPROXYPORTS:" "${firewall_dat}" | /usr/bin/grep -q "cloudflare" && [ -n "${all_dns_proxy_ips}" ]
                        then
                                rule_ssl='{"addresses":{"ipv4":['"${all_dns_proxy_ips}"']},"action":"ACCEPT","protocol":"TCP","ports":"443"},{"addresses":{"ipv4":['"${all_dns_proxy_ips}"']},"action":"ACCEPT","protocol":"UDP","ports":"443"}'
                        fi
                fi

                rule_vpc_ssl='{"addresses":{"ipv4":["'"${VPC_IP_RANGE}"'"]},"action":"ACCEPT","protocol":"TCP","ports":"443"}'
                rule_vpc_ssh='{"addresses":{"ipv4":["'"${VPC_IP_RANGE}"'"]},"action":"ACCEPT","protocol":"TCP","ports":"'"${SSH_PORT}"'"}'

                if [ "${BUILD_MACHINE_VPC}" = "0" ]
                then
                        rule_build_machine='{"addresses":{"ipv4":["'"${build_machine_ip}/32"'"]},"action":"ACCEPT","protocol":"TCP","ports":"'"${SSH_PORT}"'"}'
                        if [ "${NO_REVERSE_PROXIES}" != "0" ]
                        then
                                rule_build_machine_ssl='{"addresses":{"ipv4":["'"${build_machine_ip}/32"'"]},"action":"ACCEPT","protocol":"TCP","ports":"443"}'
                        fi
                fi
                rule_icmp='{"addresses":{"ipv4":["0.0.0.0/0"]},"action":"ACCEPT","protocol":"ICMP"}'
                ;;
        *adt-webserver*)
                firewall_rules="$(linode_firewall_rules "${webserver_firewall_ports}")"
                rule_vpc_ssl='{"addresses":{"ipv4":["'"${VPC_IP_RANGE}"'"]},"action":"ACCEPT","protocol":"TCP","ports":"443"}'

                if [ "${NO_REVERSE_PROXIES}" = "0" ]
                then
                        if [ -r "${firewall_dat}" ] && /usr/bin/grep "^WEBSERVERPORTS:" "${firewall_dat}" | /usr/bin/grep -q "cloudflare" && [ -n "${all_dns_proxy_ips}" ]
                        then
                                rule_ssl='{"addresses":{"ipv4":['"${all_dns_proxy_ips}"']},"action":"ACCEPT","protocol":"TCP","ports":"443"},{"addresses":{"ipv4":['"${all_dns_proxy_ips}"']},"action":"ACCEPT","protocol":"UDP","ports":"443"}'
                        fi
                fi

                rule_vpc_ssh='{"addresses":{"ipv4":["'"${VPC_IP_RANGE}"'"]},"action":"ACCEPT","protocol":"TCP","ports":"'"${SSH_PORT}"'"}'

                if [ "${BUILD_MACHINE_VPC}" = "0" ]
                then
                        rule_build_machine='{"addresses":{"ipv4":["'"${build_machine_ip}/32"'"]},"action":"ACCEPT","protocol":"TCP","ports":"'"${SSH_PORT}"'"}'
                        if [ "${NO_REVERSE_PROXIES}" = "0" ]
                        then
                                rule_build_machine_ssl='{"addresses":{"ipv4":["'"${build_machine_ip}/32"'"]},"action":"ACCEPT","protocol":"TCP","ports":"443"}'
                        fi
                fi
                rule_icmp='{"addresses":{"ipv4":["0.0.0.0/0"]},"action":"ACCEPT","protocol":"ICMP"}'
                ;;
        *adt-database*)
                firewall_rules="$(linode_firewall_rules "${database_firewall_ports}")"
                rule_vpc_ssh='{"addresses":{"ipv4":["'"${VPC_IP_RANGE}"'"]},"action":"ACCEPT","protocol":"TCP","ports":"'"${SSH_PORT}"'"}'
                rule_vpc_db='{"addresses":{"ipv4":["'"${VPC_IP_RANGE}"'"]},"action":"ACCEPT","protocol":"TCP","ports":"'"${DB_PORT}"'"}'
                rule_icmp='{"addresses":{"ipv4":["0.0.0.0/0"]},"action":"ACCEPT","protocol":"ICMP"}'

                if [ "${BUILD_MACHINE_VPC}" = "0" ]
                then
                        rule_build_machine='{"addresses":{"ipv4":["'"${build_machine_ip}/32"'"]},"action":"ACCEPT","protocol":"TCP","ports":"'"${SSH_PORT}"'"}'
                fi
                ;;
        *)
                status "Error: Unrecognised firewall role name (${firewall_name})."
                exit 1
                ;;
esac
# Combine all populated rule fragments into a valid JSON array
raw_rules=""
for segment in "${rule_build_machine}" "${rule_build_machine_ssl}" "${rule_wireguard}" "${rule_vpc_ssh}" "${rule_vpc_db}" "${rule_vpc_ssl}" "${rule_ssl}" "${rule_icmp}" "${firewall_rules}"
do
        if [ -n "${segment}" ]
        then
                if [ -n "${raw_rules}" ]
                then
                        raw_rules="${raw_rules},${segment}"
                else
                        raw_rules="${segment}"
                fi
        fi
done

ruleset="$(/bin/echo "[${raw_rules}]" | /usr/bin/jq -c '.' 2>/dev/null || true)"

if [ -z "${ruleset}" ]
then
        status "Error: Assembled firewall ruleset produced invalid JSON."
        exit 1
fi

# Verify software configuration file and resolve active orchestration tool (api or cli)
software_file="${BUILD_HOME}/configuration/software.dat"
if [ ! -f "${software_file}" ] || [ ! -r "${software_file}" ]
then
        status "Error: Cannot read software configuration file at ${software_file}"
        exit 1
fi

orchestration_tool="$(/usr/bin/awk -F':' '/^ORCHESTRATION_TOOL:/ {print $NF}' "${software_file}")"

if [ -z "${orchestration_tool}" ]
then
        status "Error: ORCHESTRATION_TOOL not found in ${software_file}"
        exit 1
fi

tool_dir="${BUILD_HOME}/services/security/firewall/${CLOUDHOST}/${orchestration_tool}"

# Retrieve existing firewall ID or provision a new firewall instance
set +e
jq_response="$("${tool_dir}/list_firewalls.sh" "${firewall_name}")"
get_status="$?"
set -e

if [ "${get_status}" -ne 0 ]
then
        status "Error: Failed to query existing firewall ID for ${firewall_name}."
        exit 1
else
        firewall_id="$(/bin/echo "${jq_response}" | /usr/bin/jq -r --arg lbl "${full_firewall_name}" '.[] | select(.label == $lbl) | .id // empty')"

        if [ -n "${firewall_id}" ] && [ "${firewall_id}" != "null" ]
        then
                status "Success: got firewall id for pre-existing firewall: ${firewall_id}"
        fi
fi

if [ -z "${firewall_id}" ]
then
        set +e
        jq_response="$("${tool_dir}/create_firewall.sh" "${firewall_name}")"
        create_status="$?"
        set -e

        if [ "${create_status}" -ne 0 ] 
        then
                status "Error: Failed to create native firewall for ${firewall_name}."
                exit 1
        else
                firewall_id="$(/bin/echo "${jq_response}" | /usr/bin/jq -r --arg lbl "${full_firewall_name}" '(if type == "array" then .[] else . end) | select(.label == $lbl) | .id // empty')"

                if [ -n "${firewall_id}" ] && [ "${firewall_id}" != "null" ]
                then
                        /bin/echo "${firewall_id}"
                fi
        fi
        status "Success! Created Linode firewall (ID: ${firewall_id})."
else
        status "Success! Linode firewall available and ready (ID: ${firewall_id})."
fi

# Reset firewall rules to baseline defaults before applying the updated ruleset
set +e
"${tool_dir}/reset_firewall.sh" "${firewall_id}"
reset_status="$?"
set -e

if [ "${reset_status}" -ne 0 ]
then
        status "Error: Failed to reset firewall ${firewall_id}."
        exit 1
fi

# Apply the computed inbound JSON ruleset to the target firewall
set +e
"${tool_dir}/update_firewall.sh" "${firewall_id}" "${ruleset}"
update_status="$?"
set -e

if [ "${update_status}" -ne 0 ]
then
        status "Error: Failed to update firewall ${firewall_id} with new ruleset."
        exit 1
fi

# Emit the resulting firewall ID in standard key-value format
if [ -n "${firewall_id}" ]
then
        /bin/echo "ADT_FIREWALL_ID:${firewall_id}"
fi

exit 0



