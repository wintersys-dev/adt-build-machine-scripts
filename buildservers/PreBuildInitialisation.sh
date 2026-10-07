. ${BUILD_HOME}/runtime/ansible-env/bin/activate

/usr/bin/wget https://raw.githubusercontent.com/linode/ansible_linode/main/requirements.txt -O ${BUILD_HOME}/runtime/ansible-env/requirements.txt

if [ $? -eq 0 ] 
then
        cat << 'EOF' > "${BUILD_HOME}/runtime/ansible-env/requirements.txt"
linode_api4>=5.46.1
polling==0.3.2
ansible-specdoc>=0.0.20
EOF
fi

pip install --upgrade -r ${BUILD_HOME}/runtime/ansible-env/requirements.txt

echo "1234" > ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/.ansible_vault_pass
chown root:root ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/.ansible_vault_pass
chmod 600 ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/.ansible_vault_pass
