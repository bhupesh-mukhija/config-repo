#!/bin/bash
source "/github/workspace/config/scripts/bash/utility.sh"
source "/github/workspace/config/scripts/ci/notificationutility.sh"

function handleSfdxResponse() {
    local RESPONSE=$1
    if [ "$(echo $RESPONSE | jq -r ".status")" = "1" ]
    then
        echo "******* SFDX Command Failed *******"
        echo $QUERY_RESPONSE | jq
        STACK=$(echo $RESPONSE | jq -r ".name,.message,.stack")
        sendNotification --statuscode $(echo $RESPONSE | jq -r ".status") \
            --message "$(echo $RESPONSE | jq -r ".name"): $(echo $RESPONSE | jq -r ".message")" \
            --details "$(echo $RESPONSE | jq -r ".stack")"
    fi
}

function packageCreate() {
    # get sfdx json file
    DEFINITIONFILE="/github/workspace/config/scratch-org-config/project-scratch-def.json"
    SFDX_JSON=$(cat /github/workspace/sfdx-project.json)
    P_NAME=$(echo $SFDX_JSON | jq -r ".packageDirectories | map(select(.default == true))  | .[0].package")
    echo "Package name found : $P_NAME"
    if [ -n "$P_NAME" ]
    then
        P_VERSION_SFDX_JSON=$(echo $SFDX_JSON | jq -r ".packageDirectories | map(select(.package == \"$P_NAME\")) | .[0].versionNumber" | cut -d "." -f1,2,3)
        echo "Query package details.."
        SUBTITLE="Create package version $P_NAME - $P_VERSION_SFDX_JSON"
        QUERY_RESPONSE=$(queryPackageByName $P_NAME)
        handleSfdxResponse "$QUERY_RESPONSE"
        if [ "$(echo $QUERY_RESPONSE | jq ".result.totalSize")" = "0" ]
        then
            # TODO: REVISIT AS PACKAGE NAME WILL NOT BE AVAILABLE iN SFDX PROJECT JSON
            echo "$P_NAME not found, create a package and then version"
            # TODO: CREATE PACKAGE BEFORE CREATING VERSION
        else
            echo "$P_NAME found, continue to create package version"
            P_VERSION_DEVHUB=$(echo $QUERY_RESPONSE | jq -r '"\(.result.records[0].MajorVersion)"+"."+"\(.result.records[0].MinorVersion)"+"."+"\(.result.records[0].PatchVersion)"')
            #if [ $P_VERSION_DEVHUB = $P_VERSION_SFDX_JSON ] && [ $(jq -r ".result.records[0].IsReleased" <<< $QUERY_RESPONSE) = "true" ];
            if [ "$P_VERSION_DEVHUB" = "$P_VERSION_SFDX_JSON" ]
            then
                echo "Latest devhub package version is same as requested (sfdx-project.json)"
                if [ "$(echo $QUERY_RESPONSE | jq -r ".result.records[0].IsReleased")" = "true" ]
                then # if requested package version released, fail the job and send notification
                    echo "Requested version $P_VERSION_SFDX_JSON is already released, please update sfdx project json and rerun the job"
                    sendNotification --statuscode "1" --message "Requested version is already released" \
                        --details "Requested version $P_VERSION_SFDX_JSON is already released, please increase either major, minor or patch version."
                else # create package version
                    echo "Creating next beta version ($P_VERSION_SFDX_JSON) for package $P_NAME ..."
                    VERSION_RESPONSE=$(createVersion --sourcepath $(echo $SFDX_JSON | jq -r ".packageDirectories | map(select(.default == true))  | .[0].path") \
                        --package $P_NAME --tag $(git rev-parse --short "$GITHUB_SHA") --targetdevhubusername $TARGETDEVHUBUSERNAME --wait 30 --definitionfile $DEFINITIONFILE)
                    handleSfdxResponse "$VERSION_RESPONSE"
                    sendNotification --statuscode "0" \
                        --message "Package creation successful" \
                        --details "New beta version of $P_VERSION_SFDX_JSON for $P_NAME created successfully"
                fi
            else
                echo "Requested package version (sfdx-project.json) and latest devhub version are not same"
                # check if the package version requested is downgrading
                if [ "$(isUpgrade ${P_VERSION_DEVHUB//"."/ } ${P_VERSION_SFDX_JSON//"."/ })" = "1" ]
                then
                    # create package version as it is upgrading
                    echo "Creating next beta version ($P_VERSION_SFDX_JSON) for package $P_NAME ..."
                    createVersion --sourcepath $(echo $SFDX_JSON | jq -r ".packageDirectories | map(select(.default == true))  | .[0].path") \
                        --package $P_NAME --tag $(git rev-parse --short "$GITHUB_SHA") --targetdevhubusername $TARGETDEVHUBUSERNAME --wait 30 --definitionfile $DEFINITIONFILE
                else
                    echo "Cannot downgrade a package version from $P_VERSION_DEVHUB to $P_VERSION_SFDX_JSON."
                    sendNotification --statuscode "1" --message "Cannot downgrade a package version" \
                        --details "Version downgrade not possible, please increase either major, minor or patch version. Latest DevHub version is : $P_VERSION_DEVHUB, sfdx project json/requested version: $P_VERSION_SFDX_JSON."
                fi
            fi
        fi
    else
        echo "Package Name not found in sfdx-json"
    fi
}