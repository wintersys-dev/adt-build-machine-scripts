BUILD_HOME="`/bin/cat /home/buildhome.dat`"
DB_NAME="`${BUILD_HOME}/helpers/services/GetVariableValue.sh DB_NAME`"

if ( [ "`/bin/echo ${DB_NAME} | /bin/grep 'restored'`" = "" ] )
then
        restoration_no="1"
else
        existing_restoration_no="`/bin/echo ${DB_NAME} | /usr/bin/awk -F'-' '{print $NF}'`"
        restoration_no="`/usr/bin/expr ${existing_restoration_no} + 1`"
fi

/bin/grep -rlZ "${DB_NAME}" ${BUILD_HOME}/runtime | /usr/bin/xargs -0 /bin/sed -i "s/${DB_NAME}.*/${DB_NAME}_restored-${restoration_no}/g"

command='/bin/grep -rlZ "'${DB_NAME}'" '${HOME}' | /usr/bin/xargs -0 /bin/sed -i "s/'${DB_NAME}'.*/'${DB_NAME}'_restored-${restoration_no}/g"'
${HOME}/utilities/remote/ConnectToDatabaseVPS.sh "${SUDO} ${command}"
command='/bin/grep -rlZ "'${DB_NAME}'" '/var/www/html' | /usr/bin/xargs -0 /bin/sed -i "s/'${DB_NAME}'.*/'${DB_NAME}'_restored-${restoration_no}/g"'
${HOME}/utilities/remote/ConnectToDatabaseVPS.sh "${SUDO} ${command}"

${HOME}/utilities/remote/ConnectToDatabaseVPS.sh "${SUDO} ${HOME}/application/InstallApplication.sh"
${HOME}/utilities/remote/ConnectToDatabaseVPS.sh "${SUDO} ${HOME}/application/configuration/InitialiseApplicationConfiguration.sh"

command='/bin/grep -rlZ "'${DB_NAME}'" '${HOME}' | /usr/bin/xargs -0 /bin/sed -i "s/'${DB_NAME}'.*/'${DB_NAME}'_restored-${restoration_no}/g"'
${HOME}/utilities/remote/ConnectToDatabaseVPS.sh "${SUDO} ${command}"
${HOME}/utilities/remote/ConnectToDatabaseVPS.sh "${SUDO} ${HOME}/application/db/InstallApplicationDB.sh"
