

# Input validation
if [ -z "${1}" ] || [ -z "${2}" ]
then
        status "Error: Buildos and buildos_version arguments are required."
        status "Usage: $0 <buildos> <buildos_version>"
        exit 1
fi

if ( [ "${buildos}" = "ubuntu" ] )
then
  /bin/echo "Linux Ubuntu ${buildos_version} LTS 64-bit"
elif ( [ "${buildos}" = "debian" ] )
then
  os_name="$(${BUILD_HOME}/helpers/services/GetOsName.sh | /bin/sed -e "s/\b\(.\)/\u\1/g")"
  if ( [ "${buildos_version}" = "13" ] )
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
