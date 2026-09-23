


		bespoke_application_installed="`/usr/bin/ssh -q -p ${SSH_PORT} -i ${BUILD_KEY} ${OPTIONS_WS} ${SERVER_USER}@${ws_active_ip} "/usr/bin/test -f /home/${SERVER_USER}/runtime/BESPOKE_APPLICATION_INSTALLED && /bin/echo 'BESPOKE_APPLICATION_INSTALLED'"`" >&3
