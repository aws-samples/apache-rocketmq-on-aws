set -x
echo "Please enter the s3 bucket you want to upload:"
read S3Bucket
echo "Please enter the S3 region:"
read S3Region
echo "Please enter the prefix(make sure the end with character /, example: rocketmq/)"
read QSS3KeyPrefix

AWS_DEFAULT_REGION=${S3Region}

if aws s3 ls "s3://${S3Bucket}" 2>&1 | grep -q 'NoSuchBucket'
then
   echo "S3 bucket ${S3Bucket} does not exist"
   aws s3api create-bucket --bucket my-bucket --region $S3Region
else
   echo "S3 bucket ${S3Bucket} already exist "
fi

# upload the template
aws s3 cp ../templates/rocketmq.template s3://${S3Bucket}/${QSS3KeyPrefix}templates/rocketmq.template
aws s3 cp ../templates/rocketmq-node-broker.template s3://${S3Bucket}/${QSS3KeyPrefix}templates/rocketmq-node-broker.template
aws s3 cp ../templates/rocketmq-node-nameserver.template s3://${S3Bucket}/${QSS3KeyPrefix}templates/rocketmq-node-nameserver.template
aws s3 cp ../templates/rocketmq-master.template s3://${S3Bucket}/${QSS3KeyPrefix}templates/rocketmq-master.template

# upload the scripts
aws s3 cp ../scripts s3://${S3Bucket}/${QSS3KeyPrefix}scripts --recursive --acl bucket-owner-full-control
aws s3 cp ../submodules s3://${S3Bucket}/${QSS3KeyPrefix}submodules --recursive --acl bucket-owner-full-control
aws s3 cp ../submodules/quickstart-linux-bastion/scripts/banner_message.txt s3://${S3Bucket}/${QSS3KeyPrefix}scripts/banner_message.txt
aws s3 cp ../submodules/quickstart-linux-bastion/scripts/bastion_bootstrap.sh s3://${S3Bucket}/${QSS3KeyPrefix}scripts/bastion_bootstrap.sh


#aws cloudformation create-stack --stack-name rocketMQ --template-body ../templates/rocketmq-master.template --parameters "[{"ParameterKey":"AvailabilityZones","ParameterValue":"cn-north-1a,cn-north-1b"},{"ParameterKey":"BrokerClusterCount","ParameterValue":"1"},{"ParameterKey":"NumberOfAZs","ParameterValue":"3"},{"ParameterKey":"RemoteAccessCIDR","ParameterValue":"0.0.0.0/0"},{"ParameterKey":"VolumeSize","ParameterValue":"100"},{"ParameterKey":"QSS3BucketName","ParameterValue":"${S3Bucket}"},{"ParameterKey":"QSS3BucketRegion","ParameterValue":"${QSS3BucketRegion}"},{"ParameterKey":"QSS3KeyPrefix","ParameterValue":"${QSS3KeyPrefix}"},{"ParameterKey":"KeyPairName","ParameterValue":"rocket-testing"},{"ParameterKey":"NameServerInstanceType","ParameterValue":"m5.large"},{"ParameterKey":"BrokerNodeInstanceType","ParameterValue":"m5.xlarge"},{"ParameterKey":"NameServerClusterCount","ParameterValue":"1"}]" --capabilities CAPABILITY_NAMED_IAM

aws cloudformation create-stack --stack-name rocketMQ --template-body file:////Users/minggu/code/solution-architecture/Aws-rocketMQ-HA-Deployment/templates/rocketmq-master.template --parameters "[{\"ParameterKey\":\"AvailabilityZones\",\"ParameterValue\":\"cn-north-1a,cn-north-1b\"},{\"ParameterKey\":\"BrokerClusterCount\",\"ParameterValue\":\"1\"},{\"ParameterKey\":\"NumberOfAZs\",\"ParameterValue\":\"2\"},{\"ParameterKey\":\"RemoteAccessCIDR\",\"ParameterValue\":\"0.0.0.0/0\"},{\"ParameterKey\":\"VolumeSize\",\"ParameterValue\":\"100\"},{\"ParameterKey\":\"QSS3BucketName\",\"ParameterValue\":\"${S3Bucket}\"},{\"ParameterKey\":\"QSS3BucketRegion\",\"ParameterValue\":\"${S3Region}\"},{\"ParameterKey\":\"QSS3KeyPrefix\",\"ParameterValue\":\"${QSS3KeyPrefix}\"},{\"ParameterKey\":\"KeyPairName\",\"ParameterValue\":\"rocket-testin-bjs\"},{\"ParameterKey\":\"NameServerInstanceType\",\"ParameterValue\":\"m5.large\"},{\"ParameterKey\":\"BrokerNodeInstanceType\",\"ParameterValue\":\"m5.xlarge\"},{\"ParameterKey\":\"NameServerClusterCount\",\"ParameterValue\":\"1\"}]" --capabilities CAPABILITY_NAMED_IAM

exit 0
#{"ParameterKey":"AvailabilityZones","ParameterValue":"cn-northwest-1a,cn-northwest-1b,cn-northwest-1c"},
echo "Please enter the AvailabilityZones:(for example:cn-northwest-1a,cn-northwest-1b,cn-northwest-1c)"
read AvailabilityZones
#{"ParameterKey":"BrokerClusterCount","ParameterValue":"1"},
echo "Please enter the BrokerClusterCount, 1 or 3"
read BrokerClusterCount
#{"ParameterKey":"NumberOfAZs","ParameterValue":"3"},
echo "Please enter the NumberOfAZs(1/2/3/4):"
read NumberOfAZs
#{"ParameterKey":"RemoteAccessCIDR","ParameterValue":"0.0.0.0/0"},
echo "Please enter the RemoteAccessCIDR(example:0.0.0.0/0):"
read RemoteAccessCIDR
#{"ParameterKey":"VolumeSize","ParameterValue":"100"},
echo "Please enter the  "
#{"ParameterKey":"QSS3BucketName","ParameterValue":"rocketmq-deploy-test-minggu"},
#{"ParameterKey":"QSS3BucketRegion","ParameterValue":"cn-northwest-1"},
#{"ParameterKey":"QSS3KeyPrefix","ParameterValue":"rocketmq-"},
#{"ParameterKey":"KeyPairName","ParameterValue":"mongo-db"},
#{"ParameterKey":"NameServerInstanceType","ParameterValue":"m5.large"},
#{"ParameterKey":"BrokerNodeInstanceType","ParameterValue":"m5.2xlarge"},
#{"ParameterKey":"NameServerClusterCount","ParameterValue":"1"}
