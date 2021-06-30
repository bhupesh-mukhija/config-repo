#!/bin/sh
source "/github/workspace/config/scripts/bash/utility.sh"
source "/github/workspace/config/scripts/ci/createPackage.sh"

# setting path, this is not working in actions runner
PATH=/root/sfdx/bin:$PATH
sfdx --version

authorizeDevHub $1
packageCreate