#!/bin/bash -ex
#

source config.cfg
source function.sh
source /root/admin-openrc.sh
echocolor "Create DB for CINDER"
sleep 5
cat << EOF | mysql -uroot -p$MYSQL_PASS
CREATE DATABASE cinder;
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY '$CINDER_DBPASS';
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' IDENTIFIED BY '$CINDER_DBPASS';
FLUSH PRIVILEGES;
EOF

echocolor "Create  user, endpoint for CINDER"
sleep 5
openstack user create --password $CINDER_PASS cinder
openstack role add --project service --user cinder admin
openstack service create --name cinder --description "OpenStack Block Storage" volume
openstack service create --name cinderv2 --description "OpenStack Block Storage" volumev2

openstack endpoint create \
--publicurl http://$VIP:8776/v1/%\(tenant_id\)s \
--internalurl http://$VIP:8776/v1/%\(tenant_id\)s \
--adminurl http://$VIP:8776/v1/%\(tenant_id\)s \
--region RegionOne \
volume


openstack endpoint create \
--publicurl http://$VIP:8776/v2/%\(tenant_id\)s \
--internalurl http://$VIP:8776/v2/%\(tenant_id\)s \
--adminurl http://$VIP:8776/v2/%\(tenant_id\)s \
--region RegionOne \
volumev2

#openstack endpoint create --region RegionOne \
#  volume public http://$VIP:8776/v1/%\(tenant_id\)s

#openstack endpoint create --region RegionOne \
#  volume internal http://$VIP:8776/v1/%\(tenant_id\)s

#openstack endpoint create --region RegionOne \
#  volume admin http://$VIP:8776/v1/%\(tenant_id\)s

#openstack endpoint create --region RegionOne \
#volumev2 public http://$VIP:8776/v2/%\(tenant_id\)s

#openstack endpoint create --region RegionOne \
#  volumev2 internal http://$VIP:8776/v2/%\(tenant_id\)s

#openstack endpoint create --region RegionOne \
#  volumev2 admin http://$VIP:8776/v2/%\(tenant_id\)s


#
echocolor "Install CINDER"
sleep 3
./07-cinder-add.sh $VIP $CON_MGNT_IP1
#./06-2-l3-agent-neutron.sh

#Install Neutron On Node 2
echocolor "INSTALL NEUTRON ON $CON_MGNT_IP2"
sleep 3

scp -r ./07-cinder-add.sh root@$CON_MGNT_IP2:/root/script/        
#scp -r ./07-cinder-add.sh root@$CON_MGNT_IP2:/root/script/07-cinder-add.sh

ssh root@$CON_MGNT_IP2  bash -ex << EOF
	cd script
	source config.cfg
	source function.sh
	/root/script/07-cinder-add.sh $VIP $CON_MGNT_IP2
	reboot
EOF

#Install Neutron On Node 3
echocolor "INSTALL NEUTRON ON $CON_MGNT_IP3"
sleep 3

#Install Neutron On Node 3
scp -r ./07-cinder-add.sh ./06-2-l3-agent-neutron.sh root@$CON_MGNT_IP3:/root/script/

ssh root@$CON_MGNT_IP3 bash -ex << EOF
	cd script
	source config.cfg
	source function.sh
	/root/script/07-cinder-add.sh $VIP $CON_MGNT_IP3
	reboot
EOF




echocolor "Finish setting up CINDER"