#!/bin/zsh
# courtesy of @BigMacAdmin

dialog --message "Wait for Another Process" --button1disabled &
PID=$!

# Do something. We are just looping through sending commands to the log file
# But you could do anything here
i=0
time_left=10
until [[ $i = 10 ]]; do
  /bin/echo "Message: Waiting for $time_left more seconds" >> /var/tmp/dialog.log
  /bin/sleep 1
  i=$((i+1))
  time_left=$((time_left - 1))
done

# reenable button
echo "message: Press OK when ready" >> /var/tmp/dialog.log
echo "button1: enable" >> /var/tmp/dialog.log

while true; do
  if kill -0 $PID > /dev/null 2>&1; then
    echo "$(timestamp) Waiting for user to press OK"
  else
    break
  fi
  sleep 1
done

/bin/echo "button1: enable" >> /var/tmp/dialog.log

case $? in
  0)
  dialog --message "Pressed OK"
  # Button 1 processing here
  ;;
  2)
  dialog --message "Pressed Cancel Button (button 2)"
  # Button 2 processing here
  ;;
  3)
  echo "Pressed Info Button (button 3)"
  # Button 3 processing here
  ;;
  4)
  echo "Timer Expired"
  # Timer ran out code here
  ;;
  20)
  echo "Do Not Disturb is enabled"
  # Do Not Disturb Processing here
  ;;
  201)
  echo "Image resource not found"
  ;;
  202)
  echo "Image for icon not found"
  ;;
  *)
  dialog --message "Dialog closed"
  ;;
esac
