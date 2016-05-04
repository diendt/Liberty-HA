#!/bin/bash -ex
#

source config.cfg
source function.sh
source /root/admin-openrc.sh

echocolor "Create DB for NOVA "

cat << EOF | mysql -uroot -p$MYSQL_PASS
CREATE DATABASE nova;
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '$NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY '$NOVA_DBPASS';
FLUSH PRIVILEGES;
EOF


echocolor "Creat user, endpoint for NOVA"

openstack user create --password $ADMIN_PASS nova
openstack role add --project service --user nova admin
openstack service create --name nova --description "OpenStack Compute" compute

openstack endpoint create \
--publicurl http://$VIP:8774/v2/%\(tenant_id\)s \
--internalurl http://$VIP:8774/v2/%\(tenant_id\)s \
--adminurl http://$VIP:8774/v2/%\(tenant_id\)s \
--region RegionOne \
compute

#Install Nova On Node 1
echocolor "Install Nova On $CON_MGNT_IP1"
sleep 3

./05-1-add-nova.sh $VIP $CON_MGNT_IP1

sleep 3

#Install Nova On Node 2
echocolor "Install Nova On $CON_MGNT_IP2"
sleep 3

scp -r ./05-1-add-nova.sh root@$CON_MGNT_IP2:/root/ha-lb/05-1-add-nova.sh

ssh root@$CON_MGNT_IP2  bash -ex << EOF
    cd ha-lb
	source config.cfg
	source function.sh
	/root/ha-lb/05-1-add-nova.sh $VIP $CON_MGNT_IP2
EOF

#Install Nova On Node 3
echocolor "Install Nova On $CON_MGNT_IP3"
sleep 3

scp -r ./05-1-add-nova.sh root@$CON_MGNT_IP3:/root/ha-lb/05-1-add-nova.sh

ssh root@$CON_MGNT_IP3  bash -ex << EOF
    cd ha-lb
	source config.cfg
	source function.sh
	/root/ha-lb/05-1-add-nova.sh $VIP $CON_MGNT_IP3
EOF

echocolor "Testing NOVA service"

for i in `ls /etc/init.d/ | grep nova`; do service $i restart; done

nova-manage service list

echocolor "Finish nova"
