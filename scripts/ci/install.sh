#!/bin/bash
source "$SCRIPTS_PATH/config/scripts/ci/packageutil.sh"

function installPackage() {
    echo "Preparting package details..."
    # get package name from sfdx project json
    local PACKAGE_NAME=$(cat $SCRIPTS_PATH/sfdx-project.json | jq -r ".packageDirectories | map(select(.default == true))  | .[0].package")
    # query package from devhub
    local QUERY_RESPONSE=$(queryPackageByName $PACKAGE_NAME)
    local VERSION_NUMBER=$(echo $QUERY_RESPONSE | jq -r '"\(.result.records[0].MajorVersion)"+"."+"\(.result.records[0].MinorVersion)"+"."+"\(.result.records[0].PatchVersion)"')
    local SUBSCRIBER_PACKAGE_VERSION=$(echo $QUERY_RESPONSE | jq -r '.result.records[0].SubscriberPackageVersion.attributes.url' | sed 's/.*\///')
    echo "Package version id : "$SUBSCRIBER_PACKAGE_VERSION
    # get package report for details
    local PACKAGE_REPORT=$(sfdx force:package:version:report --targetdevhubusername=$TARGETDEVHUBUSERNAME -p $SUBSCRIBER_PACKAGE_VERSION --json)
    handleSfdxResponse "$PACKAGE_REPORT"

    echo "Package to be installed"
    #echo $PACKAGE_REPORT | jq # TODO: Parse json and show formatted
    RESPONSE_INSTALL=$(sfdx force:package:install --targetusername=$TARGETUSERNAME --package=$SUBSCRIBER_PACKAGE_VERSION --json)
    handleSfdxResponse "$RESPONSE_INSTALL"
    # test
    local JOBID=$(echo $RESPONSE_INSTALL | jq -r ".result.Id")
    echo "Initilised with job id: $JOBID"
    while true
    do
        local CREATE_REPORT=$(sfdx force:package:install:report --requestid=$JOBID --targetusername=$TARGETUSERNAME --json)
        if [ "$(echo $CREATE_REPORT | jq -r ".status")" = "1" ]
        then
            handleSfdxResponse "$CREATE_REPORT"
            break
        else
            local STATUS=$(echo $CREATE_REPORT | jq -r ".result.Status")
            if [ $STATUS = "Success" ]
            then
                local INSTANCE=$(echo $AUTH_RESPONSE | jq '.result.loginUrl')
                echo "Package successfully installed.."
                sendNotification --statuscode "0" \
                    --message "Package insatllation successful" \
                    --details "Package version <b>$VERSION_NUMBER</b> for <b>$PACKAGE_NAME</b> is installed successfully 
                        in instance $INSTANCE."
            else
                sleep 5
                echo "Request status $STATUS"
            fi
        fi
    done
}