#!/bin/bash -ex
#

source config.cfg
source function.sh
source /root/admin-openrc.sh

echocolor "Install NEUTRON in $2"
sleep 5
apt-get -y install neutron-server neutron-plugin-ml2 \
neutron-plugin-linuxbridge-agent neutron-l3-agent neutron-dhcp-agent \
neutron-metadata-agent python-neutronclient  --fix-missing 


######## Backup configuration NEUTRON.CONF ##################"
echocolor "Config NEUTRON"
sleep 3

#
neutron_ctl=/etc/neutron/neutron.conf
test -f $neutron_ctl.orig || cp $neutron_ctl $neutron_ctl.orig
#rm $neutron_ctl
#touch $neutron_ctl

## [DEFAULT] section
ops_edit $neutron_ctl DEFAULT verbose True
ops_edit $neutron_ctl DEFAULT core_plugin ml2
ops_edit $neutron_ctl DEFAULT service_plugins router
ops_edit $neutron_ctl DEFAULT allow_overlapping_ips True
ops_edit $neutron_ctl DEFAULT rpc_backend rabbit
ops_edit $neutron_ctl DEFAULT notify_nova_on_port_status_changes True
ops_edit $neutron_ctl DEFAULT notify_nova_on_port_data_changes True
#ops_edit $neutron_ctl DEFAULT bind_host $2
ops_edit $neutron_ctl DEFAULT nova_url http://$VIP:8774/v2


## [database] section
ops_edit $neutron_ctl database \
connection mysql+pymysql://neutron:$NEUTRON_DBPASS@$2/neutron


## [keystone_authtoken] section
ops_edit $neutron_ctl keystone_authtoken auth_uri http://$2:5000
ops_edit $neutron_ctl keystone_authtoken auth_url http://$2:35357
ops_edit $neutron_ctl keystone_authtoken auth_plugin password
ops_edit $neutron_ctl keystone_authtoken project_domain_id default
ops_edit $neutron_ctl keystone_authtoken user_domain_id default
ops_edit $neutron_ctl keystone_authtoken project_name service
ops_edit $neutron_ctl keystone_authtoken username neutron
ops_edit $neutron_ctl keystone_authtoken password $NEUTRON_PASS

ops_del $neutron_ctl keystone_authtoken identity_uri
ops_del $neutron_ctl keystone_authtoken admin_tenant_name
ops_del $neutron_ctl keystone_authtoken admin_user
ops_del $neutron_ctl keystone_authtoken admin_password


## [oslo_messaging_rabbit] section
ops_edit $neutron_ctl oslo_messaging_rabbit rabbit_hosts   \
$CON_MGNT_IP1:5672,$CON_MGNT_IP2:5672,$CON_MGNT_IP3:5672
ops_edit $neutron_ctl oslo_messaging_rabbit rabbit_userid   openstack
ops_edit $neutron_ctl oslo_messaging_rabbit rabbit_password   $RABBIT_PASS
ops_edit $neutron_ctl oslo_messaging_rabbit rabbit_retry_interval 1
ops_edit $neutron_ctl oslo_messaging_rabbit rabbit_retry_backoff 2
ops_edit $neutron_ctl oslo_messaging_rabbit rabbit_max_retries 0
ops_edit $neutron_ctl oslo_messaging_rabbit rabbit_durable_queues true
ops_edit $neutron_ctl oslo_messaging_rabbit rabbit_ha_queues   True
ops_edit $neutron_ctl oslo_messaging_rabbit heartbeat_timeout_threshold   60
ops_edit $neutron_ctl oslo_messaging_rabbit heartbeat_rate   2

## [nova] section
ops_edit $neutron_ctl nova auth_url http://$2:35357
ops_edit $neutron_ctl nova auth_plugin password
ops_edit $neutron_ctl nova project_domain_id default
ops_edit $neutron_ctl nova user_domain_id default
ops_edit $neutron_ctl nova region_name RegionOne
ops_edit $neutron_ctl nova project_name service
ops_edit $neutron_ctl nova username nova
ops_edit $neutron_ctl nova password $NOVA_PASS

#############################################
echocolor "########## Configuring ML2 ##########"
sleep 7

ml2_clt=/etc/neutron/plugins/ml2/ml2_conf.ini
test -f $ml2_clt.orig || cp $ml2_clt $ml2_clt.orig

## [ml2] section
ops_edit $ml2_clt ml2 tenant_network_types  vxlan
ops_edit $ml2_clt ml2 type_drivers  flat,vlan,vxlan
ops_edit $ml2_clt ml2 mechanism_drivers  linuxbridge,l2population
ops_edit $ml2_clt ml2 extension_drivers  port_security


## [ml2_type_flat] section
ops_edit $ml2_clt ml2_type_flat flat_networks external

## [ml2_type_vxlan] section
ops_edit $ml2_clt ml2_type_vxlan vni_ranges 1:1000


## [securitygroup] section
ops_edit $ml2_clt securitygroup enable_ipset  True

#############################################

echocolor "Configuring Linux Bbridge AGENT"
sleep 7 

linuxbridge_ctl=/etc/neutron/plugins/ml2/linuxbridge_agent.ini 

test -f $linuxbridge_ctl.orig || cp $linuxbridge_ctl $linuxbridge_ctl.orig
#rm $linuxbridgefile
#touch $linuxbridgefile

##[linux_bridge] section
ops_edit $linuxbridge_ctl linux_bridge physical_interface_mappings  external:eth1

## [vxlan] section
ops_edit $linuxbridge_ctl vxlan enable_vxlan  True
ops_edit $linuxbridge_ctl vxlan local_ip  $2
ops_edit $linuxbridge_ctl vxlan l2_population  True

## [agent] section
ops_edit $linuxbridge_ctl agent prevent_arp_spoofing  True

## [securitygroup] section
ops_edit $linuxbridge_ctl securitygroup enable_security_group  True
ops_edit $linuxbridge_ctl securitygroup  firewall_driver  neutron.agent.linux.iptables_firewall.IptablesFirewallDriver

#############################################

echocolor "Configuring L3 AGENT"
sleep 3
netl3agent=/etc/neutron/l3_agent.ini

test -f $netl3agent.orig || cp $netl3agent $netl3agent.orig

## [DEFAULT] section 
ops_edit $netl3agent DEFAULT verbose True
ops_edit $netl3agent DEFAULT interface_driver neutron.agent.linux.interface.BridgeInterfaceDriver
ops_edit $netl3agent DEFAULT external_network_bridge 

## [AGENT] section
ops_edit $netl3agent AGENT
#########################################################
echocolor "Configuring DHCP AGENT"
sleep 7 
#
netdhcp=/etc/neutron/dhcp_agent.ini
test -f $netdhcp.orig || cp $netdhcp $netdhcp.orig

## [DEFAULT] section 
ops_edit $netdhcp DEFAULT interface_driver neutron.agent.linux.interface.BridgeInterfaceDriver
ops_edit $netdhcp DEFAULT dhcp_driver neutron.agent.linux.dhcp.Dnsmasq
ops_edit $netdhcp DEFAULT dhcp_delete_namespaces True
ops_edit $netdhcp DEFAULT verbose True
ops_edit $netdhcp DEFAULT dnsmasq_config_file /etc/neutron/dnsmasq-neutron.conf


echocolor "Fix loi MTU"
sleep 3
echo "dhcp-option-force 26,1454" > /etc/neutron/dnsmasq-neutron.conf

#killall dnsmasq

echocolor "Configuring METADATA AGENT"
sleep 3
netmetadata=/etc/neutron/metadata_agent.ini

test -f $netmetadata.orig || cp $netmetadata $netmetadata.orig

## [DEFAULT] 
ops_edit $netmetadata DEFAULT auth_uri http://$2:5000
ops_edit $netmetadata DEFAULT auth_url http://$2:35357
ops_edit $netmetadata DEFAULT auth_region regionOne
ops_edit $netmetadata DEFAULT auth_plugin password
ops_edit $netmetadata DEFAULT project_domain_id default
ops_edit $netmetadata DEFAULT user_domain_id default
ops_edit $netmetadata DEFAULT project_name service
ops_edit $netmetadata DEFAULT username neutron
ops_edit $netmetadata DEFAULT password $NEUTRON_PASS
ops_edit $netmetadata DEFAULT nova_metadata_ip $2
ops_edit $netmetadata DEFAULT metadata_proxy_shared_secret $METADATA_SECRET
ops_edit $netmetadata DEFAULT verbose True

ops_del $netmetadata DEFAULT admin_tenant_name
ops_del $netmetadata DEFAULT admin_user
ops_del $netmetadata DEFAULT admin_password



su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf \
  --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron
  
echocolor "Restarting NOVA service"
sleep 3 
for i in `ls /etc/init.d/ | grep nova`; do service $i restart; done

#service nova-api restart
#service nova-scheduler restart
#service nova-conductor restart

echocolor "Restarting NEUTRON service"
sleep 3
for i in `ls /etc/init.d/ | grep neutron`; do service $i restart; done

#service neutron-server restart
#service neutron-plugin-set  -agent restart
#service neutron-dhcp-agent restart
#service neutron-metadata-agent restart
#service neutron-l3-agent restart

rm -f /var/lib/neutron/neutron.sqlite

#echocolor "Check service Neutron"
#neutron agent-list
sleep 3

echocolor "Config IP address for br-ex"

EXT_IP=`ifconfig eth1 | grep 'inet addr' | cut -d: -f2 | awk '{print $1}'`


ifaces=/etc/network/interfaces
test -f $ifaces.orig1 || cp $ifaces $ifaces.orig1
rm $ifaces
cat << EOF > $ifaces
# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface

# EXT NETWORK
auto eth1:0
iface eth1:0 inet static
address $EXT_IP
netmask $NETMASK_ADD_EXT
gateway $GATEWAY_IP_EXT
dns-nameservers  $DNS_SERVER


auto eth1
iface  eth1 inet manual
up ip link set dev \$IFACE up
down ip link set dev \$IFACE down

# MGNT NETWORK
auto eth0
iface eth0 inet static
address $2
netmask $NETMASK_ADD_MGNT

EOF

ifdown -a && ifup -a

#neutron agent-list
#neutron ext-list
#sleep 3

echocolor "FINISH SETUP NEUTRON"
