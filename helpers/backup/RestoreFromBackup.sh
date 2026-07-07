BUILD_HOME="`/bin/cat /home/buildhome.dat`"
DB_NAME="`${BUILD_HOME}/helpers/services/GetVariableValue.sh DB_NAME`"

if ( [ "`/bin/echo ${DB_NAME} | /bin/grep 'restored'`" = "" ] )
then
        restoration_no="1"
else
        existing_restoration_no="`/bin/echo ${DB_NAME} | /usr/bin/awk -F'-' '{print $NF}'`"
        restoration_no="`/usr/bin/expr ${existing_restoration_no} + 1`"
fi

echo ${restoration_no}
