#!/bin/bash
exec 1>/tmp/test
#deploydir updated with subdirectory "deployment", which is our new deployment package(s) parent dir:
export DEPLOYDIR=/var/lib/jenkins/workspace/pipeline_${deployBranchURL}/github-checkout/force-app/main/default/deployment
#create incrementalPackage folder within deploydir
export incrementalPackagePath=$DEPLOYDIR/incrementalPackage
#diff files will be moved into the classes folder:
export SOURCE_PATH=$incrementalPackagePath/classes
export classPath=/var/lib/jenkins/workspace/parambuild_${deployBranchURL}/github-checkout/force-app/main/default/classes
export triggerPath=/var/lib/jenkins/workspace/parambuild_${deployBranchURL}/github-checkout/force-app/main/default/triggers

# Git Diff Section:

#using git diff-tree instead because the output is much shorter (only file names) and therefore easier to use:
#can interchangeably use: git diff --name-only --pretty="" test
#git diff-tree --no-commit-id --diff-filter=UMA --name-only -r HEAD | 
git diff --name-only --pretty="" --diff-filter=UMA master |
while read -r file; do
  # Copy the files from git diff into the deploy directory:
  sudo cp --parents $file $SOURCE_PATH 2>/dev/null
  # For any changed class or trigger file it's associated meta data file is copied to the deploy directory (and vice versa):
  if [[ $file == *.cls ]]; then
    find $classPath -samefile "$file-meta.xml" -exec sudo cp --parents -t $SOURCE_PATH {} \;
  elif [[ $file == *.cls-meta.xml ]]; then
    parsedfile=${file%.cls-meta.xml}
    find $classPath -samefile "$parsedfile.cls" -exec sudo cp --parents -t $SOURCE_PATH {} \;
  elif [[ $file == *.trigger ]]; then
    find $triggerPath -samefile "$file-meta.xml" -exec sudo cp --parents -t $SOURCE_PATH {} \;
  elif [[ $file == *.trigger-meta.xml ]]; then
    parsedfile=${file%.trigger-meta.xml}
    find $triggerPath -samefile "$parsedfile.trigger" -exec sudo cp --parents -t $SOURCE_PATH {} \;
  fi
done 

echo "Converting Source format to Metadata API format"
sfdx force:source:convert -p $SOURCE_PATH -d $SOURCE_PATH

#Need to generate package xml here with the above files
