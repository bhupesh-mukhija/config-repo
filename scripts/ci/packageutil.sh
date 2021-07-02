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
    readParams "$@"
    local CMD_CREATE="sfdx force:package:version:create --path=$SOURCEPATH --package=$PACKAGENAME \
        --tag=$COMMITTAG --targetdevhubusername=$TARGETDEVHUBUSERNAME --wait=$WAIT \
        --definitionfile=$DEFINITIONFILE --codecoverage --installationkeybypass --json"
    echo "Initiating package creation.."
    echo $CMD_CREATE
    local RESPONSE_CREATE=$(echo $($CMD_CREATE))
    echo $RESPONSE_CREATE
    handleSfdxResponse $RESPONSE_CREATE
    local JOBID=$(echo $RESPONSE_CREATE | jq -r ".result[0].Id")
    echo "Initilised with job id: $JOBID"
    echo $CMD_REPORT="sfdx force:package:version:create:report --targetdevhubusername=$TARGETDEVHUBUSERNAME --packagecreaterequestid=$JOBID --json"
    while true
    do
        RESPONSE_REPORT=$($CMD_REPORT)
        if [ $(echo $RESPONSE_REPORT | jq -r ".status") = "1" ]
        then
            handleSfdxResponse $RESPONSE_REPORT
            break
        else
            local REQ_STATUS=$(echo $RESPONSE_REPORT | jq -r ".result[0].Status")
            if [ $REQ_STATUS = "Success" ]
            then
                sendNotification --statuscode "0" \
                    --message "Package creation successful" \
                    --details "New beta version of $VERSIONNUMBER for $PACKAGE created successfully with following details. \n\r $(echo $RESPONSE_REPORT | jq -r ".result[0].Status")"
                break
            else
                sleep 5
                echo "Request status $REQ_STATUS"
                RESPONSE_REPORT=$($CMD_REPORT)
            fi
        fi
        break;
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