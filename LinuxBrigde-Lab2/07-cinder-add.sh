#!/bin/bash -ex
#

source config.cfg
source function.sh
source /root/admin-openrc.sh

#
echocolor "Install CINDER"
sleep 3
apt-get install cinder-api cinder-scheduler python-cinderclient

cinder_ctl=/etc/cinder/cinder.conf
test -f $cinder_ctl.orig || cp $cinder_ctl $cinder_ctl.orig

## [DEFAULT] section
ops_edit $cinder_ctl DEFAULT rpc_backend rabbit
ops_edit $cinder_ctl DEFAULT auth_strategy keystone
ops_edit $cinder_ctl DEFAULT my_ip $2
ops_edit $cinder_ctl DEFAULT verbose True
ops_edit $cinder_ctl DEFAULT enabled_backends lvm
ops_edit $cinder_ctl DEFAULT glance_host $1
ops_edit $cinder_ctl DEFAULT osapi_volume_listen $1
ops_edit $cinder_ctl DEFAULT notification_driver messagingv2

## [database] section
ops_edit $cinder_ctl database \
connection mysql+pymysql://cinder:$CINDER_DBPASS@$1/cinder

## [oslo_messaging_rabbit] section
ops_edit $cinder_ctl oslo_messaging_rabbit rabbit_hosts   \
$CON_MGNT_IP1:5672,$CON_MGNT_IP2:5672,$CON_MGNT_IP3:5672
ops_edit $cinder_ctl oslo_messaging_rabbit rabbit_userid   openstack
ops_edit $cinder_ctl oslo_messaging_rabbit rabbit_password   $RABBIT_PASS
ops_edit $cinder_ctl oslo_messaging_rabbit rabbit_retry_interval 1
ops_edit $cinder_ctl oslo_messaging_rabbit rabbit_retry_backoff 2
ops_edit $cinder_ctl oslo_messaging_rabbit rabbit_max_retries 0
ops_edit $cinder_ctl oslo_messaging_rabbit rabbit_durable_queues true
ops_edit $cinder_ctl oslo_messaging_rabbit rabbit_ha_queues   True
ops_edit $cinder_ctl oslo_messaging_rabbit heartbeat_timeout_threshold   60
ops_edit $cinder_ctl oslo_messaging_rabbit heartbeat_rate   2

## [keystone_authtoken] section
ops_edit $cinder_ctl keystone_authtoken auth_uri http://$1:5000
ops_edit $cinder_ctl keystone_authtoken auth_url http://$1:35357
ops_edit $cinder_ctl keystone_authtoken auth_type password
ops_edit $cinder_ctl keystone_authtoken project_domain_id default
ops_edit $cinder_ctl keystone_authtoken user_domain_id default
ops_edit $cinder_ctl keystone_authtoken project_name service
ops_edit $cinder_ctl keystone_authtoken username cinder
ops_edit $cinder_ctl keystone_authtoken password $CINDER_PASS

## [oslo_concurrency] section
ops_edit $cinder_ctl oslo_concurrency lock_path /var/lib/cinder/tmp



echocolor "Syncing Cinder DB"
sleep 3
su -s /bin/sh -c "cinder-manage db sync" cinder
 
echocolor "Restarting CINDER service"
sleep 3
service nova-api restart
service cinder-api restart
service cinder-scheduler restart

rm -f /var/lib/cinder/cinder.sqlite

echocolor "Finish setting up CINDER"