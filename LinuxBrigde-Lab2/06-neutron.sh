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

#Install Neutron On Node 1
echocolor "INSTALL NEUTRON ON $CON_MGNT_IP1"
sleep 3

./06-1-add-neutron.sh $VIP $CON_MGNT_IP1
#./06-2-l3-agent-neutron.sh

#Install Neutron On Node 2
echocolor "INSTALL NEUTRON ON $CON_MGNT_IP2"
sleep 3

scp -r ./06-1-add-neutron.sh ./06-2-l3-agent-neutron.sh root@$CON_MGNT_IP2:/root/script/        
#scp -r ./06-1-add-neutron.sh root@$CON_MGNT_IP2:/root/script/06-1-add-neutron.sh

ssh root@$CON_MGNT_IP2  bash -ex << EOF
	cd script
	source config.cfg
	source function.sh
	/root/script/06-1-add-neutron.sh $VIP $CON_MGNT_IP2
	#/root/script/06-2-l3-agent-neutron.sh
	reboot
EOF

#Install Neutron On Node 3
echocolor "INSTALL NEUTRON ON $CON_MGNT_IP3"
sleep 3

#Install Neutron On Node 3
scp -r ./06-1-add-neutron.sh ./06-2-l3-agent-neutron.sh root@$CON_MGNT_IP3:/root/script/

ssh root@$CON_MGNT_IP3 bash -ex << EOF
	cd script
	source config.cfg
	source function.sh
	/root/script/06-1-add-neutron.sh $VIP $CON_MGNT_IP3
	#/root/script/06-2-l3-agent-neutron.sh
	reboot
EOF


