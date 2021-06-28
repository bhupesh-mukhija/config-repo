#!/bin/bash
queryPackageByName() {
    local PACKAGE_QUERY_FIELDS=" Id, Name, Package2Id, Tag, Package2.Name, SubscriberPackageVersion.Dependencies, IsReleased, MajorVersion, MinorVersion, PatchVersion, CreatedDate, LastModifiedDate, AncestorId, Ancestor.MajorVersion, Ancestor.MinorVersion, Ancestor.PatchVersion "
    local QUERY_RESULT=$(sfdx force:data:soql:query -u $TARGETDEVHUBUSERNAME -t \
        -q "SELECT $PACKAGE_QUERY_FIELDS FROM Package2Version WHERE Package2.Name = '$1' ORDER BY LastModifiedDate DESC, CreatedDate DESC LIMIT 1" \
        --json)
    echo $QUERY_RESULT
}

# setting path, this is not working in actions runner
PATH=~/sfdx/bin:$PATH
# creating alias in case path is not set in actions runner
alias sfdx=/root/sfdx/bin/sfdx
sfdx --version
/root/sfdx/bin/sfdx --version
TARGETDEVHUBUSERNAME="devhubuser"
# TODO: DISABLE FOR ACTION
#TARGETDEVHUBUSERNAME="sagegroup"
echo "Authorize Devhub..."
echo $1 > /root/secrets/devhub.txt
sfdx auth:sfdxurl:store --sfdxurlfile=/root/secrets/devhub.txt --setalias=$TARGETDEVHUBUSERNAME
SFDX_JSON=$(</github/workspace/sfdx-project.json)
# TODO: DISABLE FOR ACTION
#SFDX_JSON=$(<../../sfdx-project.json)
P_NAME=$(jq ".name" <<< $SFDX_JSON)
# TODO: DISABLE FOR ACTION
#P_NAME="salesforce-global-sales"
PACKAGE_INFO=$(queryPackageByName $P_NAME)
echo $PACKAGE_INFO
echo "**************************************************************************************************"
#QUERY_STATUS=$(jq ".status" <<< $PACKAGE_INFO)
if [ "$(jq ".status" <<< $PACKAGE_INFO)" = "1" ]
then
    echo "Query Error FAIL THE JOB"
    echo $(jq ".name,.message,.stack" <<< $PACKAGE_INFO)
    exit 1
    # TODO: ERROR HANDLING - send emails or post to teams channel
else
    echo "PACKAGE QUERY SUCCESSFUL"
    #RETURN_SIZE=$(jq ".result.totalSize" <<< $PACKAGE_INFO)
    if [ "$(jq ".result.totalSize" <<< $PACKAGE_INFO)" = "0" ]
    then
        echo "$P_NAME not found"
        # TODO: CREATE PACKAGE BEFORE CREATING VERSION
    else
        echo "$P_NAME found, continue to create package version"
        P_VERSION_DEVHUB=$(jq -r '"\(.result.records[0].MajorVersion)"+"."+"\(.result.records[0].MinorVersion)"+"."+"\(.result.records[0].PatchVersion)"' <<< $PACKAGE_INFO)
        echo $P_VERSION_DEVHUB
        P_VERSION_SFDX_JSON=$(cut -d "." -f1,2,3 <<< $(jq -r ".packageDirectories | map(select(.package == \"$P_NAME\")) | .[0].versionNumber" <<< $SFDX_JSON))
        echo $P_VERSION_SFDX_JSON
        echo $(jq -r ".result.records[0].IsReleased" <<< $PACKAGE_INFO)
        #if [ $P_VERSION_DEVHUB = $P_VERSION_SFDX_JSON ] && [ $(jq -r ".result.records[0].IsReleased" <<< $PACKAGE_INFO) = "true" ];
        if [ $P_VERSION_DEVHUB = $P_VERSION_SFDX_JSON ]
        then
            echo "Devhub version equals sfdx json version"
            if [ $(jq -r ".result.records[0].IsReleased" <<< $PACKAGE_INFO) = "true" ]
            then
                # TODO: generate error: requested version already have a released major.minor.patch
                echo "ERROR: Requested version is already released, please update and rerun the job"
            fi
        else
            echo "Devhub version not equals sfdx json version"
        fi
    fi
fi