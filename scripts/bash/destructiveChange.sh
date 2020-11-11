#!/bin/bash

#What is this:
#exec 1>/tmp/test

# Inputs:

export API_VERSION=49.0 # api version (same as in the sfdx-project.json)
#deploydir updated with subdirectory "deployment", which is our new deployment package(s) parent dir:
mkdir -p /Users/jackbarsotti/test_parambuild//force-app/main/default/deployment/destructivePackage/classes
export DEPLOYDIR=/var/lib/jenkins/workspace/pipeline_${deployBranchURL}/github-checkout/force-app/main/default/deployment

#create destructivePackage folder (incremental build creates incrementalPackage folder within same deploydir):
export destructivePackagePath=$DEPLOYDIR/destructivePackage

#diff files will initially be moved into the classes folder:
export SOURCE_PATH=$destructivePackagePath/classes


# Git Diff:

git diff --name-only --pretty="" --diff-filter=D master |
  while read -r file; do
    sudo cp $file $SOURCE_PATH 2>/dev/null #copy D files from git diff to destructive changes folder
  done

#Several git diff commands could be used:
  #git log --oneline --diff-filter=D --summary |
    #shows all recent commits with D files that have not been pushed
    
  #git diff-tree --no-commit-id --name-only -r HEAD --diff-filter=D |
    #output is much shorter (only file names), use when diff files were deleted during the previous commit
    
  #git diff --name-only --pretty="" --diff-filter=D master |
    #best for when D files weren't deleted on the most recent commit


# Create destructive package:

echo "Converting Source format to Metadata API format"
#convert existing git diff files in the classes folder into metadata api format:
sfdx force:source:convert -p $SOURCE_PATH -d $SOURCE_PATH

#copy package.xml to destructiveChangesPre.xml:
cp manifest/package.xml $destructivePackagePath/destructiveChangesPre.xml

# generate an empty (containing only the api version tag) package.xml (why?)
cat <<EOT > $destructivePackagePath/package.xml
<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
  <version>${API_VERSION}</version>
</Package>
EOT