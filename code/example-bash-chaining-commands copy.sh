#!/bin/zsh

dialog --message "Basic Chaining Commands" --button2text "Cancel"

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
