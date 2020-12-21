#!/bin/bash
set -x

#################################################################
# Update the OS, install packages, initialize environment vars,
# and get the instance tags
#################################################################
yum -y update
yum install -y jq
yum install -y java-1.8.0-openjdk.x86_64

source ./config.sh
source ./orchestrator.sh -i

tags=`aws ec2 describe-tags --filters "Name=resource-id,Values=${AWS_INSTANCEID}"`

#################################################################
#  gatValue() - Read a value from the instance tags
#################################################################
getValue() {
    index=`echo $tags | jq '.[]' | jq '.[] | .Key == "'$1'"' | grep -n true | sed s/:.*//g | tr -d '\n'`
    (( index-- ))
    filter=".[$index]"
    result=`echo $tags | jq '.[]' | jq $filter.Value | sed s/\"//g | sed s/Primary.*/Primary/g | tr -d '\n'`
    echo $result
}

getSuggestedJVM_xms() {
  instance_type=`curl http://169.254.169.254/latest/meta-data/instance-type`
  mem_size=`aws ec2 describe-instance-types --instance-types $instance_type|jq '.InstanceTypes[0].MemoryInfo.SizeInMiB'`
  mem_size=`echo $(( $mem_size / 1024 ))`
  xms=""
  if [ $mem_size == "1" ]; then
      xms="200m"
  elif [ $mem_size == "2" ]; then
      xms="500m"
  elif [ $mem_size == "4" ]; then
      xms="1g"
  elif [ $mem_size == "8" ]; then
      xms="2g"
  elif [ $mem_size == "15" ]; then
      xms="3g"
  elif [ $mem_size == "16" ]; then
      xms="4g"
  elif [ $mem_size == "30" ]; then
      xms="8g"
  elif [ $mem_size == "32" ]; then
      xms="8g"
  elif [ $mem_size == "61" ]; then
      xms="15g"
  elif [ $mem_size == "64" ]; then
      xms="16g"
  elif [ $mem_size == "72" ]; then
      xms="20g"
  elif [ $mem_size == "122" ]; then
      xms="30g"
  elif [ $mem_size == "128" ]; then
      xms="32g"
  elif [ $mem_size == "144" ]; then
      xms="40g"
  elif [ $mem_size == "192" ]; then
      xms="45g"
  elif [ $mem_size == "244" ]; then
      xms="61g"
  elif [ $mem_size == "256" ]; then
      xms="64g"
  elif [ $mem_size == "384" ]; then
      xms="96g"
  elif [ $mem_size == "488" ]; then
      xms="122g"
  elif [ $mem_size == "512" ]; then
      xms="128g"
  elif [ $mem_size == "768" ]; then
      xms="197g"
  fi
  echo $xms
}

getSuggestedJVM_xmn() {
  instance_type=`curl http://169.254.169.254/latest/meta-data/instance-type`
  mem_size=`aws ec2 describe-instance-types --instance-types $instance_type|jq '.InstanceTypes[0].MemoryInfo.SizeInMiB'`
  mem_size=`echo $(( $mem_size / 1024 ))`
  xmn=""
  if [ $mem_size == "1" ]; then
      xmn="100m"
  elif [ $mem_size == "2" ]; then
      xmn="250m"
  elif [ $mem_size == "4" ]; then
      xmn="500m"
  elif [ $mem_size == "8" ]; then
      xmn="1g"
  elif [ $mem_size == "15" ]; then
      xmn="2g"
  elif [ $mem_size == "16" ]; then
      xmn="2g"
  elif [ $mem_size == "30" ]; then
      xmn="4g"
  elif [ $mem_size == "32" ]; then
      xmn="4g"
  elif [ $mem_size == "61" ]; then
      xmn="7g"
  elif [ $mem_size == "64" ]; then
      xmn="7g"
  elif [ $mem_size == "72" ]; then
      xmn="10g"
  elif [ $mem_size == "122" ]; then
      xmn="15g"
  elif [ $mem_size == "128" ]; then
      xmn="16g"
  elif [ $mem_size == "144" ]; then
      xmn="20g"
  elif [ $mem_size == "192" ]; then
      xmn="22g"
  elif [ $mem_size == "244" ]; then
      xmn="30g"
  elif [ $mem_size == "256" ]; then
      xmn="32g"
  elif [ $mem_size == "384" ]; then
      xmn="48g"
  elif [ $mem_size == "488" ]; then
      xmn="61g"
  elif [ $mem_size == "512" ]; then
      xmn="64g"
  elif [ $mem_size == "768" ]; then
      xmn="98g"
  fi
  echo $xmn
}
##version=`getValue RocketMQVersion`

# RocketMQVersion set inside config.sh
version=${RocketMQVersion}

if [ -z "$version" ] ; then
  version="4.7.1"
fi


#################################################################
#  Figure out what kind of node we are and set some values
#################################################################
NODE_TYPE=`getValue Name`
IP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
HOSTNAME=$(curl http://169.254.169.254/latest/meta-data/local-hostname)

NODES=`getValue BrokerClusterCount`
INDEX=`getValue NodeReplicaSetIndex`


#  Do NOT use timestamps here!!
# This has to be unique across multiple runs!
UNIQUE_NAME=ROCKETMQ_${TABLE_NAMETAG}_${VPC}

#################################################################
#  Wait for all the nodes to synchronize so we have all IP address
#################################################################
if [ "${NODE_TYPE}" == "Primary" ]; then
    ./orchestrator.sh -c -n "${UNIQUE_NAME}"
    ./orchestrator.sh -s "WORKING" -n "${UNIQUE_NAME}"
    ./orchestrator.sh -u "NodeIndex=${INDEX}" -n "${UNIQUE_NAME}"
    ./orchestrator.sh -u "NodeType=Broker" -n "${UNIQUE_NAME}"
    ./orchestrator.sh -z "Broker" -w "WORKING=${NODES}"  -n "${UNIQUE_NAME}"

    IPADDRS=$(./orchestrator.sh -n "${UNIQUE_NAME}" -g "Broker")
    read -a IPADDRS <<< $IPADDRS
    DLEDGERSERVERS=$(./orchestrator.sh  -n "${UNIQUE_NAME}" -z "Broker" -y 0)
    read -a DLEDGERSERVERS <<< $DLEDGERSERVERS
    echo "DLEDGERSERVERS is  ${DLEDGERSERVERS}"
    DLEDGERSERVERS1=$(./orchestrator.sh -n "${UNIQUE_NAME}" -z "Broker" -y 1)
    read -a DLEDGERSERVERS1 <<< $DLEDGERSERVERS1
    echo "DLEDGERSERVERS1 is  ${DLEDGERSERVERS1}"
    DLEDGERSERVERS2=$(./orchestrator.sh -n "${UNIQUE_NAME}" -z "Broker" -y 2 )
    read -a DLEDGERSERVERS2 <<< $DLEDGERSERVERS2
    echo "DLEDGERSERVERS2 is  ${DLEDGERSERVERS2}"

    #get the name server ip list
    NAMESERVERIPADDRS=$(./orchestrator.sh -n "${UNIQUE_NAME}" -g "NameServer")
    read -a NAMESERVERIPADDRS <<< $NAMESERVERIPADDRS
    echo "NAMESERVERIPADDRS is ${NAMESERVERIPADDRS}"
else
    ./orchestrator.sh -b -n "${UNIQUE_NAME}"
    ./orchestrator.sh -z "Broker" -w "WORKING=1" -n "${UNIQUE_NAME}"
    ./orchestrator.sh -u "NodeIndex=${INDEX}" -n "${UNIQUE_NAME}"
    ./orchestrator.sh -u "NodeType=Broker" -n "${UNIQUE_NAME}"
    ./orchestrator.sh -s "WORKING" -n "${UNIQUE_NAME}"
    NODE_TYPE="Secondary"
    ./orchestrator.sh -z "Broker" -w "WORKING=${NODES}" -n "${UNIQUE_NAME}"

    IPADDRS=$(./orchestrator.sh -n "${UNIQUE_NAME}" -g "Broker")
    read -a IPADDRS <<< $IPADDRS
    DLEDGERSERVERS=$(./orchestrator.sh -y 0  -z "Broker" -n "${UNIQUE_NAME}")
    read -a DLEDGERSERVERS <<< $DLEDGERSERVERS
    echo "DLEDGERSERVERS is  ${DLEDGERSERVERS}"
    DLEDGERSERVERS1=$(./orchestrator.sh -y 1 -z "Broker" -n "${UNIQUE_NAME}")
    read -a DLEDGERSERVERS1 <<< $DLEDGERSERVERS1
    echo "DLEDGERSERVERS1 is  ${DLEDGERSERVERS1}"
    DLEDGERSERVERS2=$(./orchestrator.sh -y 2 -z "Broker" -n "${UNIQUE_NAME}")
    read -a DLEDGERSERVERS2 <<< $DLEDGERSERVERS2
    echo "DLEDGERSERVERS2 is  ${DLEDGERSERVERS2}"

    #get the  name  server ip list
    NAMESERVERIPADDRS=$(./orchestrator.sh -n "${UNIQUE_NAME}" -g "NameServer")
    read -a NAMESERVERIPADDRS <<< $NAMESERVERIPADDRS
    echo "NAMESERVERIPADDRS is ${NAMESERVERIPADDRS}"
fi

#################################################################
# Setup RocketMQ servers and config nodes
#################################################################
echo "start download the rocketmq release 4.7.1"
if [ ${version} == "4.7.1" ]
then
  wget https://archive.apache.org/dist/rocketmq/4.7.1/rocketmq-all-4.7.1-bin-release.zip
  if [[ $? -ne 0 ]]
  then
     echo "failed to download the rocketMQ from website"
     exit 1
  fi
elif [ ${version} == "4.8.0" ]
then
  wget https://mirror.bit.edu.cn/apache/rocketmq/4.8.0/rocketmq-all-4.8.0-bin-release.zip
  if [[ $? -ne 0 ]]
  then
   #Try another source
   wget https://mirrors.tuna.tsinghua.edu.cn/apache/rocketmq/4.8.0/rocketmq-all-4.8.0-bin-release.zip
   if [[ $? -ne 0 ]]
   then
     #Try another  source
     wget https://mirrors.bfsu.edu.cn/apache/rocketmq/4.8.0/rocketmq-all-4.8.0-bin-release.zip
     if [[ $? -ne 0 ]]
     then
       echo "failed to download the rocketMQ from website"
       exit 1
     fi
   fi
  fi
fi

unzip ./rocketmq-all-${version}-bin-release.zip

sleep 2

#Adding openJDK ext dirs to the ext dirs to fix mqadm failed issue: https://www.itapes.cn/archives/148
sed -i 's/JAVA_OPT="${JAVA_OPT} -Djava.ext.dirs=.*$/JAVA_OPT=\"\${JAVA_OPT} -Djava.ext.dirs=\${BASE_DIR}\/lib:${JAVA_HOME}\/jre\/lib\/ext:${JAVA_HOME}\/lib\/ext:\/usr\/lib\/jvm\/jre-1.8.0-openjdk\/lib\/ext\"/gI' ./rocketmq-all-${version}-bin-release/bin/tools.sh
echo "java extension dirs are"
echo `grep "-Djava.ext.dirs" ./rocketmq-all-${version}-bin-release/bin/tools.sh`


#Update the default jvm memory allocation
#JAVA_OPT="${JAVA_OPT} -server -Xms8g -Xmx8g -Xmn4g"
xms=`getSuggestedJVM_xms`
xmn=`getSuggestedJVM_xmn`
sed -i "s/-server -Xms8g -Xmx8g -Xmn4g.*$/-server -Xms${xms} -Xmx${xms} -Xmn${xmn}\"/gI" ./rocketmq-all-${version}-bin-release/bin/runbroker.sh
echo "java jvm allocation are"
echo `grep "-server -X" ./rocketmq-all-${version}-bin-release/bin/runbroker.sh`

################################################################
# Start generating RocketMQ config file
################################################################
NAMESERVERS=""
NAMESERVER_PORT=9876
BROKERSERVER_PORT=30911
BROKERSERVER1_PORT=30921
BROKERSERVER2_PORT=30931
DLEDGER_PORT="40911"
DLEDGER1_PORT="40921"
DLEDGER2_PORT="40931"

for addr in "${NAMESERVERIPADDRS[@]}"
do
    addr="${addr%\"}"
    addr="${addr#\"}"
    NAMESERVERS+="${addr}:${NAMESERVER_PORT};"
done

FINALDLEDGERSERVERS=""
FINALDLEDGERSERVERS1=""
FINALDLEDGERSERVERS2=""

for item in "${DLEDGERSERVERS[@]}"
do
   FINALDLEDGERSERVERS+="${item}:${DLEDGER_PORT};"	
done

for item in "${DLEDGERSERVERS1[@]}"
do
   FINALDLEDGERSERVERS1+="${item}:${DLEDGER1_PORT};"
done

for item in "${DLEDGERSERVERS2[@]}"
do
   FINALDLEDGERSERVERS2+="${item}:${DLEDGER2_PORT};"
done

echo "FINAL DLEDGER SERVERS ARE ${FINALDLEDGERSERVERS}"
echo "FINAL DLEDGER1 SERVERS ARE ${FINALDLEDGERSERVERS1}"
echo "FINAL DLEDGER2 SERVERS ARE ${FINALDLEDGERSERVERS2}"

mkdir rocketMQ-config
cd rocketMQ-config/
CONFIG_NAME="broker-n${INDEX}.conf"
cat << EOF > ${CONFIG_NAME}
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#
brokerClusterName = AWS_Apache_RocketMQ_RaftCluster
brokerName=RaftNode01
listenPort=${BROKERSERVER_PORT}
namesrvAddr=${NAMESERVERS}
storePathRootDir=/home/ec2-user/rocketmq-deploy/rmqstore/node0${INDEX}
storePathCommitLog=/home/ec2-user/rocketmq-deploy/rmqstore/node0${INDEX}/commitlog
enableDLegerCommitLog=true
dLegerGroup=RaftNode01
dLegerPeers=${FINALDLEDGERSERVERS}
## must be unique
dLegerSelfId=n${INDEX}
sendMessageThreadPoolNums=16
flushDiskType=${FLUSHDISKTYPE}
EOF

CONFIG_NAME1="broker-n$(( (${INDEX} + 1) % 3 )).conf"
cat << EOF > ${CONFIG_NAME1}
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#
brokerClusterName = AWS_Apache_RocketMQ_RaftCluster
brokerName=RaftNode02
listenPort=${BROKERSERVER1_PORT}
namesrvAddr=${NAMESERVERS}
storePathRootDir=/home/ec2-user/rocketmq-deploy/rmqstore/node0$(( (${INDEX} + 1) % 3 ))
storePathCommitLog=/home/ec2-user/rocketmq-deploy/rmqstore/node0$(( (${INDEX} + 1) % 3 ))/commitlog
enableDLegerCommitLog=true
dLegerGroup=RaftNode02
dLegerPeers=${FINALDLEDGERSERVERS1}
## must be unique
dLegerSelfId=n$(( (${INDEX} + 1) % 3 ))
sendMessageThreadPoolNums=16
flushDiskType=${FLUSHDISKTYPE}
EOF

CONFIG_NAME2="broker-n$(( (${INDEX} + 2) % 3 )).conf"
cat << EOF > ${CONFIG_NAME2}
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#
brokerClusterName = AWS_Apache_RocketMQ_RaftCluster
brokerName=RaftNode03
listenPort=${BROKERSERVER2_PORT}
namesrvAddr=${NAMESERVERS}
storePathRootDir=/home/ec2-user/rocketmq-deploy/rmqstore/node0$(( (${INDEX} + 2) % 3 ))
storePathCommitLog=/home/ec2-user/rocketmq-deploy/rmqstore/node0$(( (${INDEX} + 2) % 3 ))/commitlog
enableDLegerCommitLog=true
dLegerGroup=RaftNode03
dLegerPeers=${FINALDLEDGERSERVERS2}
## must be unique
dLegerSelfId=n$(( (${INDEX} + 2) % 3 ))
sendMessageThreadPoolNums=16
flushDiskType=${FLUSHDISKTYPE}
EOF

cd ..

#################################################################
# start to construct rocketMQ config
#################################################################

nohup rocketmq-all-${version}-bin-release/bin/mqbroker -c ./rocketMQ-config/broker-n0.conf &
sleep 5
nohup rocketmq-all-${version}-bin-release/bin/mqbroker -c ./rocketMQ-config/broker-n1.conf &
sleep 5
nohup rocketmq-all-${version}-bin-release/bin/mqbroker -c ./rocketMQ-config/broker-n2.conf &
sleep 5


#################################################################
#  Primaries initiate replica sets
#################################################################
./orchestrator.sh -s "FINISHED" -n "${UNIQUE_NAME}"
./orchestrator.sh -w "FINISHED=${NODES}" -z "Broker" -n "${UNIQUE_NAME}"
if [[ "$NODE_TYPE" == "Primary" ]]; then
    sleep 15
    ./orchestrator.sh -d -n "${UNIQUE_NAME}"
fi

# TBD - Add custom CloudWatch Metrics for RocketMQ

# exit with 0 for SUCCESS
exit 0
