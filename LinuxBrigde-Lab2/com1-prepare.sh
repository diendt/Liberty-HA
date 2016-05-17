#!/bin/bash -ex
#

source config.cfg
source function.sh
#
echocolor "Install python openstack client"
apt-get -y install python-openstackclient

echocolor "Install NTP"

apt-get install ntp -y
apt-get install python-mysqldb -y
#
echocolor "Backup NTP configuration... "
sleep 3
cp /etc/ntp.conf /etc/ntp.conf.bka
rm /etc/ntp.conf
cat /etc/ntp.conf.bka | grep -v ^# | grep -v ^$ >> /etc/ntp.conf
#
sed -i 's/server 0.ubuntu.pool.ntp.org/ \
#server 0.ubuntu.pool.ntp.org/g' /etc/ntp.conf

sed -i 's/server 1.ubuntu.pool.ntp.org/ \
#server 1.ubuntu.pool.ntp.org/g' /etc/ntp.conf

sed -i 's/server 2.ubuntu.pool.ntp.org/ \
#server 2.ubuntu.pool.ntp.org/g' /etc/ntp.conf

sed -i 's/server 3.ubuntu.pool.ntp.org/ \
#server 3.ubuntu.pool.ntp.org/g' /etc/ntp.conf

sed -i "s/server ntp.ubuntu.com/server $CON_MGNT_IP iburst/g" /etc/ntp.conf


echocolor  "Installl package for NOVA"
sleep 5
apt-get -y install nova-compute 

#echo "libguestfs-tools        libguestfs/update-appliance     boolean true"  | debconf-set-selections
apt-get -y install libguestfs-tools sysfsutils guestfsd python-guestfs
#fix loi chen pass tren hypervisor la KVM
#update-guestfs-appliance
#chmod 0644 /boot/vmlinuz*
#usermod -a -G kvm root

echocolor "Configuring in nova.conf"
sleep 5
########
#/* Sao luu truoc khi sua file nova.conf
nova_com=/etc/nova/nova.conf
test -f $nova_com.orig || cp $nova_com $nova_com.orig

#Chen noi dung file /etc/nova/nova.conf vao 
## [DEFAULT] section
ops_edit $nova_com DEFAULT dhcpbridge_flagfile /etc/nova/nova.conf
ops_edit $nova_com DEFAULT dhcpbridge /usr/bin/nova-dhcpbridge
ops_edit $nova_com DEFAULT logdir /var/log/nova
ops_edit $nova_com DEFAULT state_path /var/lib/nova
ops_edit $nova_com DEFAULT lock_path /var/lock/nova
ops_edit $nova_com DEFAULT force_dhcp_release True
ops_edit $nova_com DEFAULT libvirt_use_virtio_for_bridges True
ops_edit $nova_com DEFAULT verbose True
ops_edit $nova_com DEFAULT ec2_private_dns_show_ip True
ops_edit $nova_com DEFAULT api_paste_config /etc/nova/api-paste.ini
ops_edit $nova_com DEFAULT enabled_apis ec2,osapi_compute,metadata

ops_edit $nova_com DEFAULT rpc_backend  rabbit
ops_edit $nova_com DEFAULT auth_strategy  keystone
ops_edit $nova_com DEFAULT my_ip  $COM1_MGNT_IP

ops_edit $nova_com DEFAULT network_api_class  nova.network.neutronv2.api.API
ops_edit $nova_com DEFAULT security_group_api  neutron
ops_edit $nova_com DEFAULT linuxnet_interface_driver  nova.network.linux_net.NeutronLinuxBridgeInterfaceDriver
ops_edit $nova_com DEFAULT firewall_driver  nova.virt.firewall.NoopFirewallDriver
ops_edit $nova_com DEFAULT enable_instance_password  True

## [oslo_messaging_rabbit] section
ops_edit $nova_com oslo_messaging_rabbit rabbit_hosts   \
$CON_MGNT_IP1:5672,$CON_MGNT_IP2:5672,$CON_MGNT_IP3:5672
ops_edit $nova_com oslo_messaging_rabbit rabbit_userid   openstack
ops_edit $nova_com oslo_messaging_rabbit rabbit_password   $RABBIT_PASS
ops_edit $nova_com oslo_messaging_rabbit rabbit_retry_interval 1
ops_edit $nova_com oslo_messaging_rabbit rabbit_retry_backoff 2
ops_edit $nova_com oslo_messaging_rabbit rabbit_max_retries 0
ops_edit $nova_com oslo_messaging_rabbit rabbit_durable_queues true
ops_edit $nova_com oslo_messaging_rabbit rabbit_ha_queues   True
ops_edit $nova_com oslo_messaging_rabbit heartbeat_timeout_threshold   60
ops_edit $nova_com oslo_messaging_rabbit heartbeat_rate   2

## [keystone_authtoken] section
ops_edit $nova_com keystone_authtoken auth_uri  http://$VIP:5000
ops_edit $nova_com keystone_authtoken auth_url  http://$VIP:35357
ops_edit $nova_com keystone_authtoken auth_plugin  password
ops_edit $nova_com keystone_authtoken project_domain_id  default
ops_edit $nova_com keystone_authtoken user_domain_id  default
ops_edit $nova_com keystone_authtoken project_name  service
ops_edit $nova_com keystone_authtoken username  nova
ops_edit $nova_com keystone_authtoken password  $KEYSTONE_PASS

## [vnc] section
ops_edit $nova_com vnc enabled  True
ops_edit $nova_com vnc vncserver_listen  0.0.0.0
ops_edit $nova_com vnc vncserver_proxyclient_address  \$my_ip
ops_edit $nova_com vnc novncproxy_base_url  http://$VIP:6080/vnc_auto.html

# [glance] section
ops_edit $nova_com glance host  $VIP

# [oslo_concurrency] section
ops_edit $nova_com oslo_concurrency lock_path  /var/lib/nova/tmp

## [neutron] section
ops_edit $nova_com neutron url  http://$VIP:9696
ops_edit $nova_com neutron auth_url  http://$VIP:35357
ops_edit $nova_com neutron auth_plugin  password
ops_edit $nova_com neutron project_domain_id  default
ops_edit $nova_com neutron user_domain_id  default
ops_edit $nova_com neutron region_name  RegionOne
ops_edit $nova_com neutron project_name  service
ops_edit $nova_com neutron username  neutron
ops_edit $nova_com neutron password  $NEUTRON_PASS

## [libvirt] section
ops_edit $nova_com libvirt inject_key  True
ops_edit $nova_com libvirt inject_partition  -1
ops_edit $nova_com libvirt inject_password  True


echocolor "Restart nova-compute"
sleep 5
service nova-compute restart

echocolor "Remove default nova db"
#rm /var/lib/nova/nova.sqlite

echocolor "Install linuxbridge-agent (neutron) on COMPUTE NODE"
sleep 5

apt-get -y install neutron-plugin-linuxbridge-agent

echo "Config file neutron.conf"
neutron_com=/etc/neutron/neutron.conf
test -f $neutron_com.orig || cp $neutron_com $neutron_com.orig

## [DEFAULT] section
ops_edit $neutron_com DEFAULT core_plugin  ml2
ops_edit $neutron_com DEFAULT rpc_backend  rabbit
ops_edit $neutron_com DEFAULT auth_strategy  keystone
ops_edit $neutron_com DEFAULT verbose  True
#[agent]
#ops_edit $neutron_com DEFAULT root_helper  sudo /usr/bin/neutron-rootwrap /etc/neutron/rootwrap.conf

## [keystone_authtoken] section
ops_edit $neutron_com keystone_authtoken auth_uri  http://$VIP:5000
ops_edit $neutron_com keystone_authtoken auth_url  http://$VIP:35357
ops_edit $neutron_com keystone_authtoken auth_plugin  password
ops_edit $neutron_com keystone_authtoken project_domain_id  default
ops_edit $neutron_com keystone_authtoken user_domain_id  default
ops_edit $neutron_com keystone_authtoken project_name  service
ops_edit $neutron_com keystone_authtoken username  neutron
ops_edit $neutron_com keystone_authtoken password  $KEYSTONE_PASS

## [database] section 
ops_del $neutron_com database connection

## [oslo_concurrency] section
ops_edit $neutron_com oslo_concurrency lock_path  \$state_path/lock

## [oslo_messaging_rabbit] section
ops_edit $neutron_com oslo_messaging_rabbit rabbit_hosts   \
$CON_MGNT_IP1:5672,$CON_MGNT_IP2:5672,$CON_MGNT_IP3:5672
ops_edit $neutron_com oslo_messaging_rabbit rabbit_userid   openstack
ops_edit $neutron_com oslo_messaging_rabbit rabbit_password   $RABBIT_PASS
ops_edit $neutron_com oslo_messaging_rabbit rabbit_retry_interval 1
ops_edit $neutron_com oslo_messaging_rabbit rabbit_retry_backoff 2
ops_edit $neutron_com oslo_messaging_rabbit rabbit_max_retries 0
ops_edit $neutron_com oslo_messaging_rabbit rabbit_durable_queues true
ops_edit $neutron_com oslo_messaging_rabbit rabbit_ha_queues   True
ops_edit $neutron_com oslo_messaging_rabbit heartbeat_timeout_threshold   60
ops_edit $neutron_com oslo_messaging_rabbit heartbeat_rate   2

echocolor "Configuring Linux Bbridge AGENT"
sleep 3

lbfile_com=/etc/neutron/plugins/ml2/linuxbridge_agent.ini 

test -f $lbfile_com.orig || cp $lbfile_com $lbfile_com.orig

# [linux_bridge] section
ops_edit $lbfile_com linux_bridge physical_interface_mappings provider:eth1

## [securitygroup] section 
ops_edit $lbfile_com securitygroup enable_security_group True
ops_edit $lbfile_com securitygroup firewall_driver \
	neutron.agent.linux.iptables_firewall.IptablesFirewallDriver

# [vxlan] section
ops_edit $lbfile_com vxlan enable_vxlan True
ops_edit $lbfile_com vxlan local_ip $COM1_MGNT_IP
ops_edit $lbfile_com vxlan l2_population True

## [agent] section
ops_edit $lbfile_com  agent prevent_arp_spoofing True


echo "Reset service nova-compute,linuxbridge-agent"
sleep 5
service nova-compute restart
service neutron-plugin-linuxbridge-agent restart


