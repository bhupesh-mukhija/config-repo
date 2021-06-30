#!/bin/sh
source "../scripts/bash/utility.sh"

queryPackageByName() {
    local PACKAGE_QUERY_FIELDS=" Id, Name, Package2Id, Tag, Package2.Name, SubscriberPackageVersion.Dependencies, IsReleased, MajorVersion, MinorVersion, PatchVersion, CreatedDate, LastModifiedDate, AncestorId, Ancestor.MajorVersion, Ancestor.MinorVersion, Ancestor.PatchVersion "
    echo $(sfdx force:data:soql:query -u $TARGETDEVHUBUSERNAME -t \
        -q "SELECT $PACKAGE_QUERY_FIELDS FROM Package2Version WHERE Package2.Name = '$1' ORDER BY LastModifiedDate DESC, CreatedDate DESC LIMIT 1" \
        --json)
    #echo $QUERY_RESULT
}

function createVersion() {
    readParams "$@"

    sfdx force:package:version:create --path=$SOURCEPATH --package=$PACKAGE \
        --tag=$COMMITTAG --targetdevhubusername=$TARGETDEVHUBUSERNAME --wait=$WAIT \
        --definitionfile=$DEFINITIONFILE --codecoverage --installationkeybypass
}

TARGETDEVHUBUSERNAME="sagedevorg"
SFDX_JSON=$(<../../sfdx-project.json)
P_NAME=$(echo $SFDX_JSON | jq -r ".packageDirectories | map(select(.default == true))  | .[0].package")
echo $P_NAME
$DEFINITIONFILE="../scratch-org-config/project-scratch-def.json"

PACKAGE_INFO=$(queryPackageByName $P_NAME)
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
        echo "$P_NAME found"
        P_VERSION_DEVHUB=$(echo $PACKAGE_INFO | jq -r '"\(.result.records[0].MajorVersion)"+"."+"\(.result.records[0].MinorVersion)"+"."+"\(.result.records[0].PatchVersion)"')
        echo $P_VERSION_DEVHUB
        P_VERSION_SFDX_JSON=$(echo $SFDX_JSON | jq -r ".packageDirectories | map(select(.package == \"$P_NAME\")) | .[0].versionNumber" | cut -d "." -f1,2,3)
        echo $P_VERSION_SFDX_JSON
        if [ $P_VERSION_DEVHUB = $P_VERSION_SFDX_JSON ]
        then
            echo "Devhub version equals sfdx json version"
            echo $(echo $PACKAGE_INFO | jq -r ".result.records[0].IsReleased")
            if [ $(echo $PACKAGE_INFO | jq -r ".result.records[0].IsReleased") = "true" ]
            then
                # TODO: generate error: requested version already have a released major.minor.patch
                echo "ERROR: Requested version is already released, please update and rerun the job"
            fi
        else
            echo "Devhub version not equals sfdx json version"
            # TODO: Chcek if the package version is upgraded or downgraded
            # fail if it is downgrading else create the version
            
            createVersion --sourcepath $(echo $SFDX_JSON | jq -r ".packageDirectories | map(select(.default == true))  | .[0].path") \
                 --package $P_NAME --tag $(git rev-parse --short "$GITHUB_SHA") --targetdevhubusername $TARGETDEVHUBUSERNAME --wait 30 --definitionfile $DEFINITIONFILE
        fi
    fi
fi