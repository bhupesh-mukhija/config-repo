#!/bin/bash
source "$SCRIPTS_PATH/config/scripts/ci/packageutil.sh"

function installPackage() {
    echo "Preparting package details..."
    # get package name from sfdx project json
    local PACKAGE_NAME=$(cat $SCRIPTS_PATH/sfdx-project.json | jq -r ".packageDirectories | map(select(.default == true))  | .[0].package")
    # query package from devhub
    #QUERY_RESPONSE=$(queryPackageByName1 $PACKAGE_NAME)
    local SUBSCRIBER_PACKAGE_VERSION=$(echo $(queryPackageByName1 $PACKAGE_NAME) | jq -r '.result.records[0].SubscriberPackageVersion.attributes.url' | sed 's/.*\///')
    echo $SUBSCRIBER_PACKAGE_VERSION
    # get package report for details
    local PACKAGE_REPORT=$(sfdx force:package:version:report --targetdevhubusername=$TARGETDEVHUBUSERNAME -p $SUBSCRIBER_PACKAGE_VERSION --json)
    echo "Package to be installed"
    echo $PACKAGE_REPORT | jq # TODO: Parse json and show formatted
    # TODO: Make it async use loop to report on create
    sfdx force:package:install --targetusername=$TARGETUSERNAME --package=$SUBSCRIBER_PACKAGE_VERSION --wait=30
}