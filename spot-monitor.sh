#!/bin/bash
#
# 1. 自身がスポットインスタンスであるならば強制Terminateのメタデータを定期チェック
# 2. 強制Terminateを検知したら、指定したLambdaを起動し、必要な処理は全てLambdaに任せる
#

#
# config
#
interval=5
lambda_name="spot-termination"

base_url="http://169.254.169.254/latest/meta-data/"
check_url="${base_url}spot/termination-time"
id_url="${base_url}instance-id"
az_url="${base_url}placement/availability-zone"

test_content='{
  "UpdateTime": "2000-01-23T01:23:45.000Z",
  "Code": "instance-terminated-by-price",
  "Message": "Your Spot Instance was terminated because your Spot request price was lower than required fulfillment price."
}'

#
# get info
#
instance_id=$(curl -s $id_url)
region=$(curl -s $az_url | sed -e 's/.$//')

query="Reservations[0].Instances[0].InstanceLifecycle"
lifecycle=$(aws ec2 describe-instances --instance-ids "$instance_id" --query "$query" --output text --region "$region")
if [ "$lifecycle" != "spot" ]; then
    echo "This instance is not spot type."
    exit 0
fi

echo "This instance is spot type."

#
# check spot termination
#
echo "Started checking spot meta data."

while :
do
    res=$(curl -s -w '\n%{http_code}' $check_url)
    status=$(echo "$res" | tail -1)
    echo "$status" | grep "200" > /dev/null
    if [ $? -ne 0 ]; then
        sleep $interval
        continue
    fi
    break
done

#
# pre handling
#
echo "Found spot temination info !!"

content=$(echo "$res" | head -n -1)
#content="$test_content"

payload=$(cat << JSON
{
  "instance_id": "${instance_id}",
  "response": "${content}"
}
JSON
)
aws lambda invoke --function-name $lambda_name \
    --invocation-type Event \
    --payload "$payload" \
    /tmp/lambda.log \
    --region "$region" > /dev/null

echo "Executed pre handling."
