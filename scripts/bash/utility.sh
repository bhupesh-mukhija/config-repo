#!/bin/sh
function readParams {
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
            -u|--targetusername) # matching argument with sfdx standards
                TARGETUSERNAME="$2"
                shift # past argument
                shift # past value
            ;;
            -sp|--sourcepath) #matching argument with sfdx standards
                SOURCEPATH="$2"
                shift # past argument
                shift # past value
            ;;
            -a|--setalias)
                SETALIAS="$2"
                shift # past argument
                shift # past value
            ;;
            -d|--durationdays)
                DURATIONDAYS="$2"
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
            -vd|--versiondescription)
                VERSIONDESCRIPTION="$2"
                shift # past argument
                shift # past value
            ;;
            -vd|--versiondescription)
                VERSIONDESCRIPTION="$2"
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
            --runfromci) # Switch parameter with no values
                RUNFROMCI=TRUE
                shift # past argument
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

function authorizeOrg() {
    echo "Authorizing org..."
    echo $1 > /root/secrets/devhub.txt
    sfdx auth:sfdxurl:store --sfdxurlfile=/root/secrets/devhub.txt --setalias=$2
}

function createVersion() {
    readParams "$@"

    echo $(sfdx force:package:version:create --path=$SOURCEPATH --package=$PACKAGE \
        --tag=$COMMITTAG --targetdevhubusername=$TARGETDEVHUBUSERNAME --wait=$WAIT \
        --definitionfile=$DEFINITIONFILE --codecoverage --installationkeybypass --json)
}

function sendTeamsNotification() {
    WEBHOOK_URL="https://sage365.webhook.office.com/webhookb2/1684ded0-b7a0-46f0-af48-d46b403ea75b@3e32dd7c-41f6-492d-a1a3-c58eb02cf4f8/IncomingWebhook/42190d8ce99e4602af2d5c9e8ead3157/29be0f97-c2eb-4d1f-8b31-93c80f2b466e"


    JSON="{\"title\": \"HERE\", \"themeColor\": \"RED\", \"text\": \"MESSGE TEAMS\" }"

    # Post to Microsoft Teams.
    curl -H "Content-Type: application/json" -d "${JSON}" "${WEBHOOK_URL}"
}