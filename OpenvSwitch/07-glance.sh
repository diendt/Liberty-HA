#!/bin/bash -ex
#

source config.cfg
source function.sh
source /root/admin-openrc.sh

echo "Create the database for GLANCE"
cat << EOF | mysql -uroot -p$MYSQL_PASS
CREATE DATABASE glance;
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '$GLANCE_DBPASS';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '$GLANCE_DBPASS';
FLUSH PRIVILEGES;
EOF


sleep 5
echo " Create user, endpoint for GLANCE"

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

./07-glance-add.sh $VIP $CON_MGNT_IP1


sleep 3

#Install Glance On Node 2
scp -r ./07-glance-add.sh root@$CON_MGNT_IP2:/root/script/07-glance-add.sh

ssh root@$CON_MGNT_IP2  << EOF
	cd script
	source config.cfg
	source function.sh
	/root/script/07-glance-add.sh $VIP $CON_MGNT_IP2
EOF

sleep 3

#Install Glance On Node 3
scp -r ./07-glance-add.sh root@$CON_MGNT_IP3:/root/script/07-glance-add.sh

ssh root@$CON_MGNT_IP3  << EOF
	cd script
	source config.cfg
	source function.sh
	/root/script/07-glance-add.sh $VIP $CON_MGNT_IP3
EOF


sleep 3
echo "########## Registering Cirros IMAGE for GLANCE ... ##########"

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


