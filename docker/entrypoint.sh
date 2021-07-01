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

echo "Authorizing devhub..."
local RESPONSE=$(authorizeOrg "/root/secrets/devhub.txt" $TARGETDEVHUBUSERNAME)
echo "&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&"
echo $GITHUB_RUN_ID
echo $GITHUB_RUN_NUMBER
echo $GITHUB_JOB
echo $GITHUB_ACTION
echo $GITHUB_ACTION_PATH
echo $GITHUB_ACTOR
echo $GITHUB_REPOSITORY
echo $GITHUB_EVENT_NAME
echo $GITHUB_EVENT_PATH
echo $GITHUB_WORKSPACE
echo $GITHUB_SERVER_URL
echo $GITHUB_EVENT_NAME
echo $GITHUB_EVENT_NAME
echo $GITHUB_EVENT_NAME
echo "$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID"
echo "&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&"
handleSfdxResponse "$RESPONSE" "Package Creation Notifications" "Create package version $P_NAME - $P_VERSION_SFDX_JSON"

if [ "$2" = "create_version" ]
then
    echo "Package version request.."
    packageCreate
else
    echo "Validation Request.."
fi