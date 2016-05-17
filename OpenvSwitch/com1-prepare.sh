#!/bin/bash -ex
#

source config.cfg
source function.sh

modprobe br_netfilter

#load modules br_netfilter on boot 
#fix for ubuntu 14.04.3

echo "br_netfilter" >> /etc/modules

echo "net.ipv4.conf.all.rp_filter=0" >> /etc/sysctl.conf
echo "net.ipv4.conf.default.rp_filter=0" >> /etc/sysctl.conf
echo "net.bridge.bridge-nf-call-iptables=1" >> /etc/sysctl.conf
echo "net.bridge.bridge-nf-call-ip6tables=1" >> /etc/sysctl.conf


echocolor "Install python client"
sleep 3

apt-get -y install python-openstackclient  --fix-missing 

echocolor "Install and config NTP"
sleep 3
 
apt-get install ntp -y  --fix-missing 
cp /etc/ntp.conf /etc/ntp.conf.bka
rm /etc/ntp.conf
cat /etc/ntp.conf.bka | grep -v ^# | grep -v ^$ >> /etc/ntp.conf

## Config NTP in LIBERTY
#sed -i 's/server ntp.ubuntu.com/ \
#server 0.vn.pool.ntp.org iburst \
#server 1.asia.pool.ntp.org iburst \
#server 2.asia.pool.ntp.org iburst/g' /etc/ntp.conf

#sed -i 's/restrict -4 default kod notrap nomodify nopeer noquery/ \
#restrict -4 default kod notrap nomodify nopeer noquery/g' /etc/ntp.conf

#sed -i 's/restrict -6 default kod notrap nomodify nopeer noquery/ \
#restrict -4 default kod notrap nomodify \
#restrict -6 default kod notrap nomodify/g' /etc/ntp.conf

# sed -i 's/server/#server/' /etc/ntp.conf
# echo "server $LOCAL_IP" >> /etc/ntp.conf

#sed -i "s/server ntp.ubuntu.com/server $CON_MGNT_IP iburst/g" /etc/ntp.conf

echocolor "##### Installl package for NOVA"
sleep 5
apt-get -y install nova-compute 

#echo "libguestfs-tools        libguestfs/update-appliance     boolean true"  | debconf-set-selections
apt-get -y install libguestfs-tools sysfsutils guestfsd python-guestfs

#fix loi chen pass tren hypervisor la KVM
#update-guestfs-appliance
#chmod 0644 /boot/vmlinuz*
#usermod -a -G kvm root

echocolor "Configuring in nova.conf ..."
sleep 3
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
ops_edit $nova_com DEFAULT enabled_apisc2,osapi_compute,metadata

ops_edit $nova_com DEFAULT rpc_backend rabbit
ops_edit $nova_com DEFAULT auth_strategy keystone
ops_edit $nova_com DEFAULT my_ip $COM1_MGNT_IP

ops_edit $nova_com DEFAULT network_api_class nova.network.neutronv2.api.API
ops_edit $nova_com DEFAULT security_group_api neutron
ops_edit $nova_com DEFAULT linuxnet_interface_driver nova.network.linux_net.LinuxOVSInterfaceDriver
ops_edit $nova_com DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver

ops_edit $nova_com DEFAULT verbose True
ops_edit $nova_com DEFAULT enable_instance_password True

## [oslo_messaging_rabbit] section
ops_edit $nova_com oslo_messaging_rabbit rabbit_hosts   \
$CON_MGNT_IP1:5672,$CON_MGNT_IP2:5672,$CON_MGNT_IP3:5672
ops_edit $nova_com oslo_messaging_rabbit rabbit_userid openstack
ops_edit $nova_com oslo_messaging_rabbit rabbit_password $RABBIT_PASS
ops_edit $nova_com oslo_messaging_rabbit rabbit_retry_interval 1
ops_edit $nova_com oslo_messaging_rabbit rabbit_retry_backoff 2
ops_edit $nova_com oslo_messaging_rabbit rabbit_max_retries 0
ops_edit $nova_com oslo_messaging_rabbit rabbit_durable_queues true
ops_edit $nova_com oslo_messaging_rabbit rabbit_ha_queues True
ops_edit $nova_com oslo_messaging_rabbit heartbeat_timeout_threshold 60
ops_edit $nova_com oslo_messaging_rabbit heartbeat_rate 2
ops_edit $nova_com oslo_messaging_rabbit rabbit_host $CON_MGNT_IP


## [keystone_authtoken] section
ops_edit $nova_com keystone_authtoken auth_uri http://$VIP:5000
ops_edit $nova_com keystone_authtoken auth_url http://$VIP:35357
ops_edit $nova_com keystone_authtoken auth_plugin password
ops_edit $nova_com keystone_authtoken project_domain_id default
ops_edit $nova_com keystone_authtoken user_domain_id default
ops_edit $nova_com keystone_authtoken project_name service
ops_edit $nova_com keystone_authtoken username nova
ops_edit $nova_com keystone_authtoken password $KEYSTONE_PASS

## [vnc] section
ops_edit $nova_com vnc enabled  True
ops_edit $nova_com vnc vncserver_listen  0.0.0.0
ops_edit $nova_com vnc vncserver_proxyclient_address  \$my_ip
ops_edit $nova_com vnc novncproxy_base_url  http://$CON_EXT_IP:6080/vnc_auto.html

## [glance] section
ops_edit $nova_com glance host $VIP

## [oslo_concurrency] section
ops_edit $nova_com oslo_concurrency lock_path /var/lib/nova/tmp

## [neutron] section
ops_edit $nova_com neutron url http://$VIP:9696
ops_edit $nova_com neutron auth_url http://$VIP:35357
ops_edit $nova_com neutron auth_plugin password
ops_edit $nova_com neutron project_domain_id default
ops_edit $nova_com neutron user_domain_id default
ops_edit $nova_com neutron region_name RegionOne
ops_edit $nova_com neutron project_name service
ops_edit $nova_com neutron username neutron
ops_edit $nova_com neutron password $NEUTRON_PASS

## [libvirt] section
ops_edit $nova_com libvirt inject_key True
ops_edit $nova_com libvirt inject_partition -1
ops_edit $nova_com libvirt inject_password True

echo "##### Restart nova-compute #####"
sleep 3
service nova-compute restart

# Remove default nova db
rm /var/lib/nova/nova.sqlite

echocolor "Install openvswitch-agent (neutron) on COMPUTE NODE"
sleep 5

apt-get -y install neutron-plugin-ml2 neutron-plugin-openvswitch-agent

echocolor "Config file neutron.conf"
sleep 3
com_neutron=/etc/neutron/neutron.conf
test -f $com_neutron.orig || cp $com_neutron $com_neutron.orig

## [DEFAULT] section
ops_edit $com_neutron DEFAULT core_plugin ml2
ops_edit $com_neutron DEFAULT rpc_backend rabbit
ops_edit $com_neutron DEFAULT auth_strategy keystone
ops_edit $com_neutron DEFAULT verbose True

ops_edit $com_neutron DEFAULT allow_overlapping_ips True
ops_edit $com_neutron DEFAULT service_plugins router

## [agent] section
ops_edit $com_neutron agent root_helper sudo /usr/bin/neutron-rootwrap /etc/neutron/rootwrap.conf

## [keystone_authtoken] section
ops_edit $com_neutron  keystone_authtoken auth_uri http://$VIP:5000
ops_edit $com_neutron  keystone_authtoken auth_url http://$VIP:35357
ops_edit $com_neutron  keystone_authtoken auth_plugin password
ops_edit $com_neutron  keystone_authtoken project_domain_id default
ops_edit $com_neutron  keystone_authtoken user_domain_id default
ops_edit $com_neutron  keystone_authtoken project_name service
ops_edit $com_neutron  keystone_authtoken username neutron
ops_edit $com_neutron  keystone_authtoken password $KEYSTONE_PASS

ops_del $com_neutron keystone_authtoken identity_uri
ops_del $com_neutron keystone_authtoken admin_tenant_name
ops_del $com_neutron keystone_authtoken admin_user
ops_del $com_neutron keystone_authtoken admin_password

## [database] section
ops_del $com_neutron database connection sqlite:////var/lib/neutron/neutron.sqlite

## [oslo_concurrency] section
ops_edit $com_neutron  oslo_concurrency  lock_path \$state_path/lock

## [oslo_messaging_rabbit] section
ops_edit $com_neutron oslo_messaging_rabbit rabbit_hosts   \
$CON_MGNT_IP1:5672,$CON_MGNT_IP2:5672,$CON_MGNT_IP3:5672
ops_edit $com_neutron oslo_messaging_rabbit rabbit_userid openstack
ops_edit $com_neutron oslo_messaging_rabbit rabbit_password $RABBIT_PASS
ops_edit $com_neutron oslo_messaging_rabbit rabbit_retry_interval 1
ops_edit $com_neutron oslo_messaging_rabbit rabbit_retry_backoff 2
ops_edit $com_neutron oslo_messaging_rabbit rabbit_max_retries 0
ops_edit $com_neutron oslo_messaging_rabbit rabbit_durable_queues true
ops_edit $com_neutron oslo_messaging_rabbit rabbit_ha_queues True
ops_edit $com_neutron oslo_messaging_rabbit heartbeat_timeout_threshold 60
ops_edit $com_neutron oslo_messaging_rabbit heartbeat_rate 2

echocolor "Configuring ml2_conf.ini"
sleep 5
########
com_ml2=/etc/neutron/plugins/ml2/ml2_conf.ini
test -f $com_ml2.orig || cp $com_ml2 $com_ml2.orig

#Update ML2 config file /etc/neutron/plugins/ml2/ml2_conf.ini

## [ml2] section
ops_edit $com_ml2 ml2 type_drivers flat,vlan,gre,vxlan
ops_edit $com_ml2 ml2 tenant_network_types gre
ops_edit $com_ml2 ml2 mechanism_drivers openvswitch

## [ml2_type_gre] section
ops_edit $com_ml2 ml2_type_gre tunnel_id_ranges 1:1000

## [securitygroup] section
ops_edit $com_ml2 securitygroup enable_security_group True
ops_edit $com_ml2 securitygroup enable_ipset True
ops_edit $com_ml2 securitygroup firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver

## [ovs] section
ops_edit $com_ml2 ovs local_ip $COM1_MGNT_IP
ops_edit $com_ml2 ovs enable_tunneling True

## [agent] section 
ops_edit $com_ml2 agent tunnel_types gre


echo "Reset service nova-compute,openvswitch-agent"
sleep 5
service nova-compute restart
service neutron-plugin-openvswitch-agent restart

echocolor "FINISH COMPUTE INSTALL"
