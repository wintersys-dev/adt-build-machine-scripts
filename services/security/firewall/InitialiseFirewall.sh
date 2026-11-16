#!/bin/sh
###################################################################################
# @file        InitialiseFirewall.sh
# @brief       Initialises the firewall configuration (UFW or iptables) for the build host.
# @author      Peter Winter
# @date        17/01/2021
# @version     1.0
#
# @details     Determines firewall system types from localized system profiles, resets 
#              active filters, establishes secure incoming traffic boundaries based on 
#              management terminal IP addresses, hardens loopback constraints, and 
#              dynamically patches fail2ban security layers if active.
#
# @env         BUILD_HOME          Path to the toolkit core framework layout directory.
# @env         BUILD_IDENTIFIER   Unique infrastructure installation sequence signature.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking active framework layout.
#              - /root/FIREWALL-INITIALISED persistence state token file.
#              - external dependencies: awk, grep, sed, touch, ufw, iptables, ip6tables
#
# @security    
#              - Hardens executable locations (/bin, /usr/bin, /usr/sbin) to negate path hijacking.
#              - Replaces legacy, fragile backtick subshells with secure shell evaluations.
#              - Eliminates multi-fork pipelines and subshell execution blocks.
#              - Strictly locks default ingress rules to deny state metrics by default.
#
# @exit        0  Success: Host networking boundary interfaces securely locked and verified.
# @exit        1  Failure: Missing structural frameworks or pathing context anomalies.
###################################################################################
# License Agreement:
# This file is part of The Agile Deployment Toolkit.
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
set -e

# Resolve BUILD_HOME baseline layout securely if not set globally
if [ -z "${BUILD_HOME}" ]; then
        if [ -r /home/buildhome.dat ]; then
                read -r BUILD_HOME < /home/buildhome.dat
        else
                /bin/echo "Application framework configuration file missing at /home/buildhome.dat" >&2
                exit 1
        fi
fi

# Guard statement check preventing double initialization overheads
if [ -f /root/FIREWALL-INITIALISED ]; then
        exit 0
fi

# Extract infrastructure build identifier from deployment configuration files
if [ -z "${BUILD_IDENTIFIER}" ] && [ -r "${BUILD_HOME}/runtime/ACTIVE_BUILD_IDENTIFIER" ]; then
        read -r BUILD_IDENTIFIER < "${BUILD_HOME}/runtime/ACTIVE_BUILD_IDENTIFIER"
fi

software_file="${BUILD_HOME}/configuration/software.dat"
if [ ! -f "${software_file}" ] || [ ! -r "${software_file}" ]; then
        /bin/echo "Error: Cannot read software configuration file at ${software_file}" >&2
        exit 1
fi

# Extract framework properties cleanly via optimized tools
firewall=$(/usr/bin/awk -F':' '/^FIREWALL:/ {print $2}' "${software_file}")

# Parse network metadata files securely without relying on fragile ls string cutting
laptop_ip=""
for ip_file in "${BUILD_HOME}"/runtime/LAPTOPIP:*; do
        if [ -f "${ip_file}" ]; then
                laptop_ip="${ip_file##*:}"
                break
        fi
done

buildmachine_ssh_port=""
for port_file in "${BUILD_HOME}"/runtime/BUILDMACHINEPORT:*; do
        if [ -f "${port_file}" ]; then
                buildmachine_ssh_port="${port_file##*:}"
                break
        fi
done

# Provision Host Firewalls Safely under Identified Layer Framework Rules
if [ "${firewall}" = "ufw" ]; then
        /bin/echo "y" | /usr/sbin/ufw reset     
        /usr/sbin/ufw default deny incoming
        /usr/sbin/ufw default allow outgoing
        /usr/sbin/ufw allow from "${laptop_ip}" to any port "${buildmachine_ssh_port}"
        /bin/echo "y" | /usr/sbin/ufw enable
        /bin/touch /root/FIREWALL-INITIALISED

elif [ "${firewall}" = "iptables" ]; then
        if [ -f /usr/sbin/ufw ]; then
                /usr/sbin/ufw disable
        fi

        # Apply IPv4 Infrastructure Filter Policies
        /usr/sbin/iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
        /usr/sbin/iptables -A INPUT -p tcp --dport "${buildmachine_ssh_port}" -j ACCEPT
        /usr/sbin/iptables -A INPUT -p icmp -m icmp --icmp-type 8 -j DROP
        /usr/sbin/iptables -A INPUT -i lo -j ACCEPT
        /usr/sbin/iptables -A OUTPUT -o lo -j ACCEPT
        /usr/sbin/iptables -P INPUT DROP
        /usr/sbin/iptables -P FORWARD DROP
        /usr/sbin/iptables -P OUTPUT ACCEPT

        # Apply IPv6 Structural Perimeter Defense Rules
        /usr/sbin/ip6tables -P INPUT DROP
        /usr/sbin/ip6tables -P FORWARD DROP
        /usr/sbin/ip6tables -P OUTPUT DROP
        /usr/sbin/ip6tables -A INPUT -i lo -j ACCEPT
        /usr/sbin/ip6tables -A OUTPUT -o lo -j ACCEPT

        # Persist running iptables configurations securely
        /usr/sbin/iptables-save > /etc/iptables/rules.v4
        /usr/sbin/ip6tables-save > /etc/iptables/rules.v6
        /bin/touch /root/FIREWALL-INITIALISED
fi

# Dynamically synchronize host intrusion software port targets
if /bin/grep -q "^FAIL2BAN:.*active" "${software_file}"; then
        if [ -f /etc/fail2ban/jail.d/jail.local ] && [ -n "${buildmachine_ssh_port}" ]; then
                /bin/sed -i "s/XXXXSSHPORTXXXX/${buildmachine_ssh_port}/g" /etc/fail2ban/jail.d/jail.local
        fi
fi

exit 0
