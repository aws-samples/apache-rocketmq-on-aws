set -x
echo "Please enter the s3 bucket you want to upload:"
read S3Bucket
echo "Please enter the S3 region:"
read S3Region
echo "Please enter the prefix(make sure the end with character /, example: rocketmq/)"
read QSS3KeyPrefix
echo "Please enter the AvailabilityZones, separated by comma :(for example:cn-northwest-1a,cn-northwest-1b,cn-northwest-1c)"
read AvailabilityZones
echo "Please enter the NumberOfAZs(1/2/3/4):"
read NumberOfAZs
echo "please enter the ec2 keypair name"
read KeyPairName
echo "Please enter the BrokerClusterCount, 1 or 3"
read BrokerClusterCount
echo "Please enter the number of nameserver(1/2/3):"
read NameServerClusterCount
echo "Which Apache RocketMQ version to deploy:(4.7.1 or 4.8.0)"
read RocketMQVersion

AWS_DEFAULT_REGION=${S3Region}

if aws s3 ls "s3://${S3Bucket}" 2>&1 | grep -q 'NoSuchBucket'
then
   echo "S3 bucket ${S3Bucket} does not exist"
   if [[ ${S3Bucket} == "us-east-1" ]]
   then
    aws s3api create-bucket --bucket ${S3Bucket} --region $S3Region
   else
    aws s3api create-bucket --bucket ${S3Bucket} --region $S3Region --create-bucket-configuration LocationConstraint=${S3Region}
    fi
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


template_path=`pwd`
currentTime=`date +%F-%H-%M`

aws cloudformation create-stack --stack-name rocketMQ-${currentTime} --template-body file:///${template_path}/../templates/rocketmq-master.template --parameters "[{\"ParameterKey\":\"AvailabilityZones\",\"ParameterValue\":\"${AvailabilityZones}\"},{\"ParameterKey\":\"BrokerClusterCount\",\"ParameterValue\":\"${BrokerClusterCount}\"},{\"ParameterKey\":\"NumberOfAZs\",\"ParameterValue\":\"${NumberOfAZs}\"},{\"ParameterKey\":\"RemoteAccessCIDR\",\"ParameterValue\":\"0.0.0.0/0\"},{\"ParameterKey\":\"VolumeSize\",\"ParameterValue\":\"100\"},{\"ParameterKey\":\"QSS3BucketName\",\"ParameterValue\":\"${S3Bucket}\"},{\"ParameterKey\":\"QSS3BucketRegion\",\"ParameterValue\":\"${S3Region}\"},{\"ParameterKey\":\"QSS3KeyPrefix\",\"ParameterValue\":\"${QSS3KeyPrefix}\"},{\"ParameterKey\":\"KeyPairName\",\"ParameterValue\":\"${KeyPairName}\"},{\"ParameterKey\":\"NameServerInstanceType\",\"ParameterValue\":\"m5.large\"},{\"ParameterKey\":\"BrokerNodeInstanceType\",\"ParameterValue\":\"m5.xlarge\"},{\"ParameterKey\":\"NameServerClusterCount\",\"ParameterValue\":\"${NameServerClusterCount}\"},{\"ParameterKey\":\"RocketMQVersion\",\"ParameterValue\":\"${RocketMQVersion}\"}]" --capabilities CAPABILITY_NAMED_IAM
