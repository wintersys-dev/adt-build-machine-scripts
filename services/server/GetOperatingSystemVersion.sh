#!/bin/sh
###################################################################################
# @file        GetOperatingSystemVersion.sh
# @brief       Translates generic OS labels into provider-specific image marketplace slugs.
# @author      Peter Winter
# @date        13/07/2021
# @version     1.0
#
# @details     This script maps a normalized distribution family name and major version
#              number to the exact image identification string or image query pattern 
#              expected by the targeted hosting platform's API (DigitalOcean, Exoscale, 
#              Linode, or Vultr).
#
# @param       $1  [Required] The target cloud host infrastructure platform slug.
# @param       $2  [Required] The requested base operating system family name (e.g., ubuntu, debian).
# @param       $3  [Required] The specific release version identifier string.
#
# @env         BUILD_HOME  Path to the framework core root layout directory.
#
# @exit        0  Success: A matching image string was resolved and printed to stdout.
# @exit        1  Failure: Invalid arguments or an unhandled provider configuration.
#
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
####################################################################################
#set -x
set -e

cloudhost="${1}"
buildos="${2}"
buildos_version="${3}"

BUILD_HOME="$(/bin/cat /home/buildhome.dat)"

if ( [ "${cloudhost}" = "digitalocean" ] )
then
	if ( [ "${buildos}" = "ubuntu" ] )
	then
		buildos_version="$(/bin/echo ${buildos_version} | /bin/sed 's/\./-/g')"
		/bin/echo "ubuntu-${buildos_version}-x64"
	elif ( [ "${buildos}" = "debian" ] )
	then
		/bin/echo "debian-${buildos_version}-x64"
	fi
fi

if ( [ "${cloudhost}" = "exoscale" ] )
then
	if ( [ "${buildos}" = "ubuntu" ] )
	then
		/bin/echo "Linux Ubuntu ${buildos_version} LTS 64-bit"
	elif ( [ "${buildos}" = "debian" ] )
	then
		os_name="$(${BUILD_HOME}/helpers/services/GetOsName.sh | /bin/sed -e "s/\b\(.\)/\u\1/g")"
		#At the current time (2025), 14 and 15 are here for future proofing not for actual use
		if ( [ "${buildos_version}" = "12" ] )
		then
			/bin/echo "Linux Debian ${buildos_version} (${os_name}) 64-bit"
		elif ( [ "${buildos_version}" = "13" ] )
		then
			/bin/echo "Linux Debian ${buildos_version} (${os_name}) 64-bit"
		elif ( [ "${buildos_version}" = "14" ] )
		then
			/bin/echo "Linux Debian ${buildos_version} (${os_name}) 64-bit"
		elif ( [ "${buildos_version}" = "15" ] )
		then
			/bin/echo "Linux Debian ${buildos_version} (${os_name}) 64-bit"
		fi
	fi
fi

if ( [ "${cloudhost}" = "linode" ] )
then
	if ( [ "${buildos}" = "ubuntu" ] )
	then
		/bin/echo "linode/ubuntu${buildos_version}"
	elif ( [ "${buildos}" = "debian" ] )
	then
		/bin/echo "linode/debian${buildos_version}"
	fi
fi

if ( [ "${cloudhost}" = "vultr" ] )
then
	if ( [ "${buildos}" = "ubuntu" ] )
	then
		/bin/echo "Ubuntu ${buildos_version} LTS x64"
	elif ( [ "${buildos}" = "debian" ] )
	then
		/bin/echo "Debian ${buildos_version} x64"
	fi
fi




