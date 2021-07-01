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
            --details "$(echo $RESPONSE | jq -r ".stack")" --title "$2" --subtitle "$3"
            #--title  --subtitle 
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
        QUERY_RESPONSE=$(queryPackageByName $P_NAME)
        handleSfdxResponse "$QUERY_RESPONSE" "Package Creation Notifications" "Create package version $P_NAME - $P_VERSION_SFDX_JSON"
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
                then
                    # TODO: GENERATE ERROR AND PUBLISH TO TEAMS CHANNEL
                    echo "Requested version is already released, please update sfdx project json and rerun the job"
                else
                    echo "Creating next beta version ($P_VERSION_SFDX_JSON) for package $P_NAME ..."
                    createVersion --sourcepath $(echo $SFDX_JSON | jq -r ".packageDirectories | map(select(.default == true))  | .[0].path") \
                        --package $P_NAME --tag $(git rev-parse --short "$GITHUB_SHA") --targetdevhubusername $TARGETDEVHUBUSERNAME --wait 30 --definitionfile $DEFINITIONFILE    
                fi
            else
                echo "Requested package version (sfdx-project.json) and latest devhub version are not same"
                # check if the package version requested is downgrading
                echo $(isUpgrade ${P_VERSION_DEVHUB//"."/} ${P_VERSION_SFDX_JSON//"."/})
                if [ "$(isUpgrade ${P_VERSION_DEVHUB//"."/ } ${P_VERSION_SFDX_JSON//"."/ })" = "1" ]
                then
                    # create package version as it is upgrading
                    echo "Creating next beta version ($P_VERSION_SFDX_JSON) for package $P_NAME ..."
                    createVersion --sourcepath $(echo $SFDX_JSON | jq -r ".packageDirectories | map(select(.default == true))  | .[0].path") \
                        --package $P_NAME --tag $(git rev-parse --short "$GITHUB_SHA") --targetdevhubusername $TARGETDEVHUBUSERNAME --wait 30 --definitionfile $DEFINITIONFILE
                else
                    # TODO: GENERATE ERROR AND PUBLISH TO TEAMS CHANNEL
                    echo "Cannot downgrade a package version from $P_VERSION_DEVHUB to $P_VERSION_SFDX_JSON."
                    exit 1
                fi
            fi
        fi
    else
        echo "Package Name not found in sfdx-json"
    fi
}