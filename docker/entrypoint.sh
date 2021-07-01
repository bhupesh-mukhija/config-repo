#!/bin/bash
# add bash files from config repo
source "/github/workspace/config/scripts/bash/utility.sh"
source "/github/workspace/config/scripts/ci/createPackage.sh"

# set path for sfdx
PATH=/root/sfdx/bin:$PATH
sfdx --version
sfdx plugins --core

TARGETDEVHUBUSERNAME="devhubuser" # setup devhubuser alias
echo $1 > /root/secrets/devhub.txt # save the devhub org secret
echo $DEV_HUB_URL
echo "Authorizing devhub..."
RESPONSE=$(authorizeOrg "devhub" $TARGETDEVHUBUSERNAME)
handleSfdxResponse "$RESPONSE" "DX DevHub Authrization Failed" "Failed at $GITHUB_SERVER_URL/$GITHUB_REPOSITORY repository"

if [ "$2" = "create_version" ]
then
    echo "Package version request.."
    packageCreate
else
    echo "Validation Request.."
fi