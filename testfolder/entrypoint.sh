#!/bin/sh

echo "Hello $1"
echo "Hello $2"
time=$(date)
echo "::set-output name=time::$time"
export PATH=~/sfdx/bin:$PATH
which jq
jq --version
which sfdx
sfdx --version