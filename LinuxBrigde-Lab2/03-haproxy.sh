#!/bin/bash -ex
#
source config.cfg
source function.sh


#apt-get -y update 
apt-get -y install haproxy keepalived --fix-missing

echo "ENABLED=1" > /etc/default/haproxy

#Config keepalived
echo "#### Config keepalived ####"

sleep 3

echo "net.ipv4.ip_nonlocal_bind=1" >> /etc/sysctl.conf
echo "1" > /proc/sys/net/ipv4/ip_nonlocal_bind

sysctl -p


#Config Haproxy
haproxyfile=/etc/haproxy/haproxy.cfg

test $haproxyfile && cp $haproxyfile $haproxyfile.bak

echo "" > $haproxyfile

sleep 3

cat << EOF > $haproxyfile

global
    daemon
    stats socket /var/lib/haproxy/stats
    
    #log /dev/log    local0
    #log /dev/log    local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

    # Default SSL material locations
    ca-base /etc/ssl/certs
    crt-base /etc/ssl/private

    # Default ciphers to use on SSL-enabled listening sockets.
    # For more information, see ciphers(1SSL). This list is from:
    #  https://hynek.me/articles/hardening-your-web-servers-ssl-ciphers/
    ssl-default-bind-ciphers ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:ECDH+3DES:$
    ssl-default-bind-options no-sslv3

defaults
    mode tcp
    maxconn 10000
    timeout connect 5s
    timeout client 30s
    timeout server 30s

listen monitor
    bind $VIP:9300 
    mode http
    monitor-uri /status
    stats enable
    stats uri /admin
    stats realm Haproxy\ Statistics
    stats auth u:p
    stats refresh 5s

frontend front-db
    bind $VIP:3306
    timeout client 90m
    default_backend db-vms-galera

backend db-vms-galera
	mode tcp    
	option httpchk
    server front-01 $CON_MGNT_IP1:3306 check port 9200 
    server front-02 $CON_MGNT_IP2:3306 check port 9200 backup
    server front-03 $CON_MGNT_IP3:3306 check port 9200 backup


frontend front-rabbitmq
    option clitcpka
    bind $VIP:5672
    timeout client 900m
    default_backend rabbitmq-vms

backend rabbitmq-vms
    option srvtcpka
    balance source
    timeout server 900m
    server front-01 $CON_MGNT_IP1:5672 check inter 1s
    server front-02 $CON_MGNT_IP2:5672 check inter 1s
    server front-03 $CON_MGNT_IP3:5672 check inter 1s

frontend front-keystone-admin
    bind $VIP:35357
    default_backend keystone-admin-vms
    timeout client 600s

backend keystone-admin-vms
    balance source
    timeout server 600s
    server front-01 $CON_MGNT_IP1:35357 check inter 1s on-marked-down shutdown-sessions
    server front-02 $CON_MGNT_IP2:35357 check inter 1s on-marked-down shutdown-sessions
	server front-03 $CON_MGNT_IP3:35357 check inter 1s on-marked-down shutdown-sessions

frontend front-keystone-public
    bind $VIP:5000
    default_backend keystone-public-vms
    timeout client 600s

backend keystone-public-vms
    balance source
    timeout server 600s
    server front-01 $CON_MGNT_IP1:5000 check inter 1s on-marked-down shutdown-sessions
    server front-02 $CON_MGNT_IP2:5000 check inter 1s on-marked-down shutdown-sessions
    server front-03 $CON_MGNT_IP3:5000 check inter 1s on-marked-down shutdown-sessions

frontend front-glance-registry
    bind $VIP:9191
    default_backend glance-registry-vms
backend glance-registry-vms
    balance source
    server front-01 $CON_MGNT_IP1:9191 check inter 1s
    server front-02 $CON_MGNT_IP2:9191 check inter 1s
    server front-03 $CON_MGNT_IP3:9191 check inter 1s

frontend front-glance-api
    bind $VIP:9292
    default_backend glance-api-vms
backend glance-api-vms
    balance source
    server front-01 $CON_MGNT_IP1:9292 check inter 1s
    server front-02 $CON_MGNT_IP2:9292 check inter 1s
    server front-03 $CON_MGNT_IP3:9292 check inter 1s

frontend front-cinder
    bind $VIP:8776
    default_backend cinder-vms
backend cinder-vms
    balance source
    server front-01 $CON_MGNT_IP1:8776 check inter 1s
    server front-02 $CON_MGNT_IP2:8776 check inter 1s
    server front-03 $CON_MGNT_IP3:8776 check inter 1s

frontend front-neutron
    bind $VIP:9696
    default_backend neutron-vms
backend neutron-vms
    balance source
    server front-01 $CON_MGNT_IP1:9696 check inter 1s
    server front-02 $CON_MGNT_IP2:9696 check inter 1s
    server front-03 $CON_MGNT_IP3:9696 check inter 1s

frontend front-nova-vnc-novncproxy
    bind $VIP:6080
    default_backend nova-vnc-novncproxy-vms
backend nova-vnc-novncproxy-vms
    balance source
    timeout tunnel 1h
    server front-01 $CON_MGNT_IP1:6080 check inter 1s
    server front-02 $CON_MGNT_IP2:6080 check inter 1s
    server front-03 $CON_MGNT_IP3:6080 check inter 1s

frontend nova-metadata-vms
    bind $VIP:8775
    default_backend nova-metadata-vms
backend nova-metadata-vms
    balance source
    server front-01 $CON_MGNT_IP1:8775 check inter 1s
    server front-02 $CON_MGNT_IP2:8775 check inter 1s
    server front-03 $CON_MGNT_IP3:8775 check inter 1s

frontend front-nova-api
    bind $VIP:8774
    default_backend nova-api-vms
backend nova-api-vms
    balance source
    server front-01 $CON_MGNT_IP1:8774 check inter 1s
    server front-02 $CON_MGNT_IP2:8774 check inter 1s
    server front-03 $CON_MGNT_IP3:8774 check inter 1s

frontend front-horizon
    bind $VIP:80
    timeout client 180s
    capture  cookie vgnvisitor= len 32        
    default_backend horizon-vms

backend horizon-vms
    balance source
    timeout server 180s        
    cookie  SERVERID insert indirect nocache
    mode  http        
    option  forwardfor
    option  httpchk
    option  httpclose
    rspidel  ^Set-cookie:\ IP=
    server front-01 $CON_MGNT_IP1:80 cookie control01 check inter 2000 rise 2 fall 5
    server front-02 $CON_MGNT_IP2:80 cookie control01 check inter 2000 rise 2 fall 5
    server front-03 $CON_MGNT_IP3:80 cookie control01 check inter 2000 rise 2 fall 5

frontend front-memcached
    bind $VIP:11211
    timeout client 180s
    default_backend memcached_vms

listen memcached_vms
    balance source
    option tcpka
#   option httpchk
    maxconn 10000
    server front-01 $CON_MGNT_IP1:11211 check inter 2000 rise 2 fall 5
    server front-02 $CON_MGNT_IP2:11211 check inter 2000 rise 2 fall 5
    server front-03 $CON_MGNT_IP3:11211 check inter 2000 rise 2 fall 5

EOF


sleep 3


keepalivefile=/etc/keepalived/keepalived.conf 
test -f $ikeepalivefile || cp $iphost $keepalivefile.orig

echo "" > $keepalivefile

cat << EOF >> $keepalivefile
#Config keep alived
global_defs {
# Keepalived process identifier
	lvs_id haproxy_1
}
# Script used to check if HAProxy is running
vrrp_script check_haproxy {
	script "killall -0 haproxy"
	interval 2
	weight 2
}
# Virtual interface
# The priority specifies the order in which the assigned interface to take over in a failover
vrrp_instance 50 {
	state MASTER
	interface eth0
	virtual_router_id 50
	priority 200
# The virtual ip address shared between the two loadbalancers
	virtual_ipaddress {
		$VIP  dev eth0 
	}
	track_script {
		check_haproxy
	}
}


EOF

#Enable Auto Start Keepalive
update-rc.d -f keepalived defaults
update-rc.d -f keepalived enable

sleep 2

service haproxy restart
service keepalived restart