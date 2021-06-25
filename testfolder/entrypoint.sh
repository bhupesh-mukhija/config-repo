#!/bin/sh

echo "Hello $1"
echo "Hello $2"
time=$(date)
echo "::set-output name=time::$time"
PATH=~/sfdx/bin:$PATH
which jq
jq --version
#which sfdx
/root/sfdx/bin/sfdx --version
ls -l
ls -l /github/home
ls -l /github/workflow