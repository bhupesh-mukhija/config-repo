#!/bin/bash
# send teams notification on job failure
source "$SCRIPTS_PATH/config/scripts/ci/notificationutil.sh"

sendNotification --statuscode "1" --message "Unknown error occured" \
                --details "Error occured during package creation, please check dev channel or view logs by clicking View Log button"