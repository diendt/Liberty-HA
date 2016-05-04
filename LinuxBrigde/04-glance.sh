#!/bin/bash -ex
#

source /root/ha-lb/config.cfg
source /root/ha-lb/function.sh
source /root/admin-openrc.sh

echo "Create the database for GLANCE"
cat << EOF | mysql -uroot -p$MYSQL_PASS
CREATE DATABASE glance;
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '$GLANCE_DBPASS';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '$GLANCE_DBPASS';
FLUSH PRIVILEGES;
EOF


sleep 2
echo " Create user, endpoint for GLANCE"
sleep 3

openstack user create --password $ADMIN_PASS glance
openstack role add --project service --user glance admin
openstack service create --name glance --description "OpenStack Image service" image

openstack endpoint create \
--publicurl http://$VIP:9292 \
--internalurl http://$VIP:9292 \
--adminurl http://$VIP:9292 \
--region RegionOne \
image


#Install Glance On Node 1

echocolor "Install Glance On $CON_MGNT_IP1"
sleep 3
./04-1-add-glance.sh $VIP $CON_MGNT_IP1

sleep 2

#Install Glance On Node 2
echocolor "Install Glance On $CON_MGNT_IP2"
sleep 3

scp -r ./04-1-add-glance.sh root@$CON_MGNT_IP2:/root/ha-lb/04-1-add-glance.sh

ssh root@$CON_MGNT_IP2  bash -ex << EOF
	cd ha-lb
	source config.cfg
	source function.sh
	/root/ha-lb/04-1-add-glance.sh $VIP $CON_MGNT_IP2
EOF


#Install Glance On Node 3
echocolor "Install Glance On $CON_MGNT_IP3"
sleep 3

scp -r ./04-1-add-glance.sh root@$CON_MGNT_IP3:/root/ha-lb/04-1-add-glance.sh

ssh root@$CON_MGNT_IP3  bash -ex << EOF
    cd ha-lb
	source config.cfg
	source function.sh
	/root/ha-lb/04-1-add-glance.sh $VIP $CON_MGNT_IP3
EOF


sleep 2
echo "########## Registering Cirros IMAGE for GLANCE ... ##########"
sleep 3

test -d ./images && cd images/ || mkdir images

wget http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img

glance image-create --name "cirros" \
--file cirros-0.3.4-x86_64-disk.img \
--disk-format qcow2 --container-format bare \
--visibility public --progress

cd /root/
# rm -r /tmp/images

sleep 5
echo "########## Testing Glance ##########"
glance image-list

echo "########## Finish Glance ##########"


