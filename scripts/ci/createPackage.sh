#!/bin/sh
source "/github/workspace/config/scripts/bash/utility.sh"

packageCreate() {
    # get sfdx json file
    DEFINITIONFILE="/github/workspace/config/scratch-org-config/project-scratch-def.json"
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
            # TODO: REVISIT AS PACKAGE NAME WILL NOT BE AVAILABLE iN SFDX PROJECT JSON
            echo "$P_NAME not found, create a package and then version"
            # TODO: CREATE PACKAGE BEFORE CREATING VERSION
        else
            echo "$P_NAME found, continue to create package version"
            P_VERSION_DEVHUB=$(echo $PACKAGE_INFO | jq -r '"\(.result.records[0].MajorVersion)"+"."+"\(.result.records[0].MinorVersion)"+"."+"\(.result.records[0].PatchVersion)"')
            P_VERSION_SFDX_JSON=$(echo $SFDX_JSON | jq -r ".packageDirectories | map(select(.package == \"$P_NAME\")) | .[0].versionNumber" | cut -d "." -f1,2,3)
            #if [ $P_VERSION_DEVHUB = $P_VERSION_SFDX_JSON ] && [ $(jq -r ".result.records[0].IsReleased" <<< $PACKAGE_INFO) = "true" ];
            if [ "$P_VERSION_DEVHUB" = "$P_VERSION_SFDX_JSON" ]
            then
                echo "Latest devhub package version is same as requested (sfdx-project.json)"
                if [ "$(echo $PACKAGE_INFO | jq -r ".result.records[0].IsReleased")" = "true" ]
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
    fi
}