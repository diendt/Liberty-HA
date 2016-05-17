#!/bin/bash -ex
#

source config.cfg
source function.sh
source /root/admin-openrc.sh

echocolor "INSTALL NOVA - $2"

echo "Install NOVA in $2"
sleep 5 
apt-get -y install nova-api nova-cert nova-conductor nova-consoleauth nova-novncproxy nova-scheduler python-novaclient  --fix-missing 

# Cai tu dong libguestfs-tools 
#echo "libguestfs-tools        libguestfs/update-appliance     boolean true"  | debconf-set-selections

apt-get -y install libguestfs-tools sysfsutils guestfsd python-guestfs --fix-missing 

sleep 5

#
nova_ctl=/etc/nova/nova.conf
test -f $nova_ctl.orig || cp $nova_ctl $nova_ctl.orig
#rm $nova_ctl
#touch $nova_ctl

#section [DEFAULT]
ops_edit $nova_ctl DEFAULT verbose True
ops_edit $nova_ctl DEFAULT rpc_backend rabbit
ops_edit $nova_ctl DEFAULT auth_strategy keystone

ops_edit $nova_ctl DEFAULT force_dhcp_release True
ops_edit $nova_ctl DEFAULT libvirt_use_virtio_for_bridges True
ops_edit $nova_ctl DEFAULT ec2_private_dns_show_ip True
ops_edit $nova_ctl DEFAULT enabled_apis osapi_compute,metadata

ops_edit $nova_ctl DEFAULT api_paste_config /etc/nova/api-paste.ini
ops_edit $nova_ctl DEFAULT enable_instance_password  True
ops_edit $nova_ctl DEFAULT my_ip $2
ops_edit $nova_ctl DEFAULT novncproxy_host $2
ops_edit $nova_ctl DEFAULT osapi_compute_listen $2
ops_edit $nova_ctl DEFAULT metadata_host $2
ops_edit $nova_ctl DEFAULT metadata_listen $2
ops_edit $nova_ctl DEFAULT xvpvncproxy_host $2

ops_edit $nova_ctl DEFAULT \
network_api_class nova.network.neutronv2.api.API
ops_edit $nova_ctl DEFAULT security_group_api neutron
ops_edit $nova_ctl DEFAULT \
linuxnet_interface_driver nova.network.linux_net.NeutronLinuxBridgeInterfaceDriver

ops_edit $nova_ctl DEFAULT \
firewall_driver nova.virt.firewall.NoopFirewallDriver

#section [database]
ops_edit $nova_ctl database \
connection mysql+pymysql://nova:$NOVA_DBPASS@$1/nova

#section [oslo_messaging_rabbit]
ops_edit $nova_ctl oslo_messaging_rabbit rabbit_hosts   \
$CON_MGNT_IP1:5672,$CON_MGNT_IP2:5672,$CON_MGNT_IP3:5672
ops_edit $nova_ctl oslo_messaging_rabbit rabbit_userid   openstack
ops_edit $nova_ctl oslo_messaging_rabbit rabbit_password   $RABBIT_PASS
ops_edit $nova_ctl oslo_messaging_rabbit rabbit_retry_interval 1
ops_edit $nova_ctl oslo_messaging_rabbit rabbit_retry_backoff 2
ops_edit $nova_ctl oslo_messaging_rabbit rabbit_max_retries 0
ops_edit $nova_ctl oslo_messaging_rabbit rabbit_durable_queues true
ops_edit $nova_ctl oslo_messaging_rabbit rabbit_ha_queues   True
ops_edit $nova_ctl oslo_messaging_rabbit heartbeat_timeout_threshold   60
ops_edit $nova_ctl oslo_messaging_rabbit heartbeat_rate   2

#section [keystone_authtoken]
ops_edit $nova_ctl keystone_authtoken auth_uri http://$1:5000
ops_edit $nova_ctl keystone_authtoken auth_url http://$1:35357
ops_edit $nova_ctl keystone_authtoken auth_plugin password
ops_edit $nova_ctl keystone_authtoken project_domain_id default
ops_edit $nova_ctl keystone_authtoken user_domain_id default
ops_edit $nova_ctl keystone_authtoken project_name service
ops_edit $nova_ctl keystone_authtoken username nova
ops_edit $nova_ctl keystone_authtoken password $NOVA_PASS

#section [vnc]
ops_edit $nova_ctl vnc vncserver_listen \$my_ip
ops_edit $nova_ctl vnc vncserver_proxyclient_address \$my_ip

#section [glance]
ops_edit $nova_ctl glance host $1

#section [oslo_concurrency]
ops_edit $nova_ctl oslo_concurrency lock_path /var/lib/nova/tmp

#section [neutron]
ops_edit $nova_ctl neutron url http://$1:9696
ops_edit $nova_ctl neutron auth_url http://$1:35357
ops_edit $nova_ctl neutron auth_plugin password
ops_edit $nova_ctl neutron project_domain_id default
ops_edit $nova_ctl neutron user_domain_id default
ops_edit $nova_ctl neutron region_name RegionOne
ops_edit $nova_ctl neutron project_name service
ops_edit $nova_ctl neutron username neutron
ops_edit $nova_ctl neutron password $NEUTRON_PASS
ops_edit $nova_ctl neutron service_metadata_proxy True
ops_edit $nova_ctl neutron metadata_proxy_shared_secret $METADATA_SECRET

## [cinder] Section 
ops_edit $nova_ctl cinder os_region_name RegionOne

echocolor "Remove Nova default db"
sleep 3
test -f /var/lib/nova/nova.sqlite && rm /var/lib/nova/nova.sqlite

echocolor "Syncing Nova DB"
sleep 3 
su -s /bin/sh -c "nova-manage db sync" nova

# fix bug libvirtError: internal error: no supported architecture for os type 'hvm'
# echo 'kvm_intel' >> /etc/modules

echocolor "Restarting NOVA"
sleep 5 

for i in `ls /etc/init.d/ | grep nova`; do service $i restart; done


