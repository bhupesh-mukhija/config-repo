#!/bin/bash
# add bash files from config repo
set -e # exit on error
source "/github/workspace/config/scripts/bash/utility.sh"
source "/github/workspace/config/scripts/ci/createPackage.sh"

# set path for sfdx
PATH=/root/sfdx/bin:$PATH
sfdx --version
sfdx plugins --core

TARGETDEVHUBUSERNAME="devhubuser" # setup devhubuser alias
echo $DEV_HUB_URL > /root/secrets/devhub.txt # save the devhub org secret
echo "Authorizing devhub..."
RESPONSE=$(authorizeOrg "/root/secrets/devhub.txt" $TARGETDEVHUBUSERNAME)
handleSfdxResponse "$RESPONSE" "DX DevHub Authrization Failed" "Failed at $GITHUB_SERVER_URL/$GITHUB_REPOSITORY repository"

if [ "$1" = "create_version" ]
then
    echo "Package version request.."
    TITLE="Package Creation Notifications"
    packageCreate
else
    echo "Validation Request.."
fi