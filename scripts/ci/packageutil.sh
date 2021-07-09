#!/bin/bash
source "$SCRIPTS_PATH/config/scripts/ci/globalutil.sh"

function readPackageParams {
    while [[ $# -gt 0 ]] # for each positional parameter
    do key="$1"
        case "$key" in
            -p|--package) # matching argument with sfdx standards
                PACKAGE="$2"
                shift # past argument
                shift # past value
            ;;
            -v|--targetdevhubusername) # matching argument with sfdx standards
                TARGETDEVHUBUSERNAME="$2"
                shift # past argument
                shift # past value
            ;;
            -sp|--sourcepath) #matching argument with sfdx standards
                SOURCEPATH="$2"
                shift # past argument
                shift # past value
            ;;
            -cp|--configpath)
                CONFIGPATH="$2"
                shift # past argument
                shift # past value
            ;;
            -ds|--description)
                DESCRIPTION="$2"
                shift # past argument
                shift # past value
            ;;
            -n|--name)
                PACKAGENAME="$2"
                shift # past argument
                shift # past value
            ;;
            -t|--packagetype)
                PACKAGETYPE="$2"
                shift # past argument
                shift # past value
            ;;
            -vn|--versioname)
                VERSIONNAME="$2"
                shift # past argument
                shift # past value
            ;;
            -vn|--versionnumber)
                VERSIONNUMBER="$2"
                shift # past argument
                shift # past value
            ;;
            -ct|--tag)
                COMMITTAG="$2"
                shift # past argument
                shift # past value
            ;;
            -w|--wait)
                WAIT="$2"
                shift # past argument
                shift # past value
            ;;
            -f|--definitionfile)
                DEFINITIONFILE="$2"
                shift # past argument
                shift # past value
            ;;               
            *) # unknown option
                shift # past argument
            ;;
        esac
    done
}

function queryPackageByName() {
    local PACKAGE_QUERY_FIELDS=" Id, Name, Package2Id, Tag, Package2.Name, SubscriberPackageVersion.Dependencies, IsReleased, MajorVersion, MinorVersion, PatchVersion, CreatedDate, LastModifiedDate, AncestorId, Ancestor.MajorVersion, Ancestor.MinorVersion, Ancestor.PatchVersion "
    local QUERY_RESULT=$(sfdx force:data:soql:query --targetusername=$TARGETDEVHUBUSERNAME --usetoolingapi \
        --query="SELECT $PACKAGE_QUERY_FIELDS FROM Package2Version WHERE Package2.Name = '$1' ORDER BY LastModifiedDate DESC, CreatedDate DESC LIMIT 1" \
        --json)
    echo $QUERY_RESULT
}

function createVersion() {
    readPackageParams "$@"
    local CMD_CREATE="sfdx force:package:version:create --path=$SOURCEPATH --package=$PACKAGE \
        --tag=$COMMITTAG --targetdevhubusername=$TARGETDEVHUBUSERNAME --definitionfile=$DEFINITIONFILE "
    if [ "$USE_SFDX_BRANCH" = "true" ]
    then
        CMD_CREATE+="--branch=$CURRENT_BRANCH "
    else
        CMD_CREATE+="--versiondescription=$CURRENT_BRANCH "
    fi
    CMD_CREATE+="--codecoverage --installationkeybypass --json"
    echo "Initiating package creation.."
    echo $CMD_CREATE
    local RESP_CREATE=$(echo $($CMD_CREATE)) # create package and collect response
    handleSfdxResponse "$RESP_CREATE"
    local JOBID=$(echo $RESP_CREATE | jq -r ".result.Id")
    echo "Initilised with job id: $JOBID"
    while true
    do
        RESP_REPORT=$(echo $(sfdx force:package:version:create:report --targetdevhubusername=$TARGETDEVHUBUSERNAME --packagecreaterequestid=$JOBID --json))
        if [ "$(echo $RESP_REPORT | jq -r ".status")" = "1" ]
        then
            handleSfdxResponse "$RESP_REPORT"
            break
        else
            local REQ_STATUS=$(echo $RESP_REPORT | jq -r ".result[0].Status")
            if [ $REQ_STATUS = "Success" ]
            then
                echo "Package creation successful.."
                SUBSCRIBER_PACKAGE_VERSION=$(echo $RESP_REPORT | jq -r ".result[0].SubscriberPackageVersionId")
                echo "Created subscriber version id $SUBSCRIBER_PACKAGE_VERSION"
                local VERSION_REPORT=$(echo $(sfdx force:package:version:report --targetdevhubusername=$TARGETDEVHUBUSERNAME --package=$SUBSCRIBER_PACKAGE_VERSION --json --verbose))
                handleSfdxResponse "$VERSION_REPORT"
                sendNotification --statuscode "0" \
                    --message "Package creation successful" \
                    --details "New beta version of $VERSIONNUMBER for $PACKAGE created successfully with following details.
                        <BR/><b>Package Id</b> - $(echo $VERSION_REPORT | jq -r ".result.Package2Id")
                        <BR/><b>Subscriber Package VersionId</b> - $(echo $VERSION_REPORT | jq -r ".result.SubscriberPackageVersionId")
                        <BR/><b>Package Version</b> - $(echo $VERSION_REPORT | jq -r ".result.Version")
                        <BR/><b>Ancestor Version Id</b> - $(echo $VERSION_REPORT | jq -r ".result.AncestorId")
                        <BR/><b>Ancestor Version</b> - $(echo $VERSION_REPORT | jq -r ".result.AncestorVersion")
                        <BR/><b>Package Release Version</b> - $(echo $VERSION_REPORT | jq -r ".result.ReleaseVersion")
                        <BR/><b>CommitId</b> - $(echo $VERSION_REPORT | jq -r ".Tag")
                        <BR/><b>Code Coverage</b> - $(echo $VERSION_REPORT | jq -r ".result.CodeCoverage.apexCodeCoveragePercentage")
                        <BR/><b>Code Coverage check passed</b> - $(echo $VERSION_REPORT | jq -r ".result.HasPassedCodeCoverageCheck")
                        <BR/><b>Is Validation Skipped?</b> - $(echo $VERSION_REPORT | jq -r ".result.ValidationSkipped")"
                break
            else
                sleep 5
                echo "Request status $REQ_STATUS"
                RESP_REPORT=$($CMD_REPORT)
            fi
        fi
    done
}

function createPackage() {
    readParams "$@"

    RESPONS=$(sfdx force:package:create --path=$SOURCEPATH --name=$PACKAGENAME \
        --description=$DESCRIPTION --packagetype=$PACKAGETYPE --targetdevhubusername=$TARGETDEVHUBUSERNAME --json)
    echo $RESPONSE
    #TODO: ON SUCCESS COMMIT SFDX JSON AND CREATE VERSION
}

function isUpgrade() {
    local IS_REQUEST_UPGRADE=1
    DH_VERSION=$1
    SFDXJ_VERSION=$2
    iterator=0
    for eachVersion in "${DH_VERSION[@]}";
    do
        if [ "$eachVersion" -lt "${SFDXJ_VERSION[iterator]}" ]
        then
            IS_REQUEST_UPGRADE=0
            break;
        fi
        iterator=$((iterator+1))
    done
    echo $IS_REQUEST_UPGRADE
}

function checkDependencyVersions() {
    local VERSIONS_PACKAGE=$(echo $2 | jq -r ".packageDirectories | map(select(.package == \"$1\")) | .[0].dependencies")
    local ARRAY=($(echo $VERSIONS_PACKAGE | jq -r '.[] | keys[] as $k | "\(.[$k])"'))
    VERSION_MISMATCH=0
    for ((iterator=0; iterator<${#ARRAY[@]}; iterator++))
    do
        local DEP_PACKAGE=${ARRAY[iterator]}
        # query in loop due to restrictions on the object
        local DEV_HUB_VERSION=$(queryPackageByName $DEP_PACKAGE | jq -r '"\(.result.records[0].MajorVersion)"+"."+"\(.result.records[0].MinorVersion)"+"."+"\(.result.records[0].PatchVersion)"')
        iterator=$((iterator+1)) # access version
        local SFDX_JSON_VERSION=$(echo ${ARRAY[iterator]} | cut -d "." -f1,2,3)
        if [ "$DEV_HUB_VERSION" != "$SFDX_JSON_VERSION" ]
        then
            VERSION_MISMATCH=1
            echo "Dependencies version in sfdx project json ($SFDX_JSON_VERSION) do not match with latest Devhub version ($DEV_HUB_VERSION) for package $DEP_PACKAGE"
        fi
    done

    if [ "$VERSION_MISMATCH" = "1" ] 
    then
        if [ "$DEPDENCY_VAL" = "true" ]
        then
            echo "ERROR! One or more dependency package versions are not upgraded to latest versions. Exiting.."
            sendNotification --statuscode "1" --message "Dependency package versions not upgraded" \
                        --details "One or more dependency package versions for $1 are not upgraded to latest available devhub version. Please check logs for more details."
        else
            echo "WARNING! One or more dependency package versions are not upgraded to latest versions"
        fi
    fi
}