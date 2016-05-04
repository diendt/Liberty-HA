#!/bin/bash -ex

source config.cfg
source function.sh

echocolor "Install NTP on $CON_MGNT_IP1"

sleep 3

./03-ntp.sh

echocolor "Install NTP on $CON_MGNT_IP2"
sleep 3
scp ./03-ntp.sh root@$CON_MGNT_IP2:/root/script/03-ntp.sh
ssh root@$CON_MGNT_IP2 './script/03-ntp.sh'

echocolor "Install NTP on $CON_MGNT_IP3"
sleep 3
scp ./03-ntp.sh root@$CON_MGNT_IP3:/root/script/03-ntp.sh
ssh root@$CON_MGNT_IP3 './script/03-ntp.sh'

##############################################

echocolor "INSTALL GALERA MARIADB"
sleep 3

echocolor "Install Galera MariaDB on node $CON_MGNT_IP1"
sleep 3

./04-mariadb.sh $CON_MGNT_IP1

echocolor "Restart MYSQL"

service mysql stop 
service mysql start --wsrep-new-cluster

sleep 2

echocolor "Install Galera MariaDB on node $CON_MGNT_IP2"

sleep 3

scp -r ./04-mariadb.sh root@$CON_MGNT_IP2:/root/script/04-mariadb.sh

ssh root@$CON_MGNT_IP2  << EOF
	cd script
	source config.cfg
	source function.sh
	/root/script/04-mariadb.sh $CON_MGNT_IP2
EOF

scp /etc/mysql/debian.cnf root@$CON_MGNT_IP2:/etc/mysql/

ssh root@$CON_MGNT_IP2 'service mysql restart'

sleep 3

echocolor "Install Galera MariaDB on node $CON_MGNT_IP3"
sleep 3

scp -r ./04-mariadb.sh root@$CON_MGNT_IP3:/root/script/04-mariadb.sh

ssh root@$CON_MGNT_IP3  << EOF
    cd script
	source config.cfg
	source function.sh
	/root/script/04-mariadb.sh $CON_MGNT_IP3
EOF

scp /etc/mysql/debian.cnf root@$CON_MGNT_IP3:/etc/mysql/

ssh root@$CON_MGNT_IP3 'service mysql restart'

sleep 3

echocolor "cluster check"

#prepare
cp clustercheck /usr/bin/
chmod +x /usr/bin/clustercheck

scp /usr/bin/clustercheck root@$CON_MGNT_IP2:/usr/bin/
scp /usr/bin/clustercheck root@$CON_MGNT_IP3:/usr/bin/

#Creat user mysql to check cluster
cat <<EOF | mysql -u root -p$MYSQL_PASS
GRANT PROCESS ON *.* TO 'clustercheckuser'@'localhost' IDENTIFIED BY 'clustercheckpassword!' ;
FLUSH PRIVILEGES;
EOF


#On Node 1
# install xinetd
apt-get install xinetd -y
sleep 1

cp mysqlchk /etc/xinetd.d/
echo "mysqlchk    9200/tcp		#MySQL check" >> /etc/services

sleep 1
service xinetd restart

#Install on Node2

ssh root@$CON_MGNT_IP2 'apt-get install xinetd -y'
scp /root/script/mysqlchk root@$CON_MGNT_IP2:/etc/xinetd.d/

cat << EOF | ssh root@$CON_MGNT_IP2

echo "mysqlchk    9200/tcp		#MySQL check" >> /etc/services
service xinetd restart

EOF
sleep 2

#Install On Node3
ssh root@$CON_MGNT_IP3 'apt-get install xinetd -y'
scp /root/script/mysqlchk root@$CON_MGNT_IP3:/etc/xinetd.d/

ssh root@$CON_MGNT_IP3 << EOF

echo "mysqlchk    9200/tcp		#MySQL check" >> /etc/services
service xinetd restart

EOF
sleep 2

###########################################################
echocolor "INSTALL AND CONFIG RABBITMQ"

sleep 2

echocolor "Install and Config RabbitMQ"

sleep 3

#Node1
apt-get install rabbitmq-server -y  --fix-missing 
echo "NODE_IP_ADDRESS=$CON_MGNT_IP1" >>  /etc/rabbitmq/rabbitmq-env.conf

sleep 3
service rabbitmq-server restart 

sleep 2

#Connect ssh to Node 2

cat << EOF | ssh root@$CON_MGNT_IP2
cd script
source config.cfg

apt-get install rabbitmq-server -y  --fix-missing 
echo "NODE_IP_ADDRESS=$CON_MGNT_IP2" >>  /etc/rabbitmq/rabbitmq-env.conf

service rabbitmq-server restrart

service rabbitmq-server stop
EOF

#Connect ssh to Node 3

cat << EOF | ssh root@$CON_MGNT_IP3

cd script
source config.cfg

apt-get install rabbitmq-server -y  --fix-missing 
echo "NODE_IP_ADDRESS=$CON_MGNT_IP3" >>  /etc/rabbitmq/rabbitmq-env.conf

service rabbitmq-server restrart
service rabbitmq-server stop
EOF

echocolor "Config cluster"
#On Node 1
service rabbitmq-server stop
scp /var/lib/rabbitmq/.erlang.cookie root@$CON_MGNT_IP2:/var/lib/rabbitmq/.erlang.cookie
scp /var/lib/rabbitmq/.erlang.cookie root@$CON_MGNT_IP3:/var/lib/rabbitmq/.erlang.cookie

service rabbitmq-server start

#Join node 2, node 3 to cluster
cat << EOF | ssh root@$CON_MGNT_IP2
cd script
source config.cfg

service rabbitmq-server start

rabbitmqctl stop_app
rabbitmqctl join_cluster rabbit@$HOST_CTL_IP1
rabbitmqctl start_app
rabbitmqctl cluster_status
#exit
EOF


cat << EOF | ssh root@$CON_MGNT_IP3
cd script
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


echocolor "INSTALL HARPROXY &KEEPALIVED PACKAGE ON  $CON_MGNT_IP1"

sleep 5

./05-haproxy.sh

#Node 2
echocolor "INSTALL HARPROXY &KEEPALIVED PACKAGE ON $CON_MGNT_IP2" 

sleep 5

cd script
./05-haproxy-other.sh $CON_MGNT_IP2

#Node3
echocolor "INSTALL HARPROXY &KEEPALIVED PACKAGE ON $CON_MGNT_IP3" 
sleep 5

cd script
./05-haproxy-other.sh $CON_MGNT_IP3

echocolor "END OF PREPARE"
