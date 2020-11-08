#!groovy
pipeline { 
    agent any

    options {
       timeout(time: 5, unit: 'MINUTES')  // timeout all agents on pipeline if not complete in 5 minutes or less.

    }

    parameters {
        //Line 12 errors:
        gitParameter(branchFilter: 'origin/(.*)', defaultValue: 'master', name: 'source_branch', type: 'PT_BRANCH', description: 'Select a branch to build from')
        choice(name: 'target_environment',
            choices: getSFEvnParams(),
            description: 'Select a Salesforce Org to build against')
        booleanParam(name: 'validate_only_deploy',
            defaultValue: true,
            description: 'Check this to run a validate only deploy')
        choice(name: 'test_level',
            choices: 'NoTestRun\nRunSpecifiedTests\nRunLocalTests',
            description: 'Set the Test Level for this Build')
        string(name: 'specified_tests',
            defaultValue: 'ex: ClassTest,Class2Test',
            description: 'If Test Level is "RunSpecifiedTests" then specify a comma seperated list of test classes to run. Ex: "AccountTriggerHandlerTest,LeadTriggerHandlerTest"')
    }
    
    stages {
        stage('Initializing') {
            steps {
                echo "Initializing"
                // determine if the build was trigger from a git event or manually built with parameters
                echo "${currentBuild.buildCauses}"
                // all current build environment variables
                echo sh(returnStdout: true, script: 'env')
            }
        }
        stage('GitHub Sync Target Branch') {
            steps {  
                echo "GitHub Sync Target Branch"
                githubCheckout()
            }
        }
        //NEW:
        stage('Create Build Packages') {
            steps {
                catchError(buildResult: 'FAILURE', stageResult: 'FAILURE'){
					buildIncrementalPackage()
				}
                catchError(buildResult: 'FAILURE', stageResult: 'FAILURE'){
				    buildDestructivePackage()
			    }
                echo "Creating incremental package.xml"
                buildIncrementalPackage()
                echo "Creating destructingChanges.xml"
                buildDestructivePackage()
                //Or would we be able to execute .sh scripts above? "sh './script.sh'"
            }
        }
        //NEW:
        //stage('Push New Packages Branch') {
        //    steps {
        //        catchError(buildResult: 'FAILURE', stageResult: 'FAILURE'){
		//		    pushPackages()
		//	    }
        //        echo "Pushing new branch with packages"
        //        pushPackages()
        //    }
        //}
        stage('SFDX Auth Target Org') {
            steps {
                authSF()
            }
        }
        stage('SFDX Deploy Target Org') {
            steps {  
                echo "Deploy Running ${env.BUILD_ID} on ${env.JENKINS_URL}"
                salesforceDeploy()
            }
        }
        // s3 
        // selenium
        // slack, email
    }
}

def salesforceDeploy() {
    
    def varsfdx = tool 'sfdx'
    rc2 = command "${varsfdx}/sfdx force:auth:sfdxurl:store -f authjenkinsci.txt -a targetEnvironment"
    if (rc2 != 0) {
       echo " 'SFDX CLI Authorization to target env has failed.'"
    }

    def TEST_LEVEL='NoTestRun'
    def VALIDATE_ONLY = false
    //def deployBranchURL = ""
    //if("${env.BRANCH_NAME}".contains("/")) {
    //    deployBranchURL = "${env.BRANCH_NAME}".replace("/", "_")
    //}
    //else {
    //    deployBranchURL = "${env.BRANCH_NAME}"
    //}

    //def DEPLOYDIR="/var/lib/jenkins/workspace/parambuild_${deployBranchURL}/github-checkout/force-app/main/default/deployment"    
        // added to deploydir
    //echo DEPLOYDIR
    def SF_INSTANCE_URL = "https://login.salesforce.com"

    dir("${DEPLOYDIR}") {
        if ("${currentBuild.buildCauses}".contains("UserIdCause")) {
            def deploy_script = "force:source:deploy --wait 10"
            if(params.validate_only_deploy) {
                deploy_script += " -c"
            }
            deploy_script += " --sourcepath ${DEPLOYDIR}"
            if("${params.test_level}".contains("RunSpecifiedTests")) {
                deploy_script += " --testlevel ${params.test_level} -r ${params.specified_tests}"
            }
            else {
                deploy_script += " --testlevel ${params.test_level}"
            }
            deploy_script += " -u targetEnvironment --json"

            echo deploy_script
            rc4 = command "${varsfdx}/sfdx " + deploy_script
        }
        else if("${currentBuild.buildCauses}".contains("BranchEventCause")) {
            if (env.CHANGE_ID == null && env.VALIDATE_ONLY == false){
                rc4 = command "${varsfdx}/sfdx force:source:deploy --wait 10 --sourcepath ${DEPLOYDIR} --testlevel ${TEST_LEVEL} -u targetEnvironment --json"         
            }
            else{
                rc4 = command "${varsfdx}/sfdx force:source:deploy --wait 10 --sourcepath ${DEPLOYDIR} --testlevel ${TEST_LEVEL} -u targetEnvironment --json"
            }
        }
 
        if ("$rc4".contains("0")) {
            echo "successful sfdx source deploy from X to X"
        } 
        else {
           currentBuild.result = 'FAILURE'
           echo "$rc4"
        }
    }
}

def authSF() {
    echo 'SF Auth method'
    def SF_AUTH_URL
    echo env.BRANCH_NAME

    if ("${currentBuild.buildCauses}".contains("UserIdCause")) {
        def fields = env.getEnvironment()
        fields.each {
            key, value -> if("${key}".contains("${params.target_environment}")) { SF_AUTH_URL = "${value}"; }
        }
    }
    else if("${currentBuild.buildCauses}".contains("BranchEventCause")) {
        if(env.BRANCH_NAME == 'master' || env.CHANGE_TARGET == 'master') {
            SF_AUTH_URL = env.SFDX_AUTH_URL
            //SF_AUTH_URL = env.SFDX_DEV
        }
        else { // {PR} todo - better determine if its a PR env.CHANGE_TARGET?
            SF_AUTH_URL = env.SFDX_AUTH_URL
            //SF_AUTH_URL = env.SFDX_DEV
        }
    }

    echo 'SF_AUTH_URL:'
    echo SF_AUTH_URL
    writeFile file: 'authjenkinsci.txt', text: SF_AUTH_URL
    sh 'ls -l authjenkinsci.txt'
    sh 'cat authjenkinsci.txt'
    echo 'end sf auth method'
}

def githubCheckout() {
    dir('github-checkout') {
        // determine if the build was trigger from a git event or manually built with parameters
        // [[_class:jenkins.branch.BranchEventCause, shortDescription:Branch event]]
        // [[_class:hudson.model.Cause$UserIdCause, shortDescription:Started by user JenkinsAdmin, userId:jenkins_ubuntu, userName:JenkinsAdmin]]
        if ("${currentBuild.buildCauses}".contains("UserIdCause")) {
            echo "git checkout ${params.source_branch}"
            git credentialsId: 'gh_unpw2', url:'https://github.com/jackbarsotti/test_parambuild.git', branch: "${params.source_branch}"
        }
        else if("${currentBuild.buildCauses}".contains("BranchEventCause")) {
            echo "git checkout ${env.BRANCH_NAME}"
            checkout scm
        }
        gitDiff = sh(returnStdout: true, script: 'git diff-tree --no-commit-id --name-only -r HEAD').trim().tokenize(',')
        echo "github-checkout"
        echo "Commit Changeset Size: ${gitDiff.size()}"
        echo "Commit Changeset: ${gitDiff}"
        
    }

    sh 'ls github-checkout'
    echo "Current GIT Commit : ${env.GIT_COMMIT}"
    echo "Previous Known Successful GIT Commit : ${env.GIT_PREVIOUS_SUCCESSFUL_COMMIT}"
}

//NEW: method 1
def buildIncrementalPackage() {
    def deployBranchURL = ""
    if("${env.BRANCH_NAME}".contains("/")) {
        deployBranchURL = "${env.BRANCH_NAME}".replace("/", "_")
    }
    else {
        deployBranchURL = "${env.BRANCH_NAME}"
    }
    def DEPLOYDIR="/var/lib/jenkins/workspace/parambuild_${deployBranchURL}/github-checkout/force-app/main/default/deployment"    
        // added to deploydir
    echo DEPLOYDIR
    dir("${DEPLOYDIR}/deployment/incrementalPackage/classes") {
        // created deployment directory structure
        //sh '/var/lib/jenkins/workspace/parambuild_${deployBranchURL}/github-checkout/scripts/incrementalBuild.sh'
        def sout = new StringBuffer(), serr = new StringBuffer()
        def proc ="sh /var/lib/jenkins/workspace/parambuild_${deployBranchURL}/github-checkout/scripts/bash/incrementalBuild.sh".execute()
            // execute the incremental script
        proc.consumeProcessOutput(sout, serr)
        proc.waitForOrKill(1000)
    }
}   
//NEW: method 2
def buildDestructivePackage() {
    def deployBranchURL = ""
    if("${env.BRANCH_NAME}".contains("/")) {
        deployBranchURL = "${env.BRANCH_NAME}".replace("/", "_")
    }
    else {
        deployBranchURL = "${env.BRANCH_NAME}"
    }
    def DEPLOYDIR="/var/lib/jenkins/workspace/parambuild_${deployBranchURL}/github-checkout/force-app/main/default/deployment"
    dir("${DEPLOYDIR}/deployment/destructivePackage/classes") {
        // created deployment directory structure with destructive package folder
        //sh '/var/lib/jenkins/workspace/parambuild_${deployBranchURL}/github-checkout/scripts/destructiveChange.sh'
        def sout = new StringBuffer(), serr = new StringBuffer()
        def proc ="sh /var/lib/jenkins/workspace/parambuild_${deployBranchURL}/github-checkout/scripts/bash/destructiveChange.sh".execute()
            //execute the destructive build script
        proc.consumeProcessOutput(sout, serr)
        proc.waitForOrKill(1000)
    }
}
//NEW: method 3
def pushPackages() {
    //create new branch called deploymentBranch${todaysDate}:
    todaysDate = sh "${date+'%m/%d/%Y'}"
    echo "git checkout -b deploymentBranch${todaysDate}"
    //push branch:
    sh '''
        git add force-app/.
        git commit -q -m "deployment packages created"
        echo "git push -u origin deploymentBranch${todaysDate}"
    '''
}

def getSFEvnParams() {
    def fields = env.getEnvironment()
    def output = "";
    fields.each {
        key, value -> if("${key}".startsWith("SFDX_")) { output += "${key}\n"; }
    }
    return output;
}

def command(script) {
   if (isUnix()) {
       return sh(returnStatus: true, script: script);
   } else {
       return bat(returnStatus: true, script: script);
   }
}