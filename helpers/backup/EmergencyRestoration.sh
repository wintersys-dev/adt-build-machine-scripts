BUILD_HOME="`/bin/cat /home/buildhome.dat`"

periodicities="hourly, daily, weekly, monthly, bimonthly"
/bin/echo "Please enter the periodicity of the backup you want to restore, one of ${periodicities}"

read periodicity

while ( [ "`/bin/echo ${periodicities} | /bin/grep ${periodicity}`" = "" ] )
do
        /bin/echo "That's not a valid perodicity please enter a periodicity of ${periodicities}"
        read periodicity
done


archives="`${BUILD_HOME}/services/datastore/operations/ListFromDatastore.sh "backup" "." ${periodicity} | /bin/grep "ARCHIVE" | /bin/sed 's/.*ARCHIVE/ARCHIVE/g'`"

/bin/echo "${archives}"

/bin/echo "Above are the available archives that you can restore from"
/bin/echo "Please type exactly the name of the archive you want to restore as it appears above, for example 'ARCHIVE.2026-07-07-16hr'"

read archive

while ( [ "`/bin/echo ${archives} | /bin/grep ${archive}`" = "" ] )
do
        /bin/echo "That's not a valid archive please enter an archive of ${archives}"
        read archive
done

/bin/touch /tmp/ACTIVATE_RESTORATION

/bin/echo "Do you want this to be a distributed or local restoration?"
/bin/echo "Please enter one of 'local' or 'distributed'"
read mode

while ( [ "`/bin/echo 'local distributed' | /bin/grep ${mode}`" = "" ] )
do
        /bin/echo "That's not a valid archive please enter an mode of local or distributed"
        read mode
done

${BUILD_HOME}/services/datastore/operations/PutToDatastore.sh "config" "/tmp/ACTIVATE_RESTORATION" "" "${mode}" "no"
