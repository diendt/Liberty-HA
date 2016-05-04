#!/bin/bash -ex
#
source config.cfg
source function.sh

###########################################################
echocolor "INSTALL AND CONFIG RABBITMQ"

sleep 2

echocolor "Install and Config RabbitMQ"

sleep 3

#Node1
echocolor "INSTALL AND CONFIG RABBITMQ $CON_MGNT_IP1"
apt-get install rabbitmq-server -y  --fix-missing 

echo "NODE_IP_ADDRESS=$CON_MGNT_IP1" >>  /etc/rabbitmq/rabbitmq-env.conf

sleep 3
service rabbitmq-server restart 

sleep 2

#Connect ssh to Node 2
echocolor "INSTALL AND CONFIG RABBITMQ $CON_MGNT_IP2"

cat << EOF | ssh root@$CON_MGNT_IP2 bash -ex
source config.cfg

apt-get install rabbitmq-server -y  --fix-missing 
echo "NODE_IP_ADDRESS=$CON_MGNT_IP2" >>  /etc/rabbitmq/rabbitmq-env.conf

service rabbitmq-server restart

service rabbitmq-server stop
EOF

#Connect ssh to Node 3
echocolor "INSTALL AND CONFIG RABBITMQ $CON_MGNT_IP3"
cat << EOF | ssh root@$CON_MGNT_IP3 bash -ex
source config.cfg

apt-get install rabbitmq-server -y  --fix-missing 
echo "NODE_IP_ADDRESS=$CON_MGNT_IP3" >>  /etc/rabbitmq/rabbitmq-env.conf

service rabbitmq-server restart
service rabbitmq-server stop
EOF


echocolor "CONFIG CLUSTER"
sleep 5
#On Node 1
service rabbitmq-server stop
scp /var/lib/rabbitmq/.erlang.cookie root@$CON_MGNT_IP2:/var/lib/rabbitmq/.erlang.cookie
scp /var/lib/rabbitmq/.erlang.cookie root@$CON_MGNT_IP3:/var/lib/rabbitmq/.erlang.cookie

service rabbitmq-server start

#Join node 2, node 3 to cluster
echocolor "Join node 2, node 3 to cluster"
sleep 3

cat << EOF | ssh root@$CON_MGNT_IP2 bash -ex
source config.cfg

service rabbitmq-server start

rabbitmqctl stop_app
rabbitmqctl join_cluster rabbit@$HOST_CTL_IP1
rabbitmqctl start_app
rabbitmqctl cluster_status
#exit
EOF


cat << EOF | ssh root@$CON_MGNT_IP3 bash -ex
source config.cfg

service rabbitmq-server start

rabbitmqctl stop_app
rabbitmqctl join_cluster rabbit@$HOST_CTL_IP1
rabbitmqctl start_app
rabbitmqctl cluster_status

EOF

rabbitmqctl set_cluster_name rabbitmq_os
rabbitmqctl cluster_status


rabbitmqctl add_user openstack $RABBIT_PASS
rabbitmqctl set_permissions openstack ".*" ".*" ".*"
rabbitmqctl change_password guest $RABBIT_PASS
rabbitmqctl set_policy ha-all "^ha\." '{"ha-mode":"all"}'

echocolor "FINISH INSTALL RABBITMQ"
sleep 5
