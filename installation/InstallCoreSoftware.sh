#!/bin/sh
######################################################################################################
# Description: This will install all software on the build machine. If you add new software that 
# needs installing you will have to update it here as well. This takes the approach of installing all
# possible software that could be needed even if it is not needed for the current install. 
# Author: Peter Winter
# Date: 17/01/2017
#######################################################################################################
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
# along with The Agile Deployment Toolkit.  If not, see <http://www.gnu.org/licenses/>.
#######################################################################################################
#######################################################################################################
#set -x

status () {
	/bin/echo "${1}" | /usr/bin/tee /dev/fd/3 2>/dev/null
	script_name="`/bin/echo ${0} | /usr/bin/awk -F'/' '{print $NF}'`"
	/bin/echo "${script_name}: ${1}" | /usr/bin/tee -a /dev/fd/4 2>/dev/null
}

BUILD_HOME="`/bin/cat /home/buildhome.dat`"
buildos="${1}"

if ( [ ! -f /root/DATASTORETOOL_INSTALLED ] &&  [ "${buildos}" = "ubuntu" ] )
then
	status "Installing/Updating Datastore tools"
	${BUILD_HOME}/installation/InstallDatastoreTools.sh "ubuntu" 2>&1 >/dev/null
	/bin/touch /root/DATASTORETOOL_INSTALLED
elif ( [ ! -f /root/DATASTORETOOL_INSTALLED ] && [ "${buildos}" = "debian" ] )
then
	status "Installing/Updating Datastore tools"
	${BUILD_HOME}/installation/InstallDatastoreTools.sh "debian" 2>&1 >/dev/null
	/bin/touch /root/DATASTORETOOL_INSTALLED
fi

if ( [ ! -f /root/UPDATEDSOFTWARE ] || [ "`/usr/bin/find ~/UPDATEDSOFTWARE -mmin +1440 -print`" != "" ] )
then
	if ( [ ! -d /root/logs ] )
	then
		/bin/mkdir /root/logs
	fi

	upgrade_log="/root/logs/upgrade_out-`/bin/date | /bin/sed 's/ //g'`"

	if ( [ "`${BUILD_HOME}/helpers/IsHardcoreBuild.sh`" != "1" ] )
	then   
		status "##################################################################################################"
		status "I am about to make software changes on this machine. If you are OK with that, please press <enter>"
		status "##################################################################################################"
		read x
	fi

	status "##################################################################################################################################################"
	status "Checking that the build software is up to date on this machine. Please wait .....This might take a few minutes the first time you run this script"
	status "This is best practice to make sure that all the software is at its latest versions prior to the build process"
	status "A log of the process is available at: ${upgrade_log}"
	status "##################################################################################################################################################"

	if ( [ "`/usr/bin/awk -F= '/^NAME/{print $2}' /etc/os-release | /bin/grep "Ubuntu"`" != "" ] )
	then    
		if ( [ ! -f /root/UPDATEDSOFTWARE ] )
		then
			status "Performing software update....."
			${BUILD_HOME}/installation/RemoveUnattendedUpgrades.sh "ubuntu"  >>${upgrade_log} 2>&1
			${BUILD_HOME}/installation/InitialUpdate.sh "ubuntu"  >>${upgrade_log} 2>&1
		else
			${BUILD_HOME}/installation/RemoveUnattendedUpgrades.sh "ubuntu"  >>${upgrade_log} 2>&1
			${BUILD_HOME}/installation/UpdateAndUpgrade.sh "ubuntu"  >>${upgrade_log} 2>&1
		fi

		status "Installing Firewall"
		${BUILD_HOME}/installation/InstallFirewall.sh "ubuntu" >>${upgrade_log} 2>&1
		status "Initialising Firewall"
		${BUILD_HOME}/services/security/firewall/InitialiseFirewall.sh "ubuntu" >>${upgrade_log} 2>&1
		status "Installing/Updating SysVBanner"
		${BUILD_HOME}/installation/InstallSysVBanner.sh "ubuntu" >>${upgrade_log} 2>&1
		status "Installing/Updating go"
		${BUILD_HOME}/installation/InstallGo.sh "ubuntu" >>${upgrade_log} 2>&1
		status "Installing/Updating curl"
		${BUILD_HOME}/installation/InstallCurl.sh "ubuntu" >>${upgrade_log} 2>&1
		status "Installing/Updating whois"
		${BUILD_HOME}/installation/InstallWhois.sh "ubuntu" >>${upgrade_log} 2>&1
		status "Installing/Updating JQ"
		${BUILD_HOME}/installation/InstallJQ.sh "ubuntu" >>${upgrade_log} 2>&1
		status "Installing/Updating Ruby"
		${BUILD_HOME}/installation/InstallRuby.sh "ubuntu" >>${upgrade_log} 2>&1
		status "Installing/Updating SSHPass"
		${BUILD_HOME}/installation/InstallSSHPass.sh "ubuntu" >>${upgrade_log} 2>&1
		status "Installing/Updating Sudo"
		${BUILD_HOME}/installation/InstallSudo.sh "ubuntu" >>${upgrade_log} 2>&1
		status "Installing/Updating Cron"
		${BUILD_HOME}/installation/InstallCron.sh "ubuntu" >>${upgrade_log} 2>&1 
		status "Installing/Updating Email Utilities"
		${BUILD_HOME}/installation/InstallEmailUtils.sh "ubuntu" >>${upgrade_log} 2>&1 
		status "Installing/Updating Virus Scanner"
		${BUILD_HOME}/installation/InstallVirusScanner.sh "ubuntu" >>${upgrade_log} 2>&1 
		/bin/touch ${BUILD_HOME}/runtime/EXUPDATEDSOFTWARE
	elif ( [ "`/usr/bin/awk -F= '/^NAME/{print $2}' /etc/os-release | /bin/grep "Debian"`" != "" ] )
	then     
		if ( [ ! -f /root/UPDATEDSOFTWARE ] )
		then
			status "Performing software update....."
			${BUILD_HOME}/installation/InitialUpdate.sh "debian"  >>${upgrade_log} 2>&1
		else
			${BUILD_HOME}/installation/UpdateAndUpgrade.sh "debian"  >>${upgrade_log} 2>&1
		fi

		status "Installing Firewall"
		${BUILD_HOME}/installation/InstallFirewall.sh "debian" >>${upgrade_log} 2>&1
		status "Initialising Firewall"
		${BUILD_HOME}/services/security/firewall/InitialiseFirewall.sh "debian" >>${upgrade_log} 2>&1
		status "Installing/Updating SysVBanner"
		${BUILD_HOME}/installation/InstallSysVBanner.sh "debian" >>${upgrade_log} 2>&1
		status "Installing/Updating go"
		${BUILD_HOME}/installation/InstallGo.sh "debian" >>${upgrade_log} 2>&1
		status "Installing/Updating curl"
		${BUILD_HOME}/installation/InstallCurl.sh "debian" >>${upgrade_log} 2>&1
		status "Installing/Updating whois"
		${BUILD_HOME}/installation/InstallWhois.sh "ubuntu" >>${upgrade_log} 2>&1
		status "Installing/Updating JQ"
		${BUILD_HOME}/installation/InstallJQ.sh "debian" >>${upgrade_log} 2>&1
		status "Installing/Updating Ruby"
		${BUILD_HOME}/installation/InstallRuby.sh "debian" >>${upgrade_log} 2>&1
		status "Installing/Updating SSHPass"
		${BUILD_HOME}/installation/InstallSSHPass.sh "debian" >>${upgrade_log} 2>&1
		status "Installing/Updating Sudo"
		${BUILD_HOME}/installation/InstallSudo.sh "debian" >>${upgrade_log} 2>&1
		status "Installing/Updating Cron"
		${BUILD_HOME}/installation/InstallCron.sh "debian" >>${upgrade_log} 2>&1 
		status "Installing/Updating Email Utilities"
		${BUILD_HOME}/installation/InstallEmailUtils.sh "debian" >>${upgrade_log} 2>&1 
		status "Installing/Updating Virus Scanner"
		${BUILD_HOME}/installation/InstallVirusScanner.sh "debian" >>${upgrade_log} 2>&1 
		/bin/touch ${BUILD_HOME}/runtime/EXUPDATEDSOFTWARE
	fi
	/bin/touch /root/UPDATEDSOFTWARE
fi
