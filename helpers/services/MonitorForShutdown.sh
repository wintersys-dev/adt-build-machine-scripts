
count="0"
while ( [ "${count}" -lt "60" ] )
do
  /bin/sleep 1
  count="`/usr/bin/expr ${count} + 1`"
  if ( [ -f /tmp/SHUTDOWN_INITIATED ] )
  then
      /bin/shutdown -r now
  fi
done
