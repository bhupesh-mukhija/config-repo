#!/bin/sh
source "/github/workspace/config/scripts/bash/utility.sh"

packageCreate() {
    # get sfdx json file
    $DEFINITIONFILE="/github/workspace/config/scratch-org-config/project-scratch-def.json"
    SFDX_JSON=$(cat /github/workspace/sfdx-project.json)
    P_NAME=$(echo $SFDX_JSON | jq -r ".packageDirectories | map(select(.default == true))  | .[0].package")
    PACKAGE_INFO=$(queryPackageByName $P_NAME)
    echo $PACKAGE_INFO
    #QUERY_STATUS=$(echo $PACKAGE_INFO | jq -r ".status")
    if [ "$(echo $PACKAGE_INFO | jq -r ".status")" = "1" ]
    then
        echo "Query Error FAIL THE JOB"
        echo $PACKAGE_INFO | jq -r ".name,.message,.stack"
        exit 1
        # TODO: ERROR HANDLING - send emails or post to teams channel
    else
        echo "PACKAGE QUERY SUCCESSFUL"
        if [ "$(echo $PACKAGE_INFO | jq ".result.totalSize")" = "0" ]
        then
            echo "$P_NAME not found"
            # TODO: CREATE PACKAGE BEFORE CREATING VERSION
        else
            echo "$P_NAME found, continue to create package version"
            P_VERSION_DEVHUB=$(echo $PACKAGE_INFO | jq -r '"\(.result.records[0].MajorVersion)"+"."+"\(.result.records[0].MinorVersion)"+"."+"\(.result.records[0].PatchVersion)"')
            echo $P_VERSION_DEVHUB
            P_VERSION_SFDX_JSON=$(echo $SFDX_JSON | jq -r ".packageDirectories | map(select(.package == \"$P_NAME\")) | .[0].versionNumber" | cut -d "." -f1,2,3)
            echo $P_VERSION_SFDX_JSON
            #if [ $P_VERSION_DEVHUB = $P_VERSION_SFDX_JSON ] && [ $(jq -r ".result.records[0].IsReleased" <<< $PACKAGE_INFO) = "true" ];
            if [ "$P_VERSION_DEVHUB" = "$P_VERSION_SFDX_JSON" ]
            then
                echo "Devhub version equals sfdx json version"
                echo $(echo $PACKAGE_INFO | jq -r ".result.records[0].IsReleased")
                if [ $(echo $PACKAGE_INFO | jq -r ".result.records[0].IsReleased") = "true" ]
                then
                    # TODO: generate error: requested version already have a released major.minor.patch
                    echo "ERROR: Requested version is already released, please update sfdx project json and rerun the job"
                fi
            else
                echo "Devhub version not equals sfdx json version"
                # TODO: only allow minor/major/patch versions upgrades
                # TODO: Check if dependencis do not match the latest ones
                RESPONSE=$(createVersion --sourcepath $(echo $SFDX_JSON | jq -r ".packageDirectories | map(select(.default == true))  | .[0].path") \
                    --package $P_NAME --tag $(git rev-parse --short "$GITHUB_SHA") --targetdevhubusername $TARGETDEVHUBUSERNAME --wait 30 --definitionfile $DEFINITIONFILE)
                sendTeamsNotification
            fi
        fi
    fi
}