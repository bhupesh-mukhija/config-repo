#!/bin/sh
source "/github/workspace/config/scripts/bash/utility.sh"
source "/github/workspace/config/scripts/ci/createPackage.sh"

# setting path, this is not working in actions runner
PATH=/root/sfdx/bin:$PATH
sfdx --version

ls -l
ls -l /github/workspace
ls -l /github/workspace/config
ls -l /github/workspace/config/scripts

authorizeDevHub $1
packageCreate