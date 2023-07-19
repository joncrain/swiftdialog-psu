#!/bin/zsh

### MDM Enrollment Helper ###
# Version: 0.1.1 beta
#
# Script overview
############################################
# OS Check (is OS < 11)
# System Date Check (is time reset because of drained battery)
# Dialog check (is dialog installed, install if not)
# MDM Server check (does profiles status output contain MDM_SERVER)
# DEP Check (is machine in DEP)
    # ABM Check (If in DEP does cloudConfigRecord match)
# Start the dialogs
############################################

########### Variables ######################
############################################
BANNER_IMAGE="./imgs/banner.png"
DIALOG="/usr/local/bin/dialog"
DIALOG_COMMAND_FILE=$(/usr/bin/mktemp /var/tmp/mdmcheck_dialog.XXX)
DIALOG_LINK="https://github.com/bartreardon/swiftDialog/releases/download/v2.1.0/dialog-2.1.0-4148.pkg"
HELP_LINK="https://confluence.company.com/x/dhoKBQ"
MDM_SERVER="simplemdmer"
DEFAULT_OPTIONS=(
    --moveable
    --ontop
    --ignorednd
    --title none
    --alignment center
    --messagefont "size=16"
    --width 700
    --height 300
    --infobuttontext "More Info"
    --infobuttonaction $HELP_LINK
    --helpmessage "All devices are required to be enrolled in our MDM solution. MDM is used to manage your device for initial setup configuration, for data protection in cases of loss or theft, and for other administrative purposes. \n\n Verify this message at [$HELP_LINK]($HELP_LINK)"
    --commandfile $DIALOG_COMMAND_FILE
)

########### Functions ######################
############################################
write_log () {
    /bin/echo $(/bin/date): \[mdm_check\] $1
}

update_dialog () {
    /bin/echo $1: $2 >> ${DIALOG_COMMAND_FILE}
}

exit_script () {
    /bin/rm $DIALOG_COMMAND_FILE
    exit $1
}

########### Dialog Check ###################
# Check if something else has already called dialog
############################################
# i=0
# while /usr/bin/pgrep Dialog > /dev/null 2>&1 && [ $i -lt 60 ]
# do
#     write_log "Waiting for other dialogs"
#     /bin/sleep 1
#     ((i++))
# done

# if /usr/bin/pgrep Dialog > /dev/null 2>&1; then
#     write_log "Other dialogs are present. Quitting script"
#     exit_script 0
# fi

if [[ -e ${DIALOG_COMMAND_FILE} ]]; then rm ${DIALOG_COMMAND_FILE}; fi

########### Valid OS Check #################
# Check to see if the Mac is reporting itself as running macOS 11
############################################
OLDIFS=$IFS
IFS='.' read osvers_major osvers_minor osvers_dot_version <<< "$(/usr/bin/sw_vers -productVersion)"
IFS=$OLDIFS
if [[ ${osvers_major} -lt 11 ]]; then
    write_log "Must be running macOS 11.0 or later."
    exit 1
fi

########### System Date Check ##############
# We have seen this script trigger when the system date is incorrect
# Macs that have lost all battery will reset to 1976 and could trigger
# an inadvertant enrollment.
############################################
NOW=$(/bin/date +%s)
DATE_CHECK=$(/bin/date -j -f "%b %d %Y %H:%M:%S" "Jan 01 2020 00:00:00" +%s)
if [ ${NOW} -le ${DATE_CHECK} ]; then
    write_log "System time is incorrect."
    exit 1
fi

########### Dialog Install Check ###########
# Double check that dialog is installed
# This is our one requirement for the script
############################################
if test ! -f "${DIALOG}"; then
    write_log "${DIALOG} is not installed. Installing dialog."
    /usr/bin/curl -L $DIALOG_LINK --output /tmp/dialog.pkg
    /usr/sbin/installer -pkg /tmp/dialog.pkg -target /
fi

########### MDM Server Check ###############
# Is the machine currently enrolled in our target mdm
# If we are good here, then we should be good
# We cannot however enroll if it is already enrolled
############################################
enrollment_info=$(/usr/bin/profiles status -type enrollment)
if [[ $enrollment_info ==  *"${MDM_SERVER}"* ]]; then
    write_log "$MDM_SERVER was found."
    # may want to do a branch here to check for validity
    exit 0
elif [[ $enrollment_info ==  *"MDM enrollment: Yes"* ]]; then
    write_log "$MDM_SERVER was not found. Machine is enrolled in previous MDM."
    # exit 0
else
    write_log "$MDM_SERVER was not found. Machine is not enrolled."
fi

########### DEP Check ######################
# Check if machine is in DEP
# returns $DEP true/false
############################################
cloud_config_record="/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound"
config_valid=$(/usr/libexec/PlistBuddy -c "print :'CloudConfigFetchError':'__Success__'" /var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound)
if test ! -f "${cloud_config_record}"; then
    write_log "Machine does not appear to be in DEP"
    DEP=false
elif [[ $config_valid = "false" ]]; then
    write_log "Machine has an issue with DEP"
    DEP=false
else
    write_log "Machine is in DEP"
    DEP=true
fi

########### DEP Workflow ###################
########### ABM Check ######################
# Double check that the MDM record is pointing to the target MDM
# If this is pointing at the old one, it will cause a enrollment
# loop and a bad experience for the end user.
############################################
if test $DEP = true; then
    configuration_url=$(/usr/libexec/PlistBuddy -c "print :'CloudConfigProfile':'ConfigurationURL'" /var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound)
    if [[ $configuration_url != *"${MDM_SERVER}"* ]]; then
        write_log "Target MDM is incorrect. Attempting to update record from Apple"
        if ! /usr/bin/profiles -e | grep -q "${MDM_SERVER}"; then
            write_log "Target MDM is still incorrect. \
${MDM_SERVER} in not in the Cloud Config Profile. \
Configuration URL = ${configuration_url} \
Have you changed the machine in ABM and the MDM?"
            # exit_script 1
        else
            write_log "Found ${MDM_SERVER} in Cloud Config Profile."
        fi
    fi
    write_log "Machine is in DEP and is not enrolled in ${MDM_SERVER}. Displaying notification."

    dialog_options=(
        --bannerimage $BANNER_IMAGE
        --message "## Your computer enrollment needs updating!\n\nPlease click **Send Notification** to begin enrollment."
        --button1text "Send Notification"
    )

    ${DIALOG} "${DEFAULT_OPTIONS[@]}" "${dialog_options[@]}"

    if [ $? -eq 0 ]; then
        write_log "User clicked Send notification. Running profiles renew."
    fi

    /usr/bin/profiles renew -type enrollment

    if [ $? -eq 0 ]; then
        write_log "Profiles renew completed. Displaying enrollment instructions."
    else
        write_log $?
    fi


    dialog_options=(
        --iconsize 500
        --icon /Library/CPE/imgs/dep_enroll.png
        --centericon
        --message "## Notification has been sent\n\n
It is located in the Notification Center in the top right corner of your screen.\n\n
Click on the notification and select **Allow** to finish device management setup."
        --button1text "Continue"
        --button1disabled
    )

    ${DIALOG} "${DEFAULT_OPTIONS[@]}" "${dialog_options[@]}" & /bin/sleep 10

    update_dialog "button1" "enable"
fi

########### Manual Workflow ################
# Machine is not in DEP
# Download profile from Safari and install
# Instructions are split for < macOS 13 and 13+
############################################
# if test $DEP = false; then
#     write_log "Machine is not in DEP. Giving user link to download profile."
#     dialog_options=(
#         --bannerimage $BANNER_IMAGE
#         --message "## Your computer enrollment needs updating!\n\nSelecting continue will open a webpage to download the new enrollment profile.\n\nYou must sign in to Okta to access the download link."
#         --button1text "Continue"
#     )

#     ${DIALOG} "${DEFAULT_OPTIONS[@]}" "${dialog_options[@]}"

#     /usr/bin/open -a Safari http://getmdm.company.com/
#     current_user_name=$(stat -f %Su /dev/console)
#     user_home_folder=$(dscl . -read "/Users/${current_user_name}" NFSHomeDirectory 2> /dev/null | awk '{ print $NF; exit }')
#     profile_file_path="${user_home_folder}/Downloads/SimpleMDM - Company Manual.mobileconfig"

#     i=0
#     until test -f "$profile_file_path";
#     do
#         write_log "Waiting for $profile_file_path"
#         /bin/sleep 1
#         ((i++))
#         if test $i -gt 5; then
#             write_log "User did not download the profile. Exiting."
#             # exit_script 1
#         fi
#     done

#     write_log "Profile was downloaded successfully."

#     /usr/bin/open x-apple.systempreferences:com.apple.preferences.configurationprofiles

#     dialog_options=(
#         --iconsize 500
#         --centericon
#         --button1text "OK"
#         --button1disabled
#     )

#     if [[ ${osvers_major} -gt 12 ]]; then
#         write_log "Running macOS 13.0 or later."
#         dialog_options+=(
#             --message "**Step 1:** Double click the **Company Profile** in **System Settings**\n\n**Step 2:** Select Enroll\n\n**Step 3:** Enter your local admin credentials and select **Enroll**"
#             --iconsize 500 -i /Library/CPE/imgs/ventura_install.png
#         )
#     else
#         write_log "Running macOS version lower than 13.0"
#         dialog_options+=(
#             --message "**Step 1:** Double click the **Company Profile** in **System Preferences**\n\n**Step 2:** Select **Install** and confirm by selecting **Install** again\n\n**Step 3:** Enter your local admin credentials and select **Enroll**"
#             --iconsize 500 -i /Library/CPE/imgs/install.png
#         )
#     fi

#     ${DIALOG} "${DEFAULT_OPTIONS[@]}" "${dialog_options[@]}" & /bin/sleep 5

#     update_dialog "button1" "enable"
# fi

########### Enrollment Check ###############
# Check for the enrollment for 2 minutes
# If not successful, let the user know
############################################
# i=0
# until /usr/bin/profiles status -type enrollment | grep -e "${MDM_SERVER}";
# do
#     if test $i -lt 5; then
#         write_log "Waiting for user to finish instructions."
#         /bin/sleep 1
#         ((i++))
#     else
#         update_dialog "quit"
#         write_log "User did not finish the instructions."
#         /bin/sleep 1
#         # Clear command file or else we will quit again
#         > $DIALOG_COMMAND_FILE
#         dialog_options=(
#             --bannerimage $BANNER_IMAGE
#             --message "## Enrollment was not completed!\n\nWe will remind you soon to complete again.\n\nFor issues, please log a ticket with IT Support"
#             --button1text "Defer"
#         )
#         ${DIALOG} "${DEFAULT_OPTIONS[@]}" "${dialog_options[@]}"
#         exit_script 1
#     fi
# done

########### Success Message ################
# update_dialog "quit"
echo "Test"
/bin/sleep 10
# Clear command file or else we will quit again
# > $DIALOG_COMMAND_FILE
dialog_options=(
    --bannerimage $BANNER_IMAGE
    --message "## Success!\n\nThank you for updating your MDM enrollment."
    --button1text "Quit"
)
${DIALOG} "${DEFAULT_OPTIONS[@]}" "${dialog_options[@]}" & /bin/sleep 0.1

i=0
while /usr/bin/pgrep Dialog > /dev/null 2>&1 && [ $i -lt 30 ]
do
    write_log "Waiting for user to close dialog"
    /bin/sleep 1
    ((i++))
done

write_log "Quitting."
update_dialog "quit"

exit_script 0
