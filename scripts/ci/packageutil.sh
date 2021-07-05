#!/bin/bash
source "/github/workspace/config/scripts/ci/globalutil.sh"

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
    local QUERY_RESULT=$(sfdx force:data:soql:query -u $TARGETDEVHUBUSERNAME -t \
        -q "SELECT $PACKAGE_QUERY_FIELDS FROM Package2Version WHERE Package2.Name = '$1' ORDER BY LastModifiedDate DESC, CreatedDate DESC LIMIT 1" \
        --json)
    echo $QUERY_RESULT
}

function createVersion() {
    readPackageParams "$@"
    local CMD_CREATE="sfdx force:package:version:create --path=$SOURCEPATH --package=$PACKAGE \
        --tag=$COMMITTAG --targetdevhubusername=$TARGETDEVHUBUSERNAME \
        --definitionfile=$DEFINITIONFILE --codecoverage --installationkeybypass --json"
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
                local P_SUB_VERSIONID=$(echo $RESP_REPORT | jq -r ".result[0].SubscriberPackageVersionId")
                echo "Created subscriber version id $P_SUB_VERSIONID"
                local VERSION_REPORT=$(echo $(sfdx force:package:version:report --targetdevhubusername=$TARGETDEVHUBUSERNAME --package=$P_SUB_VERSIONID --json --verbose))
                handleSfdxResponse "$VERSION_REPORT"
                sendNotification --statuscode "0" \
                    --message "Package creation successful" \
                    --details "New beta version of $VERSIONNUMBER for $PACKAGE created successfully with following details.
                        <BR/><b>Package Id</b> - $(echo $VERSION_REPORT | jq -r ".Package2Id")
                        <BR/><b>Subscriber Package VersionId</b> - $(echo $RESP_REPORT | jq -r ".SubscriberPackageVersionId")
                        <BR/><b>Package Version</b> - $(echo $RESP_REPORT | jq -r ".Version")
                        <BR/><b>Ancestor Version Id</b> - $(echo $RESP_REPORT | jq -r ".AncestorId")
                        <BR/><b>Ancestor Version</b> - $(echo $RESP_REPORT | jq -r ".AncestorVersion")
                        <BR/><b>Package Release Version</b> - $(echo $RESP_REPORT | jq -r ".ReleaseVersion")
                        <BR/><b>CommitId</b> - $(echo $RESP_REPORT | jq -r ".Tag")
                        <BR/><b>Code Coverage</b> - $(echo $RESP_REPORT | jq -r ".CodeCoverage.apexCodeCoveragePercentage")
                        <BR/><b>Code Coverage check passed</b> - $(echo $RESP_REPORT | jq -r ".HasPassedCodeCoverageCheck")
                        <BR/><b>Is Validation Skipped?</b> - $(echo $RESP_REPORT | jq -r ".ValidationSkipped")"
                break
            else
                sleep 2
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