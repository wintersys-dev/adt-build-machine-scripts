set -x

# 1. Create a virtual environment (e.g., named 'ansible-env')
python3 -m venv ansible-env

# 2. Activate the virtual environment
. ansible-env/bin/activate

# 3. Upgrade pip and install the requirements securely
pip install --upgrade pip
pip install --upgrade -r https://raw.githubusercontent.com/linode/ansible_linode/main/requirements.txt

pip install linode_api4

pip list


BUILD_HOME="/home/agile-deployer/adt-build-machine-scripts"

linode_api_token="`/bin/cat /root/.config/linode-cli | /bin/grep '^token' | /usr/bin/awk '{print $NF}'`"


ansible-playbook -i ${BUILD_HOME}/services/server/ansible/linode/inventory.ini ${BUILD_HOME}/services/server/ansible/linode/4.yaml -e "ansible_python_interpreter=/home/agile-deployer/adt-build-machine-scripts/services/server/ansible-env/bin/python linode_api_token=${linode_api_token}"
