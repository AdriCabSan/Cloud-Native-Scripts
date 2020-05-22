#!/bin/bash

#echo "print amazon services"
#aws resourcegroupstaggingapi get-resources --query ResourceTagMappingList[*].ResourceARN | grep aws | sed 's/:/ /g' | awk '{print $3}'
echo "print amazon tagged resources"
aws resourcegroupstaggingapi get-resources --query 'ResourceTagMappingList[*].ResourceARN' | sed 's/\[//g; s/\]//g; s/,//g; s/"//g; s/^[[:space:]]*//g' | grep '[^\s]' | tee aws_tagged_resources.txt

echo "#######print cloudfront distributions#########"
aws cloudfront list-distributions --output json --query 'DistributionList.Items[*].[Id,ARN,Origins.Items[*].DomainName | [0],DefaultCacheBehavior.LambdaFunctionAssociations.Quantity>`0` && DefaultCacheBehavior.LambdaFunctionAssociations.Items[*].LambdaFunctionARN | [0],ViewerCertificate.ACMCertificateArn,ViewerCertificate.Certificate] | []' | sed 's/\[//g; s/\]//g; s/^[[:space:]]*//g; s/,//g;s/"//g' | tee aws_cloudfront_distributions.txt

echo "###list all subnets####" #for getting an eye on general architecture in a region/account.
aws ec2 describe-subnets  --query 'Subnets[*].[VpcId,SubnetId,AvailabilityZone] | []' | sed 's/^[[:space:]]*//g; s/,//g;s/"//g' |  grep '[^\s]' | tee aws_subnets.txt

echo "###List all security groups####"
aws ec2 describe-security-groups --query 'SecurityGroups[*].[GroupName,IpPermissions[*] | [].IpRanges[*].CidrIp | [],GroupId,VpcId]' | sed 's/\[//g; s/\]//g; s/^[[:space:]]*//g; s/,//g; s/"//g; s/\(\/[a-z]*\/\)//g;' |  grep '[^\s]' | tee aws_security_groups.txt

echo "#####List all Hosted Zones######"
aws route53 list-hosted-zones-by-name --query "HostedZones[*].[Id] | []" | grep hosted | sed 's/^[[:space:]]*//g; s/,//g;s/"//g; s/\(\/[a-z]*\/\)//g' | tee aws_hostedZones.txt
##read each line(hosted-zones) from the hostedZones.txt & print the recordset for each domain
: > subdomains.txt
while IFS="" read -r p || [ -n "$p" ]
do
  printf '%s\n' "$p"
  aws route53 list-resource-record-sets --hosted-zone-id $p --output text --query 'ResourceRecordSets[].[join(`: `,[Name,Type])]' | sed 's/.://g' | awk '{print $1}' | tee aws_subdomains.txt
  echo "\n"
done < hostedZones.txt

echo "######list all roles############"
aws iam list-roles --query 'Roles[*].Arn' | sed 's/^[[:space:]]*//g; s/,//g; s/"//g; s/.://g; s/\[//g; s/\]//g;' |  grep '[^\s]' | tee aws_roles.txt

echo '###List all volumes####'
aws ec2 describe-volumes  --query 'Volumes[*].{ID:VolumeId,InstanceId:Attachments[0].InstanceId,AZ:AvailabilityZone,Size:Size}' |  grep '[^\s]' | sed 's/^[[:space:]]*//g; s/,//g; s/"//g' | tee aws_volumes.txt
