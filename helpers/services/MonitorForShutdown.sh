

while ( [ 1 ] )
do
  /bin/sleep 1
  if ( [ -f /tmp/SHUTDOWN_INITIATED ] )
  then
      /bin/shutdown -r now
  fi
done
