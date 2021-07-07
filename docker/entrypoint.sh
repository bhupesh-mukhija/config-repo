#!/bin/bash
# add bash files from config repo
set -e # exit on error
source "/github/workspace/config/scripts/bash/utility.sh"
source "/github/workspace/config/scripts/ci/createPackage.sh"

# set path for sfdx
PATH=/root/sfdx/bin:$PATH
sfdx --version
sfdx plugins --core
CURRENT_BRANCH=$GITHUB_REF
echo "Current branch : $CURRENT_BRANCH"
USE_SFDX_BRANCH=$USE_BRANCH
DEPDENCY_VAL=$ERR_DEPENDENCY_VALIDATION

echo "Remove Comments start *****************************"
echo "Branch: $CURRENT_BRANCH"
echo "Use Sfdx Branch : $USE_SFDX_BRANCH"
echo "Dependency validation $ERR_DEPENDENCY_VALIDATION"
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