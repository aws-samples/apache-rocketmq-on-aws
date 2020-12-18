# Apache RocketMQ on the AWS Cloud

[中文](./README.zh.md)

This solution provides a one click cloudformation deployment to sets up a high available Apache RocketMQ cluster on AWS environment.

Apache RocketMQ is a unified messaging engine as well as lightweight data processing platform. The RocketMQ on AWS solution enables customers to quickly deploy a RocketMQ cluster in AWS Cloud. The basic cluster settings such as EC2 instance types are also configurable during the deployment.

The Quick Start offers two deployment options:

- Deploying Apache RocketMQ into a new virtual private cloud (VPC) on AWS
- Deploying Apache RocketMQ into an existing VPC on AWS

You can also use the AWS CloudFormation templates as a starting point for your own implementation.

## Architecure

![Quick Start architecture for RocketMQ on AWS](./assets/architecture.jpeg)

For architectural details, best practices, step-by-step instructions, and customization options, see the
[deployment guide](https://www.amazonaws.cn/solutions/RocketMQ/).

##How to use
###Require you have set up the aws ak/sk using "aws configure" 
1. clone this repo
2. go to scripts directory inside the local repo directory
3. run "bash deploy.sh" and enter the parameters needed. it will trigger a cloudformation deploy to your aws account.
