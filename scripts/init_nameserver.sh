#!/bin/bash

#################################################################
# Update the OS, install packages, initialize environment vars,
# and get the instance tags
#################################################################
yum -y update
yum install -y jq
yum install -y java-1.8.0-openjdk.x86_64
#yum install -y xfsprogs

source ./orchestrator.sh -i
source ./config.sh

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
      xms="500m"
  elif [ $mem_size == "2" ]; then
      xms="1g"
  elif [ $mem_size == "4" ]; then
      xms="2g"
  elif [ $mem_size == "8" ]; then
      xms="4g"
  elif [ $mem_size == "15" ]; then
      xms="8g"
  elif [ $mem_size == "16" ]; then
      xms="8g"
  elif [ $mem_size == "30" ]; then
      xms="15g"
  elif [ $mem_size == "32" ]; then
      xms="16g"
  elif [ $mem_size == "61" ]; then
      xms="31g"
  elif [ $mem_size == "64" ]; then
      xms="32g"
  elif [ $mem_size == "72" ]; then
      xms="36g"
  elif [ $mem_size == "122" ]; then
      xms="61g"
  elif [ $mem_size == "128" ]; then
      xms="64g"
  elif [ $mem_size == "144" ]; then
      xms="72g"
  elif [ $mem_size == "192" ]; then
      xms="91g"
  elif [ $mem_size == "244" ]; then
      xms="122g"
  elif [ $mem_size == "256" ]; then
      xms="128g"
  elif [ $mem_size == "384" ]; then
      xms="192g"
  elif [ $mem_size == "488" ]; then
      xms="244g"
  elif [ $mem_size == "512" ]; then
      xms="256g"
  elif [ $mem_size == "768" ]; then
      xms="384g"
  fi
  echo $xms
}

getSuggestedJVM_xmn() {
  instance_type=`curl http://169.254.169.254/latest/meta-data/instance-type`
  mem_size=`aws ec2 describe-instance-types --instance-types $instance_type|jq '.InstanceTypes[0].MemoryInfo.SizeInMiB'`
  mem_size=`echo $(( $mem_size / 1024 ))`
  xmn=""
  if [ $mem_size == "1" ]; then
      xmn="250m"
  elif [ $mem_size == "2" ]; then
      xmn="500m"
  elif [ $mem_size == "4" ]; then
      xmn="1g"
  elif [ $mem_size == "8" ]; then
      xmn="2g"
  elif [ $mem_size == "15" ]; then
      xmn="4g"
  elif [ $mem_size == "16" ]; then
      xmn="4g"
  elif [ $mem_size == "30" ]; then
      xmn="7g"
  elif [ $mem_size == "32" ]; then
      xmn="8g"
  elif [ $mem_size == "61" ]; then
      xmn="15g"
  elif [ $mem_size == "64" ]; then
      xmn="16g"
  elif [ $mem_size == "72" ]; then
      xmn="18g"
  elif [ $mem_size == "122" ]; then
      xmn="30g"
  elif [ $mem_size == "128" ]; then
      xmn="32g"
  elif [ $mem_size == "144" ]; then
      xmn="36g"
  elif [ $mem_size == "192" ]; then
      xmn="45g"
  elif [ $mem_size == "244" ]; then
      xmn="61g"
  elif [ $mem_size == "256" ]; then
      xmn="64g"
  elif [ $mem_size == "384" ]; then
      xmn="96g"
  elif [ $mem_size == "488" ]; then
      xmn="122g"
  elif [ $mem_size == "512" ]; then
      xmn="128g"
  elif [ $mem_size == "768" ]; then
      xmn="192g"
  fi
  echo $xmn
}
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
    ./orchestrator.sh -u "NodeType=NameServer" -n "${UNIQUE_NAME}"
    ./orchestrator.sh -z "NameServer" -w "WORKING=${NODES}" -n "${UNIQUE_NAME}"
else
    ./orchestrator.sh -b -n "${UNIQUE_NAME}"
    ./orchestrator.sh -z "NameServer" -w "WORKING=1" -n "${UNIQUE_NAME}"
    ./orchestrator.sh -u "NodeIndex=${INDEX}" -n "${UNIQUE_NAME}"
    ./orchestrator.sh -u "NodeType=NameServer" -n "${UNIQUE_NAME}"
    ./orchestrator.sh -s "WORKING" -n "${UNIQUE_NAME}"
    NODE_TYPE="Secondary"
fi

#################################################################
# End All Nodes
#################################################################

check_primary() {
    expected_state=$1
    master_substr=\"ismaster\"\ :\ ${expected_state}
    while true; do
      check_master=$( mongo --eval "printjson(db.isMaster())" )
      log "${check_master}..."
      if [[ $check_master == *"$master_substr"* ]]; then
        log "Node is in desired state, proceed with security setup"
        break
      else
        log "Wait for node to become primary"
        sleep 10
      fi
    done
}

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

sleep 5

#Adding openJDK ext dirs to the ext dirs to fix mqadm failed issue: https://www.itapes.cn/archives/148
sed -i 's/JAVA_OPT="${JAVA_OPT} -Djava.ext.dirs=.*$/JAVA_OPT=\"\${JAVA_OPT} -Djava.ext.dirs=\${BASE_DIR}\/lib:${JAVA_HOME}\/jre\/lib\/ext:${JAVA_HOME}\/lib\/ext:\/usr\/lib\/jvm\/jre-1.8.0-openjdk\/lib\/ext\"/gI' ./rocketmq-all-${version}-bin-release/bin/tools.sh
echo "java extension dirs are"
echo `grep "-Djava.ext.dirs" ./rocketmq-all-${version}-bin-release/bin/tools.sh`

#Update the default jvm memory allocation
#JAVA_OPT="${JAVA_OPT} -server -Xms8g -Xmx8g -Xmn4g"
xms=`getSuggestedJVM_xms`
xmn=`getSuggestedJVM_xmn`
sed -i "s/-server -Xms4g -Xmx4g -Xmn2g.*$/-server -Xms${xms} -Xmx${xms} -Xmn${xmn}\"/gI" ./rocketmq-all-${version}-bin-release/bin/runserver.sh
echo "java jvm allocation are"
echo `grep "-server -X" ./rocketmq-all-${version}-bin-release/bin/runserver.sh`

################################################################
# Start generating RocketMQ config file
################################################################
NAMESERVERS=""
NAMESERVER_PORT=9876

################################################################
# Start to launch Name Server
################################################################
nohup sh rocketmq-all-${version}-bin-release/bin/mqnamesrv &

# TBD - Add custom CloudWatch Metrics for RocketMQ
if [[ "$NODE_TYPE" == "Primary" ]]; then

    #################################################################
    #  Update status to FINISHED, if this is s0 then wait on the rest
    #  of the nodes to finish and remove orchestration tables
    #################################################################
    ./orchestrator.sh -s "FINISHED" -n "${UNIQUE_NAME}"
    ./orchestrator.sh -w "FINISHED=${NODES}" -z "NameServer" -n "${UNIQUE_NAME}"

    #get the name server ip list
    NAMESERVERIPADDRS=$(./orchestrator.sh -n "${UNIQUE_NAME}" -g "NameServer")
    read -a NAMESERVERIPADDRS <<< $NAMESERVERIPADDRS
    echo "NAMESERVERIPADDRS is ${NAMESERVERIPADDRS}"
else
    #################################################################
    #  Update status of Secondary to FINISHED
    #################################################################
    ./orchestrator.sh -s "FINISHED" -n "${UNIQUE_NAME}"
    ./orchestrator.sh -w "FINISHED=${NODES}" -z "NameServer" -n "${UNIQUE_NAME}"

    #get the name server ip list
    NAMESERVERIPADDRS=$(./orchestrator.sh -n "${UNIQUE_NAME}" -g "NameServer")
    read -a NAMESERVERIPADDRS <<< $NAMESERVERIPADDRS
    echo "NAMESERVERIPADDRS is ${NAMESERVERIPADDRS}"
fi

NAMESERVERS=""

for addr in "${NAMESERVERIPADDRS[@]}"
do
    addr="${addr%\"}"
    addr="${addr#\"}"
    NAMESERVERS+="${addr}:${NAMESERVER_PORT};"
done

nohup java -jar ./rocketmq-console-ng-1.0.0.jar --rocketmq.config.namesrvAddr=$NAMESERVERS &


# exit with 0 for SUCCESS
exit 0
