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
echo "Current"
ls -l
echo "github"
ls -l /github
echo "github/home"
ls -l /github/home
echo "github/workflow"
ls -l /github/workflow
echo "../"
ls -l ../
echo "../../"
ls -l ../../