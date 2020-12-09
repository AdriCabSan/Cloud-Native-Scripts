###########################################################################################
#                                                                                          #
# This script compresses all files by month in by monthly labeled zip files & removes them #
# prior to latest month in the logs directory,then zip files are send to a s3 bucket       #
                                                                                           #
# Example: sh zip-by-month logs/folder/path logPrefixname S3BucketName environment         #
                                                                                           #
# works with log files like these: logPrefixname-2020-10-16-3.log                          #
# environment examples: DEV,QA,DEMO/STAGING/UAT PRODUCTION                                 #
                                                                                           #
###########################################################################################

logprint() { echo "$(date +"%T.%3N"): $*" >> $LOGFILE; }

isOutputEmpty(){
if [ -z "$*" ]; then
    logprint "no new zip files to sync"
else
    logprint "synced files: $*"
fi
}

LOGPATH=$1
LOGNAME=$2
S3_BUCKET_NAME=$3
ENVIRONMENT=$4
LOGDIR=/var/log/zippedLogs/
LOGDATE=$(date +'%Y%m%d')
LOGFILE="$LOGDIR""$2-zipped_logs$LOGDATE.log"

S3_PATH="s3://$S3_BUCKET_NAME/$ENVIRONMENT/$LOGNAME"
AWS=~/.local/bin/aws #this command is due to to python aws cli installation

mkdir -p $LOGDIR
:>>$LOGFILE

echo "---------- Log of $0 for $LOGDATE ----------" >> $LOGFILE

REGEXDATES="([12]\d{3}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01]))"  #detects this date format YYYY-mm-dd
SELECTED_FILES=/opt/filepathslog.txt
SELECTED_DATES=/opt/dateslog.txt
LOGDATES=$(ls $LOGPATH* | grep -P $REGEXDATES > $SELECTED_FILES)
DATES=$(ls $LOGPATH* | grep -oP $REGEXDATES > $SELECTED_DATES)
BEGGINING_DATE_PATH=$(cat $SELECTED_DATES | head -qn1  2>/dev/null)
LAST_DATE_PATH=$(cat $SELECTED_DATES | tail -qn1  2>/dev/null)
FIRST_DATE=$(date -d $BEGGINING_DATE_PATH "+%Y-%m")
LAST_DATE=$(date -d $LAST_DATE_PATH "+%Y-%m")

logprint "LAST DATE FROM $LOGNAME-LOGS: $LAST_DATE"

while IFS='' read -r LINE || [ -n "${LINE}" ]; do
    LINEDATE=$(echo ${LINE} | grep -oP $REGEXDATES)
    CURRENT_LOGDATE=$(date -d $LINEDATE "+%Y-%m")
    LINE="${LOGPATH}/$LINE"
    logprint $LINE
    logprint "CURRENT: $CURRENT_LOGDATE"
    if [ "$CURRENT_LOGDATE" != "$LAST_DATE" ]
    then
        ZIPNAME=""$LOGPATH/"$LOGNAME""-"${CURRENT_LOGDATE}".zip"
        logprint $ZIPNAME
        zip -r $ZIPNAME $LINE && logprint "\n-------\n" && rm -rf $LINE || echo "File was not compressed"       
    fi
done < $SELECTED_FILES

isOutputEmpty $($AWS s3 sync $LOGPATH $S3_PATH --sse AES256 --exclude "*.log")

rm $SELECTED_FILES
rm $SELECTED_DATES

