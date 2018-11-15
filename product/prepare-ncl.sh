#!/bin/bash -xe
# script to ensure latest bits are fetched from this repo, so we can reuse scripts in another repo (eg., use build-ncl.sh to build che, not just codeready-workspaces)
 
git --no-pager log --graph --pretty=format:'%h -%d %s %aE (%cr)' --abbrev-commit --date=relative --color=never | head -10
