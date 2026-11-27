#!/bin/sh
####################################################################################
# Description: This script will work out what Application we are deploying, if any.
# There are several scenarios. The 1st is that it is a virgin install of an Application
# in which case we can discern elsewhere which Application it is. We can discern our
# application type based on a baseline or on a datastore backup depending on what
# type of deployment is being made.
# Date: 07-11/2016
# Author: Peter Winter
####################################################################################
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
#####################################################################################
#####################################################################################
#set -x

status () {
        ${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

BUILD_HOME="`/bin/cat /home/buildhome.dat`"
WEBSITE_NAME="`${BUILD_HOME}/helpers/services/GetVariableValue.sh WEBSITE_NAME`"
BUILD_ARCHIVE_CHOICE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILD_ARCHIVE_CHOICE`"
APPLICATION_REPOSITORY_PROVIDER="`${BUILD_HOME}/helpers/services/GetVariableValue.sh APPLICATION_REPOSITORY_PROVIDER`"
APPLICATION_BASELINE_SOURCECODE_REPOSITORY="`${BUILD_HOME}/helpers/services/GetVariableValue.sh APPLICATION_BASELINE_SOURCECODE_REPOSITORY`"
BASELINE_DB_REPOSITORY="`${BUILD_HOME}/helpers/services/GetVariableValue.sh BASELINE_DB_REPOSITORY`"

#If we are a basseline check then we expect to be able to find the baseline repository available
if ( [ "${BUILD_ARCHIVE_CHOICE}" = "baseline" ] )
then
        application=$(${BUILD_HOME}/services/git/GetFileContentsFromRepository.sh "${APPLICATION_BASELINE_SOURCECODE_REPOSITORY}" "dba.dat")

        if ( [ "${application}" = "" ] )
        then
                status "Sorry, could not find the baseline repository for you application when I was expecting to, will have to exit..."
                exit 1
        else
                status "I have found potentially usable ${application} webroot baseline sourcecode in your ${APPLICATION_REPOSITORY_PROVIDER} application repository"
        fi

        applicationDB=$(${BUILD_HOME}/services/git/GetFileContentsFromRepository.sh "${BASELINE_DB_REPOSITORY}" "applicationDB.sql" | /bin/grep 'zzzz' | /bin/grep 'CREATE TABLE')

        if ( [ "${applicationDB}" = "" ] )
        then
                applicationDB=$(${BUILD_HOME}/services/git/GetFileContentsFromRepository.sh "${BASELINE_DB_REPOSITORY}" "applicationDB.psql" | /bin/grep 'zzzz' | /bin/grep 'CREATE TABLE')
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

        status "I have found potentially usable ${db_type} database baseline sourcecode in your ${APPLICATION_REPOSITORY_PROVIDER} database repository"

        webroot_db_type=$(${BUILD_HOME}/services/git/GetFileContentsFromRepository.sh "${APPLICATION_BASELINE_SOURCECODE_REPOSITORY}" "dbe.dat")

        if printf '%s\n' "${webroot_db_type}" | /bin/grep -qw -- "Maria" || printf '%s\n' "${webroot_db_type}" | /bin/grep -qw -- "MySQL" 
        then
                webroot_db_type="mysql"
        elif printf '%s\n' "${webroot_db_type}" | /bin/grep -qw -- "Postgres" 
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
                status "The build assets have been verified suitable for the build to proceed"
        fi
fi

if ( [ "${BUILD_ARCHIVE_CHOICE}" != "baseline" ] && [ "${BUILD_ARCHIVE_CHOICE}" != "virgin" ] )
then
        application="$(${BUILD_HOME}/services/datastore/operations/ObtainFileContentsFromDatastore.sh "backup-webroot" "applicationsourcecode.tar.gz" "hourly" | /usr/bin/tar -xzOf - ./dba.dat)"
        if ( [ "${application}" = "" ] )
        then
                status "Sorry, could not find the application type from a webroot backup in your datastore when I was expecting to, will have to exit..."
                exit 1
        else
                status "I have found potentially usable ${application} webroot backup in your provided application datastore"
        fi

        set -x

        applicationDB="$(${BUILD_HOME}/services/datastore/operations/ObtainFileContentsFromDatastore.sh "backup-db" "${WEBSITE_NAME}-DB-backup.tar.gz" "hourly" | /usr/bin/tar -xzOf - | /usr/bin/awk 'BEGIN{IGNORECASE=1} /MySQL database dump complete/,0' | /bin/grep 'zzzz' | /bin/grep 'CREATE TABLE')"
        if ( [ "${applicationDB}" = "" ] )
        then
                applicationDB="$(${BUILD_HOME}/services/datastore/operations/ObtainFileContentsFromDatastore.sh "backup-db" "${WEBSITE_NAME}-DB-backup.tar.gz" "hourly" | /usr/bin/tar -xzOf - | /usr/bin/awk 'BEGIN{IGNORECASE=1} /PostgreSQL database dump complete/,0' | /bin/grep 'zzzz' | /bin/grep 'CREATE TABLE')" 
                if [ "${applicationDB}" = "" ]
                then
                        status "Sorry, could not find the baseline repository for you application when I was expecting to, will have to exit..."
                        exit 1
                else
                        db_type="postgres"
                fi
                if [ "${applicationDB}" = "" ]
                then
                        status "Sorry, could not find the application database in your datastore when I was expecting to, will have to exit..."
                        exit 1
                else
                        db_type="postgres"
                fi
        else
                db_type="mysql"
        fi

        status "I have found potentially usable ${db_type} database baseline sourcecode in your ${APPLICATION_REPOSITORY_PROVIDER} database repository"
        status "The build assets have been verified suitable for the build to proceed"

        webroot_db_type="$(${BUILD_HOME}/services/datastore/operations/ObtainFileContentsFromDatastore.sh "backup-webroot" "applicationsourcecode.tar.gz" "hourly" | /usr/bin/tar -xzOf - ./dbe.dat)"

        if printf '%s\n' "${webroot_db_type}" | /bin/grep -qw -- "Maria" || printf '%s\n' "${webroot_db_type}" | /bin/grep -qw -- "MySQL"
        then
                webroot_db_type="mysql"
        elif printf '%s\n' "${webroot_db_type}" | /bin/grep -qw -- "Postgres"
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
                status "The database type that the webroot backup expects ${webroot_db_type} matches with what the database backup expects ${db_type}"
        fi
fi
