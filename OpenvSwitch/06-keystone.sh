#!/bin/bash -ex
#

source config.cfg
source function.sh

echocolor "Install Openstack components on $CON_MGNT_IP1"


echocolor "INSTALL KEYSTONE"

echocolor "Create Database for Keystone"

cat << EOF | mysql -uroot -p$MYSQL_PASS
CREATE DATABASE keystone;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '$KEYSTONE_DBPASS';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '$KEYSTONE_DBPASS';
FLUSH PRIVILEGES;
EOF

./06-keystone-add.sh $VIP $CON_MGNT_IP1


sleep 3

echocolor "CREATE SOMETHING"
sleep 3

export OS_TOKEN="$TOKEN_PASS"
export OS_URL=http://$VIP:35357/v2.0
 
###  Identity service
openstack service create --name keystone --description "OpenStack Identity" identity

### Create the Identity service API endpoint
openstack endpoint create \
--publicurl http://$VIP:5000/v2.0 \
--internalurl http://$VIP:5000/v2.0 \
--adminurl http://$VIP:35357/v2.0 \
--region RegionOne \
identity
 
#### To create tenants, users, and roles ADMIN
openstack project create --description "Admin Project" admin
openstack user create --password  $ADMIN_PASS admin
openstack role create admin
openstack role add --project admin --user admin admin
 
#### To create tenants, users, and roles  SERVICE
openstack project create --description "Service Project" service
 
 
#### To create tenants, users, and roles  DEMO
openstack project create --description "Demo Project" demo
openstack user create --password $ADMIN_PASS demo
 
### Create the user role
openstack role create user
openstack role add --project demo --user demo user
 
#################
 
unset OS_TOKEN OS_URL
 
 
echocolor "Install Openstack components on $CON_MGNT_IP2"

sleep 3

scp -r ./06-keystone-add.sh root@$CON_MGNT_IP2:/root/script/06-keystone-add.sh

ssh root@$CON_MGNT_IP2  bash -ex << EOF
	cd script
	source config.cfg
	source function.sh
	/root/script/06-keystone-add.sh $VIP $CON_MGNT_IP2
	#/root/script/06-keystone-add.sh
EOF

echocolor "Install Openstack components on $CON_MGNT_IP3"
sleep 3

scp -r ./06-keystone-add.sh root@$CON_MGNT_IP3:/root/script/06-keystone-add.sh

ssh root@$CON_MGNT_IP3  bash -ex<< EOF
	cd script
	source config.cfg
	source function.sh
	/root/script/06-keystone-add.sh $VIP $CON_MGNT_IP3
	#/root/script/06-keystone-add.sh
EOF



service haproxy restart


