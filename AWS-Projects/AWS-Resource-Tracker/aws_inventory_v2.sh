#!/bin/bash

set -e
set -x

# =====================================
# Variables
# =====================================

DATE=$(date +%F)

BASE_DIR=$(dirname "$(dirname "$(realpath "$0")")")

REPORT="$BASE_DIR/reports/aws_report_$DATE.txt"

LOGFILE="$BASE_DIR/logs/aws_inventory.log"

S3_BUCKET="devops-learning-vp-001"

EMAIL="blueteamforge.official@gmail.com"

# =====================================
# Logging
# =====================================

exec >> "$LOGFILE" 2>&1

echo "======================================="
echo "Started AWS Inventory Collection"
echo "Date: $(date)"
echo "======================================="

# =====================================
# Report Generation
# =====================================

echo "AWS INVENTORY REPORT - $DATE" > "$REPORT"
echo "===================================" >> "$REPORT"

# EC2
echo "" >> "$REPORT"
echo "EC2 INSTANCES" >> "$REPORT"

aws ec2 describe-instances \
--query 'Reservations[*].Instances[*].[InstanceId,State.Name]' \
--output table >> "$REPORT"

# S3
echo "" >> "$REPORT"
echo "S3 BUCKETS" >> "$REPORT"

aws s3 ls >> "$REPORT"

# Lambda
echo "" >> "$REPORT"
echo "LAMBDA FUNCTIONS" >> "$REPORT"

aws lambda list-functions \
--query 'Functions[*].[FunctionName]' \
--output table >> "$REPORT"

# IAM
echo "" >> "$REPORT"
echo "IAM USERS" >> "$REPORT"

aws iam list-users \
--query 'Users[*].[UserName]' \
--output table >> "$REPORT"

# Unattached EBS
echo "" >> "$REPORT"
echo "UNATTACHED EBS VOLUMES" >> "$REPORT"

aws ec2 describe-volumes \
--filters Name=status,Values=available \
--query 'Volumes[*].[VolumeId,Size,AvailabilityZone]' \
--output table >> "$REPORT"

# Stopped EC2
echo "" >> "$REPORT"
echo "STOPPED EC2 INSTANCES" >> "$REPORT"

aws ec2 describe-instances \
--filters Name=instance-state-name,Values=stopped \
--query 'Reservations[*].Instances[*].[InstanceId,State.Name]' \
--output table >> "$REPORT"

# =====================================
# Upload To S3
# =====================================

echo "" >> "$REPORT"
echo "S3 UPLOAD STATUS" >> "$REPORT"

if aws s3 cp "$REPORT" "s3://$S3_BUCKET/reports/$DATE/"; then
    echo "S3 Upload Successful" >> "$REPORT"
else
    echo "S3 Upload Failed" >> "$REPORT"
fi

# =====================================
# Send SES Email
# =====================================

aws ses send-email \
--from "$EMAIL" \
--destination ToAddresses="$EMAIL" \
--message '{
"Subject":{
"Data":"AWS Resource Tracker Report"
},
"Body":{
"Text":{
"Data":"AWS Resource Tracker executed successfully. Report uploaded to S3."
}
}
}'

# =====================================
# Footer
# =====================================

echo "" >> "$REPORT"
echo "REPORT GENERATED ON: $(date)" >> "$REPORT"

echo "======================================="
echo "Report Generated Successfully"
echo "Report Location: $REPORT"
echo "Completed: $(date)"
echo "======================================="
