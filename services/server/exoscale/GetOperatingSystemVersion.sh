


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
