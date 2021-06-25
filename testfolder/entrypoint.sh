#!/bin/sh

echo "Hello $1"
echo "Hello $2"
time=$(date)
echo "::set-output name=time::$time"
# setting path, this is not working in actions runner
PATH=~/sfdx/bin:$PATH
# creating  alias in case path is not set in actions runner
alias sfdx=/root/sfdx/bin/sfdx
which jq
jq --version
#which sfdx
/root/sfdx/bin/sfdx --version

sfdx --version
echo "Current"
ls -l
echo "github"
ls -l /github
echo "github/home"
ls -l /github/home
echo "github/workflow"
ls -l /github/workflow
echo "github/workspace"
ls -l /github/workspace
echo "../"
ls -l ../
echo "../../"
ls -l ../../
echo "/root"
ls -l /root/
echo "/root/root"
ls -l /root/root

TARGETDEVHUBUSERNAME="devhubuser"
echo "Authorize Devhub..."
echo $TARGETDEVHUBUSERNAME
echo $1 > /root/secrets/devhub.txt
sfdx auth:sfdxurl:store --sfdxurlfile=/root/secrets/devhub.txt --setalias=$TARGETDEVHUBUSERNAME
sfdx force:org:list --all