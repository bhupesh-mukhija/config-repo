#!/bin/bash
# add bash files from config repo
source "/github/workspace/config/scripts/bash/utility.sh"
source "/github/workspace/config/scripts/ci/createPackage.sh"

# set path for sfdx
PATH=/root/sfdx/bin:$PATH
sfdx --version
sfdx plugins --core

echo "Opertion parameter : $2"
TARGETDEVHUBUSERNAME="devhubuser"
authorizeOrg $1 $TARGETDEVHUBUSERNAME
packageCreate