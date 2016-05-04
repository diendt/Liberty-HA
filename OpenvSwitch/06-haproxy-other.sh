#!/bin/bash -ex
#
source config.cfg
source function.sh

cat << EOF | ssh root@$1
source config.cfg
source function.sh

echocolor "ON $1"

sleep 5

#apt-get -y update 
apt-get -y install haproxy keepalived --fix-missing

echo "ENABLED=1" > /etc/default/haproxy

#Config keepalived
echo "#### Config keepalived ####"

sleep 3

echo "net.ipv4.ip_nonlocal_bind=1" >> /etc/sysctl.conf
echo "1" > /proc/sys/net/ipv4/ip_nonlocal_bind

sysctl -p

service haproxy restart
service keepalived restart
EOF

scp /etc/haproxy/haproxy.cfg root@$1:/etc/haproxy/
scp /etc/keepalived/keepalived.conf root@$1:/etc/keepalived/

cat << EOF | ssh root@$1
sed -i 's/MASTER/BACKUP/g' /etc/keepalived/keepalived.conf
sed -i 's/200/150/g' /etc/keepalived/keepalived.conf
reboot
EOF
