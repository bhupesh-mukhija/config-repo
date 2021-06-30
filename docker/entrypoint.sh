#!/bin/sh
# add bash files from config repo
source "/github/workspace/config/scripts/bash/utility.sh"
source "/github/workspace/config/scripts/ci/createPackage.sh"

# set path for sfdx
PATH=/root/sfdx/bin:$PATH
sfdx --version
sfdx plugins --core

TARGETDEVHUBUSERNAME="devhubuser"
authorizeOrg $1 $TARGETDEVHUBUSERNAME
packageCreate