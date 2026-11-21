if ( [ "${BUILD_ARCHIVE_CHOICE}" = "baseline" ] )
then
        gitrepo="0"

        application=$(${BUILD_HOME}/services/git/GetFileContentsFromRepository.sh "${APPLICATION_BASELINE_SOURCECODE_REPOSITORY}" "dba.dat")

        if ( [ "${application}" = "" ] )
        then
                status "Sorry, could not find the baseline repository for you application when I was expecting to, will have to exit..."
                exit 1
        else
                status "I have found potentially usable ${application} webroot baseline sourcecode in your git repo."
                gitrepo="1"
        fi

        gitrepo="1"

        applicationDB=$(${BUILD_HOME}/services/git/GetFileContentsFromRepository.sh "${BASELINE_DB_REPOSITORY}" "applicationDB.sql" | /bin/grep 'zzzz')

        if ( [ "${applicationDB}" = "" ] )
        then
                applicationDB=$(${BUILD_HOME}/services/git/GetFileContentsFromRepository.sh "${BASELINE_DB_REPOSITORY}" "applicationDB.psql" | /bin/grep 'zzzz')
                if [ "${applicationDB}" = "" ] 
                then
                        status "Sorry, could not find the baseline repository for you application when I was expecting to, will have to exit..."
                        exit 1
                else 
                        db_type="postgres"
                fi
        else
                db_type="mysql"
        fi

        status "I have found potentially usable ${db_type} database baseline sourcecode in your git repo."
        status "The build assets have been verified suitable for the build to proceed"

        webroot_db_type=$(${BUILD_HOME}/services/git/GetFileContentsFromRepository.sh "${APPLICATION_BASELINE_SOURCECODE_REPOSITORY}" "dbe.dat")

        if printf '%s\n' "${webroot_db_type}" | grep -qw -- "Maria" || printf '%s\n' "${webroot_db_type}" | grep -qw -- "MySQL" 
        then
                webroot_db_type="mysql"
        elif printf '%s\n' "${webroot_db_type}" | grep -qw -- "Postgres" 
        then
                webroot_db_type="postgres"
        else
                status "Could not establish application database type from repository sourcecode"
                exit 1
        fi

        if ( [ "${db_type}" != "${webroot_db_type}" ] )
        then
                status "Mismatch detected between the database type the application webroot thinks it is and what the application database repository thinks it is"
                status "The application webroot is expecting ${db_type} and the webroot database is expecting ${webroot_db_type})"
                exit 1
        else
                status "The database type that the webroot repository ${APPLICATION_BASELINE_SOURCECODE_REPOSITORY} expects matches with what the database repository ${BASELINE_DB_REPOSITORY} expects"
        fi
fi
