if ( [ ! -f  ./AdjustScaling.sh ] )
then
	/bin/echo "Sorry, this script has to be run from the ${BUILD_HOME}/helpers/services subdirectory"
	exit
fi

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

if ( [ "`${BUILD_HOME}/helpers/services/GetVariableValue.sh DEPLOYMENT_MODE`" != "PRODUCTION" ] )
then
	/bin/echo "You are not in PRODUCTION mode, cannot set scaling parameters"
	exit
fi

/bin/echo "Please enter the number of webservers you want to be provisioned and active"
read no_webservers

${BUILD_HOME}/helpers/scaling/TestIfScalingAllowed.sh

