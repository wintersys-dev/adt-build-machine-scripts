#!/bin/sh

BUILD_HOME="`/bin/cat /home/buildhome.dat`"
WEBSITE_URL="`${BUILD_HOME}/helpers/services/GetVariableValue.sh WEBSITE_URL`"
website_identifier="`/bin/echo ${WEBSITE_URL} | /usr/bin/awk -F'.' '{print $2}'`"

periodicities="hourly, daily, weekly, monthly, bimonthly"
/bin/echo "Please enter the periodicity of the backup you want to restore, one of ${periodicities}"

read periodicity

while ( [ "`/bin/echo ${periodicities} | /bin/grep ${periodicity}`" = "" ] )
do
        /bin/echo "That's not a valid perodicity please enter a periodicity of ${periodicities}"
        read periodicity
done


archives="`${BUILD_HOME}/services/datastore/operations/ListFromDatastore.sh "backup" "root" ${periodicity} | /bin/grep "ARCHIVE" | /bin/sed 's/.*ARCHIVE/ARCHIVE/g'`"
archives="`/bin/echo ${archives} | /usr/bin/tr '\n' ' '`"
/bin/echo "${archives}"

/bin/echo "Above are the available archives that you can restore from"
/bin/echo "Please copy and paste the list of archives that you want to delete as they appear above, for example 'ARCHIVE.2026-07-07-16hr ARCHIVE.2026-07-07-10hr''"

read archives

/bin/echo "Please enter one of 'local' or 'distributed'"
read mode

while ( [ "`/bin/echo 'local distributed' | /bin/grep ${mode}`" = "" ] )
do
        /bin/echo "That's not a valid archive please enter an mode of local or distributed"
        read mode
done

/bin/echo "Are you sure you want to delete these archives (y|Y) : ${archives}"
read response

if ( [ "${response}" != "y" ] && [ "${response}" != "Y" ] )
then
        /bin/echo "OK...exiting"
        exit
fi

for archive in ${archives}
do
        ${BUILD_HOME}/services/datastore/operations/DeleteFromDatastore.sh "backup-web" "applicationsourcecode.tar.gz.${archive}" "${mode}" "${periodicity}" "local"
        ${BUILD_HOME}/services/datastore/operations/DeleteFromDatastore.sh "backup-db" "${website_identifier}-DB-backup.tar.gz.${archive}" "${mode}" "${periodicity}" "local"
done
