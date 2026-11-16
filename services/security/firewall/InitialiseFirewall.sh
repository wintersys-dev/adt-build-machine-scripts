#!/bin/sh
#: Name:        InitialiseFirewall.sh
#: Purpose:     Initialises the host firewall configuration (UFW or iptables) for the build machine.
#: Author:      Peter Winter
#: Date:        16/11/2026
#: Version:     1.0
#:
#: Usage:       InitialiseFirewall.sh
#:              InitialiseFirewall.sh [-h|--help]
#:
#: Parameters:
#:   None
#:
#: Environment:
#:   BUILD_HOME       Resolved automatically from /home/buildhome.dat if unset
#:   BUILD_IDENTIFIER Resolved from ${BUILD_HOME}/runtime/ACTIVE_BUILD_IDENTIFIER if unset
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - ${BUILD_HOME}/configuration/software.dat
#:   - /root/FIREWALL-INITIALISED
#:   - LogStatusMessages.sh
#:   - External binaries: cat, echo, grep, cut, awk, sed, touch, ufw, iptables, ip6tables, iptables-save, ip6tables-save
#:
#: Exit Codes:
#:   0          Host firewall initialised and persisted successfully (or already initialised)
#:   1          Missing configuration files, missing runtime network metadata, or unsupported firewall type
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

# Resolve the toolkit root directory from the system tracking file if not already set
if [ -z "${BUILD_HOME}" ]
then
        if [ -r /home/buildhome.dat ]
        then
                BUILD_HOME="$(/bin/cat /home/buildhome.dat)"
        else
                /bin/echo "Application root configuration file missing at /home/buildhome.dat" >&2
                exit 1
        fi
fi

# Route status log entries to the centralized logging utility
status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}" 2>/dev/null
}

# Guard check to prevent duplicate firewall initialisation
if [ -f /root/FIREWALL-INITIALISED ]
then
        exit 0
fi

# Extract active build identifier from runtime tracking file if unset
if [ -z "${BUILD_IDENTIFIER}" ] && [ -r "${BUILD_HOME}/runtime/ACTIVE_BUILD_IDENTIFIER" ]
then
        read -r BUILD_IDENTIFIER < "${BUILD_HOME}/runtime/ACTIVE_BUILD_IDENTIFIER"
fi

# Validate existence and readability of software configuration file
software_file="${BUILD_HOME}/configuration/software.dat"

if [ ! -f "${software_file}" ] || [ ! -r "${software_file}" ]
then
        status "Error: Cannot read software configuration file at ${software_file}"
        exit 1
fi

# Extract configured host firewall engine
firewall="$(/usr/bin/awk -F':' '/^FIREWALL:/ {print $2}' "${software_file}")"

if [ -z "${firewall}" ]
then
        status "Error: FIREWALL is not configured in ${software_file}"
        exit 1
fi

# Resolve management laptop IP and build machine SSH port from runtime metadata files
laptop_ip=""
for ip_file in "${BUILD_HOME}"/runtime/LAPTOPIP:*
do
        if [ -f "${ip_file}" ]
        then
                laptop_ip="${ip_file##*:}"
                break
        fi
done

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
        status "Error: Failed to resolve build machine SSH port from ${BUILD_HOME}/runtime/BUILDMACHINEPORT:*"
        exit 1
fi

if [ "${firewall}" = "ufw" ] && [ -z "${laptop_ip}" ]
then
        status "Error: Failed to resolve management laptop IP from ${BUILD_HOME}/runtime/LAPTOPIP:*"
        exit 1
fi

# Provision host firewall rules according to the configured firewall engine
case "${firewall}" in
        ufw)
                /bin/echo "y" | /usr/sbin/ufw reset
                /usr/sbin/ufw default deny incoming
                /usr/sbin/ufw default allow outgoing
                /usr/sbin/ufw allow from "${laptop_ip}" to any port "${buildmachine_ssh_port}"
                /bin/echo "y" | /usr/sbin/ufw enable
                /bin/touch /root/FIREWALL-INITIALISED
                status "Success! UFW host firewall initialised."
                ;;
        iptables)
                if [ -x /usr/sbin/ufw ]
                then
                        /usr/sbin/ufw disable
                fi

                # Apply IPv4 filter policies
                /usr/sbin/iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
                /usr/sbin/iptables -A INPUT -p tcp --dport "${buildmachine_ssh_port}" -j ACCEPT
                /usr/sbin/iptables -A INPUT -p icmp -m icmp --icmp-type 8 -j DROP
                /usr/sbin/iptables -A INPUT -i lo -j ACCEPT
                /usr/sbin/iptables -A OUTPUT -o lo -j ACCEPT
                /usr/sbin/iptables -P INPUT DROP
                /usr/sbin/iptables -P FORWARD DROP
                /usr/sbin/iptables -P OUTPUT ACCEPT

                # Apply IPv6 perimeter defense rules
                /usr/sbin/ip6tables -P INPUT DROP
                /usr/sbin/ip6tables -P FORWARD DROP
                /usr/sbin/ip6tables -P OUTPUT DROP
                /usr/sbin/ip6tables -A INPUT -i lo -j ACCEPT
                /usr/sbin/ip6tables -A OUTPUT -o lo -j ACCEPT

                # Persist running iptables rules
                /usr/sbin/iptables-save > /etc/iptables/rules.v4
                /usr/sbin/ip6tables-save > /etc/iptables/rules.v6
                /bin/touch /root/FIREWALL-INITIALISED
                status "Success! iptables host firewall initialised."
                ;;
        *)
                status "Error: Unsupported FIREWALL value (${firewall}) in ${software_file}"
                exit 1
                ;;
esac

# Synchronize Fail2Ban SSH port placeholder if Fail2Ban is active
if /usr/bin/grep -q '^FAIL2BAN:.*active' "${software_file}"
then
        if [ -f /etc/fail2ban/jail.d/jail.local ]
        then
                /bin/sed -i "s/XXXXSSHPORTXXXX/${buildmachine_ssh_port}/g" /etc/fail2ban/jail.d/jail.local
        fi
fi

exit 0

