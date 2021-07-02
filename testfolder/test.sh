#!/bin/sh
source "../scripts/bash/utility.sh"
source "../scripts/ci/notificationutil.sh"

queryPackageByName1() {
    local PACKAGE_QUERY_FIELDS=" Id, Name, Package2Id, Tag Package2.Name, SubscriberPackageVersion.Dependencies, IsReleased, MajorVersion, MinorVersion, PatchVersion, CreatedDate, LastModifiedDate, AncestorId, Ancestor.MajorVersion, Ancestor.MinorVersion, Ancestor.PatchVersion "
    echo $(sfdx force:data:soql:query -u $TARGETDEVHUBUSERNAME -t \
        -q "SELECT $PACKAGE_QUERY_FIELDS FROM Package2Version WHERE Package2.Name = '$1' ORDER BY LastModifiedDate DESC, CreatedDate DESC LIMIT 1" \
        --json)
}

function createVersion() {
    readParams "$@"

    sfdx force:package:version:create --path=$SOURCEPATH --package=$PACKAGE \
        --tag=$COMMITTAG --targetdevhubusername=$TARGETDEVHUBUSERNAME --wait=$WAIT \
        --definitionfile=$DEFINITIONFILE --codecoverage --installationkeybypass
}

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

function createPackageVersion() {
    TARGETDEVHUBUSERNAME="sagedevorg"
    SFDX_JSON=$(<../../sfdx-project.json)
    P_NAME=$(echo $SFDX_JSON | jq -r ".packageDirectories | map(select(.default == true))  | .[0].package")
    DEFINITIONFILE="../scratch-org-config/project-scratch-def.json"

    if [ -n "$P_NAME" ]
    then
        P_VERSION_SFDX_JSON=$(echo $SFDX_JSON | jq -r ".packageDirectories | map(select(.package == \"$P_NAME\")) | .[0].versionNumber" | cut -d "." -f1,2,3)
        QUERY_RESPONSE=$(queryPackageByName1 $P_NAME)
        handleSfdxResponse "$QUERY_RESPONSE" "Package Creation Notifications" "Create package version $P_NAME - $P_VERSION_SFDX_JSON"
        if [ "$(echo $QUERY_RESPONSE | jq ".result.totalSize")" = "0" ]
        then
            echo "$P_NAME not found"
            # TODO: CREATE PACKAGE BEFORE CREATING VERSION
        else
            echo "$P_NAME found"
            P_VERSION_DEVHUB=$(echo $QUERY_RESPONSE | jq -r '"\(.result.records[0].MajorVersion)"+"."+"\(.result.records[0].MinorVersion)"+"."+"\(.result.records[0].PatchVersion)"')
            echo $P_VERSION_DEVHUB
            echo $P_VERSION_SFDX_JSON
            if [ $P_VERSION_DEVHUB = $P_VERSION_SFDX_JSON ]
            then
                echo "Latest devhub package version is same as requested (sfdx-project.json)"
                if [ "$(echo $QUERY_RESPONSE | jq -r ".result.records[0].IsReleased")" = "true" ]
                then
                    # TODO: GENERATE ERROR: requested version already have a released major.minor.patch
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
                        --package $P_NAME --tag $(git rev-parse --short "$GITHUB_SHA") --targetdevhubusername $TARGETDEVHUBUSERNAME --wait "30" --definitionfile $DEFINITIONFILE
                else
                    # TODO: GENERATE ERROR
                    echo "Cannot downgrade a package version from $P_VERSION_DEVHUB to $P_VERSION_SFDX_JSON."
                    exit 1
                fi
            fi
        fi
    else
        echo "Package Name not found in sfdx-json"
    fi
}
#createPackageVersion
#testspilt
SOURCEPATH="sales"
PACKAGE="salesforce-global-sales"
DEFINITIONFILE="config/scratch-org-config/project-scratch-def.json"
COMMITTAG="97262a8"
local CMD_CREATE="sfdx force:package:version:create --path=$SOURCEPATH --package=$PACKAGE \
    --tag=$COMMITTAG --targetdevhubusername=$TARGETDEVHUBUSERNAME \
    --definitionfile=$DEFINITIONFILE --codecoverage --installationkeybypass --json"
echo "Initiating package creation.."
echo $CMD_CREATE
local RESP_CREATE=$(echo $($CMD_CREATE)) # create package and collect response
echo $RESP_CREATE
handleSfdxResponse $RESP_CREATE
local JOBID=$(echo $RESP_CREATE | jq -r ".result[0].Id")
echo "Initilised with job id: $JOBID"
echo $CMD_REPORT="sfdx force:package:version:create:report --targetdevhubusername=$TARGETDEVHUBUSERNAME --packagecreaterequestid=$JOBID --json"
while true
do
    RESP_REPORT=$($CMD_REPORT)
    if [ $(echo $RESP_REPORT | jq -r ".status") = "1" ]
    then
        handleSfdxResponse $RESP_REPORT
        break
    else
        local REQ_STATUS=$(echo $RESP_REPORT | jq -r ".result[0].Status")
        if [ $REQ_STATUS = "Success" ]
        then
            sendNotification --statuscode "0" \
                --message "Package creation successful" \
                --details "New beta version of $VERSIONNUMBER for $PACKAGE created successfully with following details. \n\r $(echo $RESPONSE_REPORT | jq -r ".result[0]")"
            break
        else
            sleep 5
            echo "Request status $REQ_STATUS"
            RESP_REPORT=$($CMD_REPORT)
        fi
    fi
    break;
done