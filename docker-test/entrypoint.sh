#!/bin/bash
# add bash files from config repo
set -e # exit on error
source "$SCRIPTS_PATH/config/scripts/bash/utility.sh"
source "$SCRIPTS_PATH/config/scripts/ci/createPackage.sh"
source "$SCRIPTS_PATH/config/scripts/ci/install.sh"

# set path for sfdx
PATH=/root/sfdx/bin:$PATH
sfdx --version
sfdx plugins --core
echo "Operation: $1"
echo "Aws Url: $2"
CURRENT_BRANCH=$(echo $BRANCH | sed 's/.*\///')
USE_SFDX_BRANCH=$(cat $SCRIPTS_PATH/config/docker/config.json | jq '.useBranch')
DEPDENCY_VAL=$(cat $SCRIPTS_PATH/config/docker/config.json | jq '.dependecyValidation')
echo "Container Running..."
