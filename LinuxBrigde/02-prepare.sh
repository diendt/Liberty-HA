#!/bin/bash -ex
#
source config.cfg
source function.sh

#install node 1


#Instal NTP

echocolor "INSTALL NTP NODE $CON_MGNT_IP1"

./02-1-ntp.sh


echocolor "INSTALL NTP NODE $CON_MGNT_IP2"
sleep 3
scp ./02-1-ntp.sh root@$CON_MGNT_IP2:/root/02-1-ntp.sh
ssh root@$CON_MGNT_IP2 './02-1-ntp.sh'

echocolor "INSTALL NTP NODE $CON_MGNT_IP3"
sleep 3
scp ./02-1-ntp.sh root@$CON_MGNT_IP3:/root/02-1-ntp.sh
ssh root@$CON_MGNT_IP3 './02-1-ntp.sh'

echocolor "FINISH INSTALL NTP"

#INSTALL GALERA MARIADB
echocolor "INSTALL MARIADB"

echocolor "Install Galera MariaDB on node $CON_MGNT_IP1"
sleep 3

./02-2-mariadb.sh $CON_MGNT_IP1

echocolor "Restart MYSQL"

service mysql stop 
service mysql start --wsrep-new-cluster

sleep 2

echocolor "Install Galera MariaDB on node $CON_MGNT_IP2"

sleep 3

scp -r ./02-2-mariadb.sh root@$CON_MGNT_IP2:/root/02-2-mariadb.sh

ssh root@$CON_MGNT_IP2  << EOF
	source config.cfg
	source function.sh
	/root/02-2-mariadb.sh $CON_MGNT_IP2
EOF

scp /etc/mysql/debian.cnf root@$CON_MGNT_IP2:/etc/mysql/

ssh root@$CON_MGNT_IP2 'service mysql restart'

sleep 3

echocolor "Install Galera MariaDB on node $CON_MGNT_IP3"
sleep 3

scp -r ./02-2-mariadb.sh root@$CON_MGNT_IP3:/root/02-2-mariadb.sh

ssh root@$CON_MGNT_IP3  << EOF
	source config.cfg
	source function.sh
	/root/02-2-mariadb.sh $CON_MGNT_IP3
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
scp /root/mysqlchk root@$CON_MGNT_IP2:/etc/xinetd.d/

cat << EOF | ssh root@$CON_MGNT_IP2

echo "mysqlchk    9200/tcp		#MySQL check" >> /etc/services
service xinetd restart

EOF
sleep 2

#Install On Node3
ssh root@$CON_MGNT_IP3 'apt-get install xinetd -y'
scp /root/mysqlchk root@$CON_MGNT_IP3:/etc/xinetd.d/

ssh root@$CON_MGNT_IP3 << EOF

echo "mysqlchk    9200/tcp		#MySQL check" >> /etc/services
service xinetd restart

EOF
sleep 2 

./02-3-rabbitmq.sh
