BUILD_HOME="`/bin/cat /home/buildhome.dat`"

if ( [ ! -d ${BUILD_HOME}/runtime/linode-env ] )
then
        /bin/mkdir -p ${BUILD_HOME}/runtime/linode-env 
fi

apt update
apt install python3 python3-venv python3-pip -y

python3 -m venv ${BUILD_HOME}/runtime/linode-env

. ${BUILD_HOME}/runtime/linode-env/bin/activate

pip install --upgrade pip
pip install linode-cli
pip install boto3
