#!/bin/bash
####################################################################################################################
#   NOTE:This script must be inside and AMI in order to work,it will create AMIs snapshots as generated backups ####
#   Instance must have a ec2fullaccess policy on its role, Must be configured in crontab to run on a daily basis####
#   EX: 0 0 * * * bash /opt/create-ec2-ami-ubuntu.sh , this will run the script at 00:00am                      ####
####################################################################################################################

die() { status=$1; shift; echo "FATAL: $*"; exit $status; }
logprint() { echo "$(date +%T): $*" >> $LOGFILE; }

readonly LOGDATE=$(date +'%m%d%Y')
readonly LOGDIR=/var/log/aws/ec2/
readonly OLDLOGSFILE="$LOGDIR""backup_old_logs.log"
readonly LOGFILE="$LOGDIR""create_ami$LOGDATE.log"
readonly EC2_INSTANCE_ID="$(wget -q -O - http://169.254.169.254/latest/meta-data/instance-id || die \"wget instance-id has failed: $?\")"
readonly AMI_NAME="project-environment-prd-$LOGDATE"
readonly SUBJECT="PROJECT-ENVIRONMENT-PRD" #PRODUCT-BACKEND/FRONTEND-ENVIRONMENT
readonly MAIL=/usr/bin/mail #path of your mail command
readonly MAIL_RECEIVER="correo.usuario@company.mx"
readonly AWS_PATH=~/.aws
AWS=~/.local/bin/aws #path of your aws command
#readonly EC2_AZ=$($AWS ec2 describe-instances --instance-ids $EC2_INSTANCE_ID --query 'Reservations[*].Instances[*].Placement.AvailabilityZone[]' | sed 's/[[:space:]]//g; s/\[//g; s/\]//g; s/"//g' | grep '[^\s]')
mkdir -p $AWS_PATH
mkdir -p $LOGDIR
touch $AWS_PATH/config
:>>$LOGFILE
#NOTE: on autoscaling groups,regions may differ on each creation,installation may be installed manually
echo "[default]
region = us-east-1
output = json" > $AWS_PATH/config

if hash ~/.local/bin/aws 2>/dev/null; then
    
    logprint "aws cli already installed"

else  ###install pip3,awscli,clean apt repo,and update OS
    
    apt-get clean
    logprint "clean repos succesfully"
    cd /var/lib/apt
    mv lists lists.old
    mkdir -p lists/partial
    apt-get clean
    logprint "clean repos succesfully"
    apt-get update && logprint "updated OS succesfully" || logprint "OS update failed"
    apt-get -y install python3-pip && logprint "pip3 is now installed" || logprint "pip3 could not be installed"
    pip3 install awscli --upgrade --user && logprint "aws cli is now installed" || logprint "aws could not be installed"

fi

#if hash mail 2>/dev/null; then
#    logprint "mail command already installed"
#else
#    apt-get -y install mailutils && logprint "mail client is now installed"
#fi

if hash wget 2>/dev/null; then
    logprint "wget already installed"
else
    apt-get -y install wget && logprint "wget is now installed"
fi


echo "---------- Log of $0 for $LOGDATE ----------" >> $LOGFILE

logprint "Instance_id: $EC2_INSTANCE_ID"
logprint "image_name: $AMI_NAME"
logprint "Creating image..."

#######Create ami & send mail notification########

if $AWS ec2 create-image --instance-id $EC2_INSTANCE_ID --name $AMI_NAME --description "latest backup from running instance"; then
    logprint "image was created successfully"
    logprint "sending mail to $MAIL_RECEIVER"
    $MAIL -s "$SUBJECT AMI" $MAIL_RECEIVER <<< "An AMI for $SUBJECT ($EC2_INSTANCE_ID) was created as $AMI_NAME" && logprint "message send to $MAIL_RECEIVER" || logprint "email could not be sent to $MAIL_RECEIVER"

else
    logprint "image creation failed"
    $MAIL -s "$SUBJECT AMI" $MAIL_RECEIVER <<< "An AMI for $SUBJECT ($EC2_INSTANCE_ID) was NOT created as $AMI_NAME" && logprint "message send to $MAIL_RECEIVER" || logprint "email could not be sent to $MAIL_RECEIVER"
    logprint "image creation failed due to command failure"
fi

######find and erase the logs of the last 3 days on server#######

find $LOGDIR -type f  -mtime +3 | grep -v "backup_old_logs" > $OLDLOGSFILE
FILES=$(wc -l < $OLDLOGSFILE)
logprint "$FILES files were found"

if [ $FILES -ne 0 ]; then
    logprint "removing logsfiles older than 3 days"
    xargs rm -rv < $OLDLOGSFILE && logprint "removed" || logprint "old logsfiles could not be removed"
else
    logprint "files not yet removed"
fi
