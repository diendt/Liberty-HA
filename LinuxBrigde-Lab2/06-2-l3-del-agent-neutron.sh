#!/bin/bash -ex
#

source config.cfg
source function.sh
source /root/admin-openrc.sh

echocolor "Config NEUTRON FOR L3 AGENT HA"
sleep 3

#
echocolor "Configuring NEUTRON CONFIG"
sleep 3

neutron_ctl=/etc/neutron/neutron.conf
test -f $neutron_ctl.orig || cp $neutron_ctl $neutron_ctl.orig
#rm $neutron_ctl
#touch $neutron_ctl


## [DEFAULT] section
ops_del $neutron_ctl DEFAULT dhcp_agents_per_network 2
ops_del $neutron_ctl DEFAULT l3_ha True
ops_del $neutron_ctl DEFAULT allow_automatic_l3agent_failover True
ops_del $neutron_ctl DEFAULT max_l3_agents_per_router 3
ops_del $neutron_ctl DEFAULT min_l3_agents_per_router 2
ops_del $neutron_ctl DEFAULT dhcp_agents_per_network  3
ops_del $neutron_ctl DEFAULT l3_ha_net_cidr  169.254.192.0/18


echocolor "Configuring L3 AGENT"
sleep 3

netl3agent=/etc/neutron/l3_agent.ini

## [DEFAULT] section
ops_del $netl3agent DEFAULT ha_confs_path '$state_path/ha_confs'
ops_del $netl3agent DEFAULT ha_vrrp_auth_type PASS
ops_del $netl3agent DEFAULT ha_vrrp_auth_password Welcome123
ops_del $netl3agent DEFAULT  ha_vrrp_advert_int 2


#
#neutron agent-list
#neutron ext-list
#sleep 3
echocolor "RESTART SERVICE NEUTRON"
sleep 2

for i in `ls /etc/init.d/ | grep neutron`; do service $i restart; done

echocolor "RESTART SERVICE NOVA"
sleep 2

for i in `ls /etc/init.d/ | grep nova`; do service $i restart; done

echocolor "FINISH SETUP NEUTRON"
sleep 3