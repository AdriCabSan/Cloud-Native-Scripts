#/bin/bash
#
readonly IMAGE_PATH=/tmp/imagesearch
readonly AMI_PATH=/tmp/ami
readonly PROJECT_NAME="project" #main name of AMIs,must follow a similar syntax of this: project-backend-staging01172020
AWS=~/.local/bin/aws
INSTANCE_NAME=$($AWS ec2 describe-instances --instance-ids $(wget -q -O - http://169.254.169.254/latest/meta-data/instance-id) --query 'Reservations[*].Instances[*].Tags[?Key == `Name`].Value' | sed 's/[[:space:]]//g; s/\[//g; s/\]//g; s/"//g' | grep '[^\s]')
IMAGE_PREFIX="$INSTANCE_NAME-"
IMAGE_SEARCH=$($AWS ec2 describe-images --owners self --filters "Name=name,Values=$IMAGE_PREFIX*" --query 'sort_by(Images, &CreationDate)[].[Name,ImageId,CreationDate,BlockDeviceMappings[].Ebs[].[SnapshotId]]' > $IMAGE_PATH)
AMIS=$(cat $IMAGE_PATH | grep -i $PROJECT_NAME | sed "s/[[:space:]]//g; s/,//g; s/\"//g" | grep -i "$IMAGE_PREFIX[0-9]" > $AMI_PATH)

while IFS= read -r LINE || [ -n "$LINE" ]; do

        DATE_LIMIT=$(date +'%m%d%Y' -d "-1 days")
        IMAGE_NAME="$IMAGE_PREFIX""$DATE_LIMIT"
        OLD_AMI_DATE=$(echo $LINE | awk '{print $4}' FS="-")
        OLDER_AMI_NAME="$IMAGE_PREFIX""$OLD_AMI_DATE"
        OLDER_AMI_ID=$($AWS ec2 describe-images --owners self --filters "Name=name,Values=$OLDER_AMI_NAME" --query 'sort_by(Images, &CreationDate)[].[ImageId]' | sed 's/^[[:space:]]*//g; s/,//g; s/"//g; s/.://g; s/\[//g; s/\]//g;' |  grep '[^\s]')

        if [ $OLD_AMI_DATE -le $DATE_LIMIT ]; then
                SNAPSHOT_ID=$($AWS ec2 describe-images --owners self --filters "Name=name,Values=$OLDER_AMI_NAME" --query 'sort_by(Images, &CreationDate)[].[BlockDeviceMappings[].Ebs[].[SnapshotId]]' | grep "snap" | sed "s/\"//g")
                echo "AMI_NAME: $OLDER_AMI_NAME id: $OLDER_AMI_ID"
                echo "SNAPSHOT_ID:$SNAPSHOT_ID"
                $AWS ec2 deregister-image --image-id $OLDER_AMI_ID
                $AWS ec2 delete-snapshot --snapshot-id $SNAPSHOT_ID
        fi
done < $AMI_PATH

