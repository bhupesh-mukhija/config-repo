#!/bin/sh
source "../scripts/bash/utility.sh"
source "../scripts/ci/notificationutil.sh"

queryPackageByName1() {
    local PACKAGE_QUERY_FIELDS=" Id, Name, Package2Id, Tag, Package2.Name, SubscriberPackageVersion.Dependencies, IsReleased, MajorVersion, MinorVersion, PatchVersion, CreatedDate, LastModifiedDate, AncestorId, Ancestor.MajorVersion, Ancestor.MinorVersion, Ancestor.PatchVersion "
    echo $(sfdx force:data:soql:query -u $TARGETDEVHUBUSERNAME -t \
        -q "SELECT $PACKAGE_QUERY_FIELDS FROM Package2Version WHERE Package2.Name = '$1' ORDER BY LastModifiedDate DESC, CreatedDate DESC LIMIT 1" \
        --json)
}

function queryPackageBySubscriberVersionId() {
    local PACKAGE_QUERY_FIELDS=" Id, Name, Package2Id, Tag, Package2.Name
        , SubscriberPackageVersion.Dependencies, IsReleased, MajorVersion, MinorVersion
        , PatchVersion, CreatedDate, LastModifiedDate, AncestorId, Ancestor.MajorVersion
        , Ancestor.MinorVersion, Ancestor.PatchVersion "
    echo $(sfdx force:data:soql:query -u $TARGETDEVHUBUSERNAME -t \
        -q "SELECT $PACKAGE_QUERY_FIELDS FROM Package2Version WHERE SubscriberPackageVersionId IN ($1) ORDER BY LastModifiedDate DESC, CreatedDate DESC LIMIT 1" --json)
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
function start() {
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
}


function getDependenciesFromDevHub() {
    P_NAME="salesforce-global-sales"
    TARGETDEVHUBUSERNAME="sagedevorg"
    QUERY_RESPONSE=$(queryPackageByName1 $P_NAME)
    #echo $QUERY_RESPONSE | jq
    PACKAGE_Id=$(echo $QUERY_RESPONSE | jq -r ".result.records | map(select(.Package2.Name == \"$P_NAME\"))  | .[0].Package2Id")
    # get dependencies from package details
    DEPENDENCIES=$(echo $QUERY_RESPONSE \
        | jq -r ".result.records \
        | map(select(.Package2.Name == \"$P_NAME\")) \
        | .[0].SubscriberPackageVersion.Dependencies")

    # get query filter
    iterator=0
    for eachDepId in $(echo $DEPENDENCIES | jq -r '.ids | keys[] as $k | "\(.[$k].subscriberPackageVersionId)"')
    do
        if [ "$iterator" = "0" ]
        then
            QUERY_FILTER+="'$eachDepId'"
        else
            QUERY_FILTER+=",'$eachDepId'"
        fi
        iterator+=1
    done
    echo "$QUERY_FILTER"
    queryPackageBySubscriberVersionId $QUERY_FILTER | jq
    #D=$(echo $DEPENDENCIES | jq -r '.ids | map(.subscriberPackageVersionId) | join(",")')
    #echo $D
    #RES=$(queryPackageBySubscriberVersionId $D)
    #echo $RES | jq

    # get values from array
    #DEPENDENCY_ARRAY=$(echo $DEPENDENCIES | jq -r '.ids | keys[] as $k | "\(.[$k].subscriberPackageVersionId)"')
    #echo $(printf '%s,' "${DEPENDENCY_ARRAY[@]}")
}

function dependenciesTest() {
    ERR_DEPENDENCY_VALIDATION="true"
    SFDX_JSON=$(<../../sfdx-project.json)
    P_NAME="salesforce-global-sales"
    TARGETDEVHUBUSERNAME="sagedevorg"
    VERSIONS_PACKAGE=$(echo $SFDX_JSON | jq -r ".packageDirectories | map(select(.package == \"$P_NAME\")) | .[0].dependencies")
    ARRAY=($(echo $VERSIONS_PACKAGE | jq -r '.[] | keys[] as $k | "\(.[$k])"'))
    VERSION_MISMATCH=0
    for ((iterator=0; iterator<${#ARRAY[@]}; iterator++))
    do
        local CURRENT_PACKAGE=${ARRAY[iterator]}
        # query in loop due to restrictions on the object
        local DEV_HUB_VERSION=$(queryPackageByName1 $CURRENT_PACKAGE | jq -r '"\(.result.records[0].MajorVersion)"+"."+"\(.result.records[0].MinorVersion)"+"."+"\(.result.records[0].PatchVersion)"')
        iterator=$((iterator+1)) # access version
        local SFDX_JSON_VERSION=$(echo ${ARRAY[iterator]} | cut -d "." -f1,2,3)
        if [ "$DEV_HUB_VERSION" != "$SFDX_JSON_VERSION" ]
        then
            VERSION_MISMATCH=1
            echo "Dependencies version in sfdx project json ($SFDX_JSON_VERSION) do not match with latest Devhub version ($DEV_HUB_VERSION) for package $CURRENT_PACKAGE"
        fi
    done
    if [ "$VERSION_MISMATCH" = "1" ] 
    then
        if [ "$ERR_DEPENDENCY_VALIDATION" = "true" ]
        then
            echo "ERROR!"
        else
            echo "WARNING!"
        fi
    fi
}

function spiltString() {
    URL=https://developer.salesforce.com/media/salesforce-cli/sfdx/versions/7.108.0/d2f9bbd/sfdx-v7.108.0-d2f9bbd-linux-x64.tar.xz
    echo $URL | sed 's/.*\///'
}
#dependenciesTest
#echo "Script ran on failure"

USE_SFDX_BRANCH=$(cat ../docker/config.json | jq '.useBranch')
DEPDENCY_VAL=$(cat ../docker/config.json | jq '.dependecyValidation')
ENDPOINT=$(cat ../docker/config.json | jq '.notifications | map(select(.type == "teams")) | .[0].recipients | map(select(.role) == "ci")')

echo $USE_SFDX_BRANCH
echo $DEPDENCY_VAL
echo $ENDPOINT | jq