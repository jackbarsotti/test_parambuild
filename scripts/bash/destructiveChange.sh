#!/bin/bash
exec 1>/tmp/test
# inputs:
#deploydir updated with subdirectory "deployment", which is our new deployment package(s) parent dir:
export DEPLOYDIR=/var/lib/jenkins/workspace/parambuild_${deployBranchURL}/github-checkout/force-app/main/default/deployment
#create destructivePackage folder (incremental build creates incrementalPackage folder within same deploydir):
export destructivePackagePath=$DEPLOYDIR/destructivePackage
#diff files will be moved into the classes folder:
export SOURCE_PATH=$destructivePackagePath/classes
export API_VERSION=49.0 # api version (same as in the sfdx-project.json)

# Copy D files from git diff to destructive changes folder
  #originally: git log --oneline --diff-filter=D --summary
  #can interchangeably use: git diff --name-only --pretty="" test
  #using git diff-tree instead because the output is much shorter (only file names) and therefore easier to use:
git diff-tree --no-commit-id --name-only -r HEAD --diff-filter=D |
  while read -r file; do
    sudo cp "$file" $SOURCE_PATH 2>/dev/null
  done

echo "Converting Source format to Metadata API format"
#convert existing git diff files in the classes folder into metadata api format
sfdx force:source:convert -p $SOURCE_PATH -d $SOURCE_PATH

# copy package.xml to destructiveChangesPre.xml
cp manifest/package.xml $destructivePackagePath/destructiveChangesPre.xml

# generate an empty (containing only the api version tag) package.xml (why?)
cat <<EOT > $destructivePackagePath/package.xml
<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
  <version>${API_VERSION}</version>
</Package>
EOT