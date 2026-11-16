#!/bin/sh
#: Name:        AdjustBuildMachineFirewall.sh
#: Purpose:     Synchronises authorised management IP addresses from S3 datastore to SSH and host firewalls.
#: Author:      Peter Winter
#: Date:        16/11/2026
#: Version:     1.0
#:
#: Usage:       AdjustBuildMachineFirewall.sh
#:              AdjustBuildMachineFirewall.sh [-h|--help]
#:
#: Parameters:
#:   None
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - /root/buildmachine_user.dat
#:   - ${BUILD_HOME}/configuration/software.dat
#:   - LogStatusMessages.sh
#:   - GetBuildMachineIP.sh
#:   - GetServerName.sh
#:   - GetVariableValue.sh
#:   - RunServiceCommand.sh
#:   - Datastore operation scripts (MountDatastore.sh, ListDatastore.sh, ListFromDatastore.sh, GetFromDatastore.sh, PutToDatastore.sh, DeleteFromDatastore.sh)
#:   - External binaries: cat, echo, grep, cut, sed, awk, tr, touch, mkdir, rm, mv, find, sort, whois, yes, ufw, iptables, ip6tables, iptables-save, ip6tables-save
#:
#: Exit Codes:
#:   0          Firewall rules and SSH AllowUsers synchronised successfully (or bypassed on laptop)
#:   1          Missing configuration files, missing runtime metadata, or execution error
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
#set -x
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

# Validate required runtime metadata files
if [ ! -r "${BUILD_HOME}/runtime/ACTIVE_BUILD_IDENTIFIER" ] || [ ! -r "${BUILD_HOME}/runtime/BUILD_MACHINE_CLOUDHOST" ] || [ ! -r /root/buildmachine_user.dat ]
then
        status "Error: Missing required build identifier, cloudhost, or buildmachine user metadata files."
        exit 1
fi

BUILD_IDENTIFIER="$(/bin/cat "${BUILD_HOME}/runtime/ACTIVE_BUILD_IDENTIFIER")"
CLOUDHOST="$(/bin/cat "${BUILD_HOME}/runtime/BUILD_MACHINE_CLOUDHOST")"
BUILDMACHINE_USER="$(/bin/cat /root/buildmachine_user.dat)"

if [ -z "${BUILD_IDENTIFIER}" ] || [ -z "${CLOUDHOST}" ] || [ -z "${BUILDMACHINE_USER}" ]
then
        status "Error: One or more core build context variables resolved empty."
        exit 1
fi

# Resolve build machine IP address and register server name
ip="$("${BUILD_HOME}/helpers/services/GetBuildMachineIP.sh")"

if [ -z "${ip}" ]
then
        status "Error: Failed to resolve build machine IP address."
        exit 1
fi

"${BUILD_HOME}/services/server/GetServerName.sh" "${ip}"

# Detect whether the build is executing on a local laptop rather than a cloud host
on_laptop="1"
if [ -d "${BUILD_HOME}/templatedconfigurations/templates" ]
then
        whois_output="$(/usr/bin/whois "${ip}" 2>/dev/null || true)"
        for template_path in "${BUILD_HOME}"/templatedconfigurations/templates/*
        do
                if [ -e "${template_path}" ]
                then
                        cloud_provider="${template_path##*/}"
                        if /bin/echo "${whois_output}" | /usr/bin/grep -q "${cloud_provider}"
                        then
                                on_laptop="0"
                                break
                        fi
                fi
        done
fi

if [ "${on_laptop}" = "1" ]
then
        /bin/touch "${BUILD_HOME}/runtime/BUILDING_ON_LAPTOP"
        exit 0
fi
# Resolve or initialize the firewall bucket specifier based on the build machine IP
additional_specifier=""
for bucket_file in /root/FIREWALL-BUCKET:*
do
        if [ -f "${bucket_file}" ]
        then
                additional_specifier="${bucket_file##*:}"
                break
        fi
done

if [ -z "${additional_specifier}" ]
then
        additional_specifier="$(/bin/echo "${ip}" | /bin/sed 's/\./-/g')"
        /bin/touch "/root/FIREWALL-BUCKET:${additional_specifier}"
fi

# Mount authentication datastore and fetch pending firewall events
runtime_dir="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}"
ips_dir="${runtime_dir}/ips"
auth_ips_file="${ips_dir}/authorised-ips.dat"

if [ ! -d "${runtime_dir}" ]
then
        /bin/mkdir -p "${runtime_dir}"
fi

"${BUILD_HOME}/services/datastore/operations/MountDatastore.sh" "auth" "local" "${additional_specifier}"

if [ -n "$("${BUILD_HOME}/services/datastore/operations/ListFromDatastore.sh" "auth" "FIREWALL-EVENT" "${additional_specifier}")" ]
then
        "${BUILD_HOME}/services/datastore/operations/GetFromDatastore.sh" "auth" "FIREWALL-EVENT" "${runtime_dir}" "${additional_specifier}"
fi

# Process firewall update when a FIREWALL-EVENT or PRIME_FIREWALL marker is present
if [ -f "${runtime_dir}/FIREWALL-EVENT" ] || [ -f "${runtime_dir}/PRIME_FIREWALL" ]
then
        if [ -f "${runtime_dir}/FIREWALL-EVENT" ]
        then
                /bin/rm -f "${runtime_dir}/FIREWALL-EVENT"
        fi

        if [ -f "${runtime_dir}/PRIME_FIREWALL" ]
        then
                /bin/rm -f "${runtime_dir}/PRIME_FIREWALL"
        fi

        if [ -f "${auth_ips_file}" ] && [ -z "$(/usr/bin/find "${auth_ips_file}" -mmin +1)" ]
        then
                if [ -n "$("${BUILD_HOME}/services/datastore/operations/ListFromDatastore.sh" "auth" "FIREWALL-EVENT" "${additional_specifier}")" ]
                then
                        "${BUILD_HOME}/services/datastore/operations/DeleteFromDatastore.sh" "auth" "FIREWALL-EVENT" "local" "${additional_specifier}"
                fi

                if [ -n "$("${BUILD_HOME}/services/datastore/operations/ListFromDatastore.sh" "auth" "authorised-ips.dat" "${additional_specifier}")" ]
                then
                        if [ ! -d "${ips_dir}" ]
                        then
                                /bin/mkdir -p "${ips_dir}"
                        fi
                        "${BUILD_HOME}/services/datastore/operations/GetFromDatastore.sh" "auth" "authorised-ips.dat" "${ips_dir}" "${additional_specifier}"
                fi
        fi

        # Resolve management laptop IP from runtime tracking file if not already set
        if [ -z "${laptop_ip}" ]
        then
                for ip_file in "${BUILD_HOME}"/runtime/LAPTOPIP:*
                do
                        if [ -f "${ip_file}" ]
                        then
                                laptop_ip="${ip_file##*:}"
                                break
                        fi
                done
        fi

        # Append laptop IP to authorised-ips.dat and sync to datastore unless bypassed
        if [ -n "${laptop_ip}" ] && [ "${laptop_ip}" != "BYPASS" ]
        then
                if [ ! -d "${ips_dir}" ]
                then
                        /bin/mkdir -p "${ips_dir}"
                fi

                /bin/echo "${laptop_ip}" >> "${auth_ips_file}"
                /usr/bin/sort -u "${auth_ips_file}" > "${auth_ips_file}.$$"
                /bin/mv "${auth_ips_file}.$$" "${auth_ips_file}"

                count="0"
                while [ -z "$("${BUILD_HOME}/services/datastore/operations/ListDatastore.sh" "auth" "${additional_specifier}")" ] && [ "${count}" -lt 5 ]
                do
                        "${BUILD_HOME}/services/datastore/operations/MountDatastore.sh" "auth" "local" "${additional_specifier}"
                        count="$((count + 1))"
                done

                if [ ! -f "${auth_ips_file}" ]
                then
                        /bin/echo "${laptop_ip}" > "${auth_ips_file}"
                fi

                "${BUILD_HOME}/services/datastore/operations/PutToDatastore.sh" "auth" "${auth_ips_file}" "root" "local" "no" "${additional_specifier}"
        fi
        # Apply SSH AllowUsers and host firewall ingress rules for all authorised IPs
        if [ -r "${auth_ips_file}" ]
        then
                /usr/bin/sort -u "${auth_ips_file}" > "${auth_ips_file}.$$"
                /bin/mv "${auth_ips_file}.$$" "${auth_ips_file}"
                ips="$(/bin/tr '\n' ' ' < "${auth_ips_file}")"
        else
                ips=""
        fi

        if [ -n "${ips}" ]
        then
                updated="0"

                for auth_ip in ${ips}
                do
                        if [ ! -f /etc/ssh/sshd_config.d/99-hardening.conf ] || ! /usr/bin/grep -q "${auth_ip}" /etc/ssh/sshd_config.d/99-hardening.conf
                        then
                                /bin/echo "AllowUsers ${BUILDMACHINE_USER}@${auth_ip}" >> /etc/ssh/sshd_config.d/99-hardening.conf
                                updated="1"
                        fi
                done

                if [ "${updated}" = "1" ]
                then
                        /bin/sh "${BUILD_HOME}/helpers/services/RunServiceCommand.sh" ssh restart
                fi

                software_file="${BUILD_HOME}/configuration/software.dat"
                if [ ! -r "${software_file}" ]
                then
                        status "Error: Cannot read software configuration file at ${software_file}"
                        exit 1
                fi

                firewall="$(/usr/bin/awk -F':' '/^FIREWALL:/ {print $2}' "${software_file}")"

                buildmachine_ssh_port=""
                for port_file in "${BUILD_HOME}"/runtime/BUILDMACHINEPORT:*
                do
                        if [ -f "${port_file}" ]
                        then
                                buildmachine_ssh_port="${port_file##*:}"
                                break
                        fi
                done

                if [ -z "${buildmachine_ssh_port}" ]
                then
                        buildmachine_ssh_port="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" SSH_PORT)"
                fi

                # Rebuild host firewall rules to permit authorised IP addresses
                case "${firewall}" in
                        ufw)
                                /usr/bin/yes | /usr/sbin/ufw reset
                                /usr/sbin/ufw default deny incoming
                                /usr/sbin/ufw default allow outgoing

                                if [ -z "${buildmachine_ssh_port}" ]
                                then
                                        for auth_ip in ${ips}
                                        do
                                                /usr/sbin/ufw allow from "${auth_ip}"
                                        done
                                else
                                        for auth_ip in ${ips}
                                        do
                                                /usr/sbin/ufw allow from "${auth_ip}" proto tcp to any port "${buildmachine_ssh_port}"
                                        done
                                fi

                                /usr/bin/yes | /usr/sbin/ufw enable
                                ;;
                        iptables)
                                if [ -z "${buildmachine_ssh_port}" ]
                                then
                                        status "Error: Failed to resolve build machine SSH port for iptables configuration."
                                        exit 1
                                fi

                                comma_ips="$(/bin/echo "${ips}" | /bin/sed 's/ *$//; s/ /,/g')"

                                /usr/sbin/iptables -F
                                /usr/sbin/iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
                                /usr/sbin/iptables -A INPUT -s "${comma_ips}" -p icmp --icmp-type 8 -j ACCEPT
                                /usr/sbin/iptables -A INPUT -p icmp -m icmp --icmp-type 8 -j DROP
                                /usr/sbin/iptables -I INPUT -s "${comma_ips}" -m state --state NEW,RELATED,ESTABLISHED -p tcp --dport "${buildmachine_ssh_port}" -j ACCEPT
                                /usr/sbin/iptables -A INPUT -i lo -j ACCEPT
                                /usr/sbin/iptables -A OUTPUT -o lo -j ACCEPT
                                /usr/sbin/iptables -P INPUT DROP
                                /usr/sbin/iptables -P FORWARD DROP
                                /usr/sbin/iptables -P OUTPUT ACCEPT

                                /usr/sbin/ip6tables -P INPUT DROP
                                /usr/sbin/ip6tables -P FORWARD DROP
                                /usr/sbin/ip6tables -P OUTPUT DROP
                                /usr/sbin/ip6tables -A INPUT -i lo -j ACCEPT
                                /usr/sbin/ip6tables -A OUTPUT -o lo -j ACCEPT

                                /usr/sbin/iptables-save > /etc/iptables/rules.v4
                                /usr/sbin/ip6tables-save > /etc/iptables/rules.v6
                                ;;
                        *)
                                status "Error: Unsupported FIREWALL value (${firewall}) in ${software_file}"
                                exit 1
                                ;;
                esac

                # Prune any stale IP addresses no longer present in authorised-ips.dat
                authorised_ips="$(/bin/cat "${auth_ips_file}")"

                if [ "${firewall}" = "ufw" ]
                then
                        live_ips="$(/usr/sbin/ufw status | /usr/bin/awk '/ALLOW IN/ {print $NF}' | /usr/bin/sort -u)"
                        for live_ip in ${live_ips}
                        do
                                if ! /bin/echo "${authorised_ips}" | /usr/bin/grep -qx "${live_ip}"
                                then
										rule_nos="$(/usr/sbin/ufw status numbered | /usr/bin/grep -E "(^|[[:space:]])${live_ip}([[:space:]]|/|$)" | /usr/bin/sed -n 's/^\[[[:space:]]*\([0-9][0-9]*\)\].*/\1/p' | /usr/bin/sort -rn)"
                                        for rule_no in ${rule_nos}
                                        do
                                                /usr/bin/yes | /usr/sbin/ufw delete "${rule_no}"
                                        done
                                fi
                        done
                elif [ "${firewall}" = "iptables" ]
                then
						live_ips="$(/usr/sbin/iptables --list-rules | /usr/bin/awk '{for (i=1; i<=NF; i++) if ($i == "-s") { sub(/\/32$/, "", $(i+1)); print $(i+1) }}' | /usr/bin/sort -u)"
                        for live_ip in ${live_ips}
                        do
                                if ! /bin/echo "${authorised_ips}" | /usr/bin/grep -qx "${live_ip}"
                                then
                                        /usr/sbin/iptables -D INPUT -s "${live_ip}" -p icmp --icmp-type 8 -j ACCEPT 2>/dev/null || true
                                        /usr/sbin/iptables -D INPUT -s "${live_ip}" -m state --state NEW,RELATED,ESTABLISHED -p tcp --dport "${buildmachine_ssh_port}" -j ACCEPT 2>/dev/null || true
                                fi
                        done
                        /usr/sbin/iptables-save > /etc/iptables/rules.v4
                fi

                status "Success! Build machine firewall and SSH access updated."
        fi
fi

exit 0

