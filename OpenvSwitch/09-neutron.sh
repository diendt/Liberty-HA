#!/bin/bash -ex
#
source config.cfg
source function.sh
source /root/admin-openrc.sh

echocolor "Create DB for NEUTRON "
sleep 5
cat << EOF | mysql -uroot -p$MYSQL_PASS
CREATE DATABASE neutron;
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY '$NEUTRON_DBPASS';
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY '$NEUTRON_DBPASS';
FLUSH PRIVILEGES;
EOF


echo "Create  user, endpoint for NEUTRON"
sleep 5
openstack user create --password $ADMIN_PASS neutron
openstack role add --project service --user neutron admin
openstack service create --name neutron --description "OpenStack Networking" network
 
openstack endpoint create \
  --publicurl http://$VIP:9696 \
  --adminurl http://$VIP:9696 \
  --internalurl http://$VIP:9696 \
  --region RegionOne \
  network 
  
# SERVICE_TENANT_ID=`keystone tenant-get service | awk '$2~/^id/{print $4}'`


./09-neutron-add.sh $VIP $CON_MGNT_IP1

sleep 3

#Install Neutron On Node 2
scp -r ./09-neutron-add.sh root@$CON_MGNT_IP2:/root/script/09-neutron-add.sh

ssh root@$CON_MGNT_IP2  << EOF
	cd script
	source config.cfg
	source function.sh
	/root/script/09-neutron-add.sh $VIP $CON_MGNT_IP2
	reboot
EOF

sleep 3

#Install Neutron On Node 3
scp -r ./09-neutron-add.sh root@$CON_MGNT_IP3:/root/script/09-neutron-add.sh

ssh root@$CON_MGNT_IP3  << EOF
	cd script
	source config.cfg
	source function.sh
	/root/script/09-neutron-add.sh $VIP $CON_MGNT_IP3
	reboot
EOF

reboot


