#!/bin/bash
 ##########################################################################################
#                                                                                          #
# This script compresses all files by month in by monthly labeled zip files & removes them #
# prior to latest month in the logs directory,then zipped files are send to a s3 bucket    #
#                                                                                          #
# Examples:                                                                                #
#       bash zip-by-month logs/folder/path logPrefixname S3BucketName environment          #
#       bash zip-by-month /home/api/log microservicename company-zipped-logs PRODUCTION    #
#                                                                                          #
# Works with log files like these:                                                         #
#               logPrefixname-2020-10-16-3.log                                             #
#               microservicename-2020-10-16-3.log                                          #
#                                                                                          #
# Environment examples: DEV,QA,DEMO/STAGING/UAT PRODUCTION                                 #
#                                                                                          #
# Run as cronjob,run script on the 2nd day of each month and remove its log each 3 months: #
#                                                                                          #
#  0 0 2 * * bash home/api/log microservicename company-zipped-logs PRODUCTION             #
#  0 0 1 */3 * rm -rf /var/log/zipped-logs                                                 #
 ##########################################################################################
set -o errexit
set -o nounset
readonly LOGPATH="${1:-}"
readonly LOGNAME="${2:-}"
readonly S3_BUCKET_NAME="${3:-}"
readonly ENVIRONMENT="${4:-}"
readonly LOGDIR=/var/log/zippedLogs/
readonly LOGDATE=$(date +'%Y%m%d')
readonly LOGFILE="$LOGDIR""$2-zipped_logs$LOGDATE.log"
readonly S3_PATH="s3://$S3_BUCKET_NAME/$ENVIRONMENT/$LOGNAME"
readonly AWS=/usr/bin/aws
readonly REGEXDATES="([12]\d{3}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01]))"  #detects this date format YYYY-mm-dd
readonly SELECTED_FILES=/opt/filepathslog.txt
readonly SELECTED_DATES=/opt/dateslog.txt

ls $LOGPATH* | grep -P $REGEXDATES > $SELECTED_FILES
ls $LOGPATH* | grep -oP $REGEXDATES > $SELECTED_DATES

readonly BEGGINING_DATE_PATH=$(cat $SELECTED_DATES | head -qn1  2>/dev/null)
readonly LAST_DATE_PATH=$(cat $SELECTED_DATES | tail -qn1  2>/dev/null)
readonly FIRST_DATE=$(date -d $BEGGINING_DATE_PATH "+%Y-%m")
readonly LAST_DATE=$(date -d $LAST_DATE_PATH "+%Y-%m")

initLogFile(){
  mkdir -p $LOGDIR
  :>>"$LOGFILE"
  printf "%b" "\n---------- LOG OF $0 FOR $LOGDATE ----------" >> "$LOGFILE"
}
finishLogFile(){ 
        printf "%b" "\n---------- END OF LOG $0 ---------\n" >> "$LOGFILE"
        rm $SELECTED_FILES
        rm $SELECTED_DATES
}
logprint() { printf "%b" "\n$(date +"%T.%3N"): $*" >> "$LOGFILE"; }
isOutputEmpty(){ [ -z "$*" ] && logprint "no new zip files to sync" || logprint "synced files: $*"; }
installAWSCli(){
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/opt/awscliv2.zip"
unzip -o /opt/awscliv2.zip
/opt/aws/install -i /usr/local/aws-cli -b /usr/bin
rm -rf /opt/aws/install /opt/awscliv2.zip
#$AWS configure set aws_access_key_id <your-key>
#$AWS configure set aws_secret_access_key <your-key>
$AWS configure set default.region us-east-1
$AWS configure set default.output json
}
installNotFoundPackages(){
programs=(zip unzip aws)
for program in "${programs[@]}"; do
    if ! command -v "$program" > /dev/null 2>&1; then
            logprint "preparing to install $program"
        if [ "$program" = "aws" ]; then
                installAWSCli && logprint "installed aws-cli in: $(which -- "$program")" || logprint "aws cli could not installed"
                continue
        fi
        /usr/bin/apt-get install "$program" -y && logprint "installed $program in $(which -- "$program")" || logprint "$program could not be installed"
    else logprint "$program is already installed in: $(which -- "$program")"
    fi
done
}
#########################    MAIN PROGRAM    ##############################
initLogFile
installNotFoundPackages
logprint "LAST DATE FROM $LOGNAME-LOGS: $LAST_DATE"
while IFS='' read -r LINE || [ -n "${LINE}" ]; do
    LINEDATE=$(echo ${LINE} | grep -oP $REGEXDATES)
    CURRENT_LOGDATE=$(date -d $LINEDATE "+%Y-%m")
    LINE="${LOGPATH}/$LINE"
    logprint $LINE
    logprint "CURRENT: $CURRENT_LOGDATE"
    if [ "$CURRENT_LOGDATE" != "$LAST_DATE" ]
    then
        ZIPNAME=""$LOGPATH/"$LOGNAME""-$CURRENT_LOGDATE.zip"
        logprint $ZIPNAME
        zip -r $ZIPNAME $LINE && logprint "-------------------" && rm -rf $LINE || echo "File was not compressed"       
    fi
done < $SELECTED_FILES

isOutputEmpty "$($AWS s3 sync $LOGPATH $S3_PATH --sse AES256 --exclude "*.log")"
finishLogFile
