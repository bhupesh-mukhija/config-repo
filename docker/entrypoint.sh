#!/bin/bash
# add bash files from config repo
set -e # exit on error
source "$SCRIPTS_PATH/config/scripts/bash/utility.sh"
source "$SCRIPTS_PATH/config/scripts/ci/createPackage.sh"

# set path for sfdx
PATH=/root/sfdx/bin:$PATH
sfdx --version
sfdx plugins --core
CURRENT_BRANCH=$(echo $BRANCH | sed 's/.*\///')
USE_SFDX_BRANCH=$(cat $SCRIPTS_PATH/config/docker/config.json | jq '.useBranch')
DEPDENCY_VAL=$(cat $SCRIPTS_PATH/config/docker/config.json | jq '.dependecyValidation')

echo "Remove Comments start *****************************"
echo "Branch: $CURRENT_BRANCH"
echo "Use Sfdx Branch : $USE_SFDX_BRANCH"
echo "Dependency validation $DEPDENCY_VAL"
echo "Remove Comments end *****************************"

TARGETDEVHUBUSERNAME="devhubuser" # setup devhubuser alias
echo $DEV_HUB_URL > /root/secrets/devhub.txt # save the devhub org secret
echo "Authorizing devhub..."
RESPONSE=$(authorizeOrg "/root/secrets/devhub.txt" $TARGETDEVHUBUSERNAME)
handleSfdxResponse "$RESPONSE" "DX DevHub Authrization Failed" "Failed at $GITHUB_SERVER_URL/$GITHUB_REPOSITORY repository"

if [ "$1" = "create_version" ]
then
    echo "Package version request.."
    TITLE="Package Creation Notifications"
    VALIDATE_DEPENDENCY_ERROR=$ERR_DEPENDENCY_VALIDATION
    packageCreate
else
    echo "Validation Request.."
fi