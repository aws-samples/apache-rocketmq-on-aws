export S3Bucket=rocketmq-deploy-test-minggu
export S3Region=cn-northwest-1
export QSS3KeyPrefix=rocketmq-

# upload the template
aws s3 cp ../templates/rocketmq.template s3://${S3Bucket}/${QSS3KeyPrefix}templates/rocketmq.template

aws s3 cp ../templates/rocketmq-node-broker.template s3://${S3Bucket}/${QSS3KeyPrefix}templates/rocketmq-node-broker.template

aws s3 cp ../templates/rocketmq-node-nameserver.template s3://${S3Bucket}/${QSS3KeyPrefix}templates/rocketmq-node-nameserver.template

aws s3 cp ../templates/rocketmq-master.template s3://${S3Bucket}/${QSS3KeyPrefix}templates/rocketmq-master.template

# upload the scripts
aws s3 cp ../scripts s3://${S3Bucket}/${QSS3KeyPrefix}scripts --recursive --acl bucket-owner-full-control
