BUILD_HOME_FILE="/home/buildhome.dat"


if ( [ ! -f "${BUILD_HOME_FILE}" ] || [ ! -r "${BUILD_HOME_FILE}" ] )
then
    echo "Error: Cannot read build home data file at $BUILD_HOME_FILE" >&2
    exit 1
fi

BUILD_HOME="`/bin/cat "$BUILD_HOME_FILE"`"

if ( [ "$BUILD_HOME" = "" ] )
then
    echo "Error: BUILD_HOME variable is empty." >&2
    exit 1
fi

/bin/echo "${BUILD_HOME}"
