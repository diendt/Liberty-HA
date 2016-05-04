#!/bin/bash -ex
#
source /root/ha-lb/config.cfg
source /root/ha-lb/function.sh
source /root/admin-openrc.sh

echocolor "INSTALL GLANCE - $2"
source /root/admin-openrc.sh
sleep 5

apt-get -y install glance python-glanceclient  --fix-missing 
sleep 3

echocolor "Configuring GLANCE API"
sleep 5 

#/* Back-up file nova.conf
glanceapi_ctl=/etc/glance/glance-api.conf

test -f $glanceapi_ctl.orig || cp $glanceapi_ctl $glanceapi_ctl.orig

#Configuring glance config file /etc/glance/glance-api.conf

#Section [DEFAULT]
ops_edit $glanceapi_ctl DEFAULT verbose True
ops_edit $glanceapi_ctl DEFAULT notification_driver noop
#ops_edit $glanceapi_ctl DEFAULT registry_host $2
#ops_edit $glanceapi_ctl DEFAULT bind_host $2

#Section [database]
ops_edit $glanceapi_ctl database \
connection  mysql+pymysql://glance:$GLANCE_DBPASS@$1/glance
ops_del $glanceapi_ctl database sqlite_db
ops_edit $glanceapi_ctl database backend sqlalchemy

#Section [glance_store]
ops_edit $glanceapi_ctl glance_store default_store file
ops_edit $glanceapi_ctl glance_store \
filesystem_store_datadir /var/lib/glance/images/

#section [keystone_authtoken]
ops_edit $glanceapi_ctl keystone_authtoken auth_uri http://$1:5000
ops_edit $glanceapi_ctl keystone_authtoken auth_url http://$1:35357
ops_edit $glanceapi_ctl keystone_authtoken auth_plugin password
ops_edit $glanceapi_ctl keystone_authtoken project_domain_id default
ops_edit $glanceapi_ctl keystone_authtoken user_domain_id default
ops_edit $glanceapi_ctl keystone_authtoken project_name service
ops_edit $glanceapi_ctl keystone_authtoken username glance
ops_edit $glanceapi_ctl keystone_authtoken password $GLANCE_PASS

#section [paste_deploy]
ops_edit $glanceapi_ctl paste_deploy flavor keystone

#section [glance_store]
ops_edit $glanceapi_ctl glance_store default_store file
ops_edit $glanceapi_ctl glance_store \
filesystem_store_datadir /var/lib/glance/images/

sleep 5
echocolor "Configuring GLANCE REGISTER"
#/* Backup file file glance-registry.conf
glancereg_ctl=/etc/glance/glance-registry.conf
test -f $glancereg_ctl.orig || cp $glancereg_ctl $glancereg_ctl.orig

#rm $glancereg_ctl
#touch $glancereg_ctl
#Config file /etc/glance/glance-registry.conf

#Section [database]
ops_edit $glancereg_ctl database \
connection  mysql+pymysql://glance:$GLANCE_DBPASS@$1/glance
ops_del $glancereg_ctl database sqlite_db
ops_edit $glancereg_ctl database backend sqlalchemy

#section [keystone_authtoken]
ops_edit $glancereg_ctl keystone_authtoken auth_uri http://$1:5000

ops_edit $glancereg_ctl keystone_authtoken auth_url http://$1:35357

ops_edit $glancereg_ctl keystone_authtoken auth_plugin password
ops_edit $glancereg_ctl keystone_authtoken project_domain_id default
ops_edit $glancereg_ctl keystone_authtoken user_domain_id default
ops_edit $glancereg_ctl keystone_authtoken project_name service
ops_edit $glancereg_ctl keystone_authtoken username glance
ops_edit $glancereg_ctl keystone_authtoken password $GLANCE_PASS

#section [paste_deploy]
ops_edit $glancereg_ctl paste_deploy flavor keystone

#Section [DEFAULT]
ops_edit $glancereg_ctl DEFAULT  notification_driver noop
ops_edit $glancereg_ctl DEFAULT  verbose True
#ops_edit $glancereg_ctl DEFAULT bind_host  $2

sleep 2

echocolor "Remove Glance default DB"
test -f /var/lib/glance/glance.sqlite && rm /var/lib/glance/glance.sqlite

#chown glance:glance $fileglanceapicontrol
#chown glance:glance $fileglanceregcontrol

echocolor "Remove Glance default DB"
test -f /var/lib/glance/glance.sqlite && rm /var/lib/glance/glance.sqlite
sleep 5

echocolor "SYNC DB GLANCE"
glance-manage db_sync

sleep 5
echocolor "Restarting GLANCE service"
service glance-registry restart
service glance-api restart


service glance-registry restart
service glance-api restart

sleep 3
echocolor "Registering Cirros IMAGE for GLANCE"


