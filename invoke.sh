#!/bin/bash

set -e

aws_repo='https://github.com/amazon-archives/automating-governance-sample.git'  
nj_repo='https://github.com/nordcloud/notejam.git'
custom_repo='git@github.com:ncdemo2020/n1.git'
sources_target="$(echo $(pwd)/sources)"
assemble_target="$(echo $(pwd)/demo)"
aws_region=eu-west-1
s3_bucket_prefix=notejam-demo
operator_email=you@someplaceonline.com
stackname=notejam-demo
cicd_repo_target="$(echo $(pwd)/cicd-repos/$stackname-$aws_region)"
db_user=DBUser
ssh_keyname=somekeyname


die() {
    printf '%s\n' "$1" >&2
    exit 1
}

action=none
show_help()
{
    echo
    echo
    echo
    echo
    echo Assumptions and prerequisites:
    echo
    echo - access to a linux / bash shell, either natively, via docker, or Windows Subsystem for Linux
    echo
    echo - an aws account to deploy into, where you have 
    echo   an IAM user with administrator access - arn:aws:iam::aws:policy/AdministratorAccess
    echo   https://docs.aws.amazon.com/IAM/latest/UserGuide/getting-started_create-admin-group.html
    echo   you are anticipated to be using a sandbox or similar account.
    echo
    echo - the aws client installed and configured 
    echo   https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html
    echo
    echo
    echo A worked example of using this script to stand up an environment:
    echo
    echo ./invoke.sh --download \
--aws-region eu-west-2 \
--s3-bucket-prefix your-bucket-here \
--operator-email you@someplaceonline.com \
--cf-stackname-base your-stack-name \
--ec2-ssh-keyname somekeyname
    echo 
    echo ./invoke.sh --assemble \
--aws-region eu-west-2 \
--s3-bucket-prefix your-bucket-here \
--operator-email you@someplaceonline.com \
--cf-stackname-base your-stack-name \
--ec2-ssh-keyname somekeyname
    echo 
    echo ./invoke.sh --create-s3-bucket \
--aws-region eu-west-2 \
--s3-bucket-prefix your-bucket-here \
--operator-email you@someplaceonline.com \
--cf-stackname-base your-stack-name \
--ec2-ssh-keyname somekeyname
    echo
    echo ./invoke.sh --sync-s3-bucket \
--aws-region eu-west-2 \
--s3-bucket-prefix your-bucket-here \
--operator-email you@someplaceonline.com \
--cf-stackname-base your-stack-name \
--ec2-ssh-keyname somekeyname
    echo 
    echo ./invoke.sh --deploy-cf-stacks \
--aws-region eu-west-2 \
--s3-bucket-prefix your-bucket-here \
--operator-email you@someplaceonline.com \
--cf-stackname-base your-stack-name \
--ec2-ssh-keyname somekeyname
    echo 
}

while :; do
    case $1 in
        -h|-\?|--help)
            show_help    # Display a usage synopsis.
            exit
            ;;
        --download)
            action=download
            ;;
        --assemble)
            action=assemble
            ;;
        --create-s3-bucket)
            action=create-s3-bucket
            ;;
        --sync-s3-bucket)
            action=sync-s3-bucket
            ;;
        --deploy-cf-stacks)
            action=deploy-cf-stacks
            ;;
        --checkout-cicd-coderepo)
            action=checkout-cicd-coderepo
            ;;
        --aws-repo)
            if [ "$2" ]; then
                aws_repo=$2
                shift
            else
                die 'ERROR: "-c" requires a clone url, eg: https://github.com/amazon-archives/automating-governance-sample.git'
            fi
            ;; 
        --notejam-repo)
            if [ "$2" ]; then
                nj_repo=$2
                shift
            else
                die 'ERROR: "-n" requires a clone url, eg: https://github.com/nordcloud/notejam.git'
            fi
            ;; 
        --custom-repo)
            if [ "$2" ]; then
                nj_repo=$2
                shift
            else
                die 'ERROR: "-n" requires a clone url, eg: git@github.com:ncdemo2020/n1.git'
            fi
            ;; 
        --sources-target)
            if [ "$2" ]; then
                sources_target=$2
                shift
            else
                die 'ERROR: "-s" requires a local path, eg: ~/somefolder/sources'
            fi
            ;;     
        --assemble-target)
            if [ "$2" ]; then
                assemble_target=$2
                shift
            else
                die 'ERROR: "-s" requires a local path, eg: ~/somefolder/demo'
            fi
            ;;          
        --aws-region)
            if [ "$2" ]; then
                aws_region=$2
                shift
            else
                die 'ERROR: "-s" requires an aws region, eg: eu-west-1'
            fi
            ;; 
        --operator-email)
            if [ "$2" ]; then
                operator_email=$2
                shift
            else
                die 'ERROR: "-s" requires an email address, eg: you@someplaceonline.com'
            fi
            ;; 
        --s3-bucket-prefix)
            if [ "$2" ]; then
                s3_bucket_prefix=$2
                shift
            else
                die 'ERROR: "-s" requires an aws region, eg: notejam-demo'
            fi
            ;;
        --cf-stackname-base)
            if [ "$2" ]; then
                stackname=$2
                shift
            else
                die 'ERROR: "-s" requires a base name for aws stacks, eg: notejam-demo'
            fi
            ;;
        --ec2-ssh-keyname)
            if [ "$2" ]; then
                ssh_keyname=$2
                shift
            else
                die 'ERROR: "-s" requires the name of an existing ec2 ssh key - see https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html'
            fi
            ;;
        --)              # End of all options.
            shift
            break
            ;;
        -?*)
            printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
            ;;
        *)               # Default case: No more options, so break out of the loop.
            break
    esac
    shift
done




echo
echo 'We are working with:'
echo $sources_target

echo $assemble_target

echo $nj_repo
nj_repo_name=$(basename "$nj_repo" ".${nj_repo##*.}")
echo $nj_repo_name

echo $aws_repo
aws_repo_name=$(basename "$aws_repo" ".${aws_repo##*.}")
echo $aws_repo_name

echo $custom_repo
custom_repo_name=$(basename "$custom_repo" ".${custom_repo##*.}")
echo $custom_repo_name

echo $aws_region

echo $s3_bucket_prefix

echo $action
echo 

validate_installed_prereqs()
{
    echo
    echo 'Checking we have aws, jq, git, zip available on our path.'
    echo ' If this fails, it is up to you to make them available.'
    which aws
    which jq
    which git
    which zip
    echo 'Seems we have what we need...'
    echo
}

validate_installed_prereqs

while :; do
    case $action in
        download)
            echo "Downloading pre-reqs to $sources_target"
            mkdir -p $sources_target
            pushd $sources_target
            git clone $nj_repo
            git clone $aws_repo
            git clone $custom_repo
            popd
            
            ;;
        assemble)
            echo "putting things together..."
            # another approach would be git submodules, but that might be considered advanced git knowledge, so we avoid
            mkdir -p $assemble_target
            pushd $assemble_target
            cp -r $sources_target/$aws_repo_name/Bluegreen-AMI-Application-Deployment-blog/part1/* $assemble_target
            cp -r $sources_target/$aws_repo_name/Bluegreen-AMI-Application-Deployment-blog/part3/* $assemble_target 
            cp -r $sources_target/$custom_repo_name/* $assemble_target
            cp ./lambda/AutomationExecuteDocument.py .
            zip devsecops-part3.zip AutomationExecuteDocument.py
            rm ./AutomationExecuteDocument.py
            mkdir -p $cicd_repo_target
            popd
            ;;
        create-s3-bucket)
            echo "Creating S3 bucket $s3_bucket_prefix-$aws_region"
            aws s3 mb s3://$s3_bucket_prefix-$aws_region --region $aws_region
            ;;
        sync-s3-bucket)
            echo "Syncing S3 bucket $s3_bucket_prefix-$aws_region from $assemble_target"
            aws s3 sync $assemble_target s3://$s3_bucket_prefix-$aws_region --delete
            ;;
        deploy-cf-stacks)
            echo "Deploying Cloudformation Stacks"
            template="--template-body file://$assemble_target/cf/blog_template_part1_custom.json"
            stackparams="--parameters ParameterKey=LambdaS3Bucket,ParameterValue=$s3_bucket_prefix-$aws_region \
                ParameterKey=OperatorEMail,ParameterValue=$operator_email \
                ParameterKey=SSHkeyName,ParameterValue=$ssh_keyname \
                ParameterKey=DBUsername,ParameterValue=$db_user \
                ParameterKey=DBName,ParameterValue=$stackname "

            echo 'stackparams'
            echo $stackparams
            stackaction=create-stack

            stackcreation=$(aws cloudformation $stackaction \
                --stack-name $stackname \
                $template \
                $stackparams \
                --region $aws_region \
                --capabilities CAPABILITY_NAMED_IAM)

            stackid=$(echo $stackcreation | jq -r '.StackId')

            echo $stackid

            stackready=no
            while [ $stackready != 'CREATE_COMPLETE' ] && [ $stackready != 'UPDATE_COMPLETE' ] && [ $stackready != 'UPDATE_ROLLBACK_COMPLETE' ] && [ $stackready != 'ROLLBACK_COMPLETE' ]
            do
                sleep 20
                stackready=$(aws cloudformation describe-stacks --stack-name $stackid --region $aws_region | jq -r  '.Stacks[].StackStatus')
                echo $(date) status: $stackready from stack: $stackid
            done

            stackoutputs=$(aws cloudformation describe-stacks \
                    --stack-name $stackid \
                    --region $aws_region | \
                    jq -r  '.Stacks[].Outputs[]')

            lburl=$(echo $stackoutputs | jq -r  '. | select(.OutputKey=="URL") | .OutputValue')

            httpresponds=$(curl -s -D - $lburl -o /dev/null | grep 'HTTP/')
            echo $httpresponds

            clonesshcmd=$(echo $stackoutputs | jq -r  '. | select(.OutputKey=="CloneUrlSsh") | .OutputValue')
            clonehttpscmd=$(echo $clonesshcmd | sed s/ssh/https/)
            lbname=$(echo $stackoutputs | jq -r  '. | select(.OutputKey=="ElasticLoadBalancer") | .OutputValue')
            ssmautomationdoc=$(echo $stackoutputs | jq -r  '. | select(.OutputKey=="SSMAutomationDocument") | .OutputValue')
            codedeploygrp=$(echo $stackoutputs | jq -r  '. | select(.OutputKey=="CodeDeploymentGroup") | .OutputValue')
            codedeployapp=$(echo $stackoutputs | jq -r  '. | select(.OutputKey=="CodeDeployApplication") | .OutputValue')


            echo lburl=$lburl
            echo lbname=$lbname
            echo clonesshcmd=$clonesshcmd
            echo clonehttpscmd=$clonehttpscmd
            echo ssmautomationdoc=$ssmautomationdoc
            echo codedeploygrp=$codedeploygrp
            echo codedeployapp=$codedeployapp

            stacknamecicd=$stackname-cicd

            templatecicd="--template-body file://$assemble_target/cf/blog_template_part3_custom.json"
            stackparamscicd="--parameters ParameterKey=CodeBuildProject,ParameterValue=$stackname \
                ParameterKey=CodeCommitRepo,ParameterValue=$stackname \
                ParameterKey=LambdaS3Bucket,ParameterValue=$s3_bucket_prefix-$aws_region \
                ParameterKey=LambdaS3Key,ParameterValue=devsecops-part3.zip \
                ParameterKey=RepositoryBranch,ParameterValue=master \
                ParameterKey=SSMAutomationDocument,ParameterValue=$ssmautomationdoc \
                ParameterKey=ElasticLoadBalancer,ParameterValue=$lbname \
                ParameterKey=CodeDeploymentGroup,ParameterValue=$codedeploygrp \
                ParameterKey=CodeDeployApplication,ParameterValue=$codedeployapp "

            echo 'stackparamscicd'
            echo $stackparamscicd

            stackcreationcicd=$(aws cloudformation $stackaction \
                --stack-name $stacknamecicd \
                $templatecicd \
                $stackparamscicd \
                --region $aws_region \
                --capabilities CAPABILITY_NAMED_IAM)
            stackidcicd=$(echo $stackcreationcicd | jq -r '.StackId')

            echo $stackidcicd

            stackready=no
            while [ $stackready != 'CREATE_COMPLETE' ] && [ $stackready != 'UPDATE_COMPLETE' ] && [ $stackready != 'UPDATE_ROLLBACK_COMPLETE' ] && [ $stackready != 'ROLLBACK_COMPLETE' ]
            do
                sleep 20
                stackready=$(aws cloudformation describe-stacks --stack-name $stackidcicd --region $aws_region | jq -r  '.Stacks[].StackStatus')
                echo $(date) status: $stackready from stack: $stackidcicd
            done

            echo
            echo
            echo
            echo The remaining steps are manual, to aid with understanding of the process. You should:
            echo
            echo "pushd $cicd_repo_target"
            echo
            echo '# see:'
            echo '# https://docs.aws.amazon.com/codecommit/latest/userguide/setting-up-https-unixes.html'
            echo 'git config --global credential.helper '"'"'!aws codecommit credential-helper $@'"'"''
            echo git config --global credential.UseHttpPath true
            echo
            echo "$clonehttpscmd"
            echo
            echo "pushd $stackname"
            echo
            echo "cp -rf $assemble_target/* ."
            echo
            echo 'git add .'
            echo
            echo 'git commit -m "your commit message"'
            echo
            echo 'git push'
            echo
            echo 'you can inspect the progress of the build and deploy via AWS Code Pipeline,'
            echo
            echo "or simply wait for notejam to become available at $lburl"
            echo
            echo
            echo
            echo 'To destroy afterwards, use the Cloudformation console to delete the stacks'
            echo 'If you encounter errors deleting them, request the deletion again, following the prompts'
            ;;
        checkout-cicd-coderepo)
            pushd cicd_repo_target

    esac
    shift
done

