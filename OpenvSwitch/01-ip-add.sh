#!/bin/bash -ex
#

source config.cfg
source function.sh

#Setup IP

ifaces=/etc/network/interfaces
test -f $ifaces.orig || cp $ifaces $ifaces.orig
rm $ifaces
touch $ifaces

cat << EOF >> $ifaces
#Assign IP for Controller node

# LOOPBACK NET 
auto lo
iface lo inet loopback

# MGNT NETWORK
auto eth0
iface eth0 inet static
address $CON_MGNT_IP1
netmask $NETMASK_ADD_MGNT


# EXT NETWORK
auto eth1
iface eth1 inet static
address $CON_EXT_IP1
netmask $NETMASK_ADD_EXT
gateway $GATEWAY_IP_EXT
dns-nameservers 8.8.8.8
EOF


echocolor "Configuring hostname in CONTROLLER node"

sleep 3
echo "$HOST_CTL_IP1" > /etc/hostname
hostname -F /etc/hostname


echocolor "Configuring for file /etc/hosts"
sleep 3

iphost=/etc/hosts
test -f $iphost.orig || cp $iphost $iphost.orig
rm $iphost
touch $iphost

cat << EOF >> $iphost
127.0.0.1       localhost

$CON_MGNT_IP1    $HOST_CTL_IP1
$CON_MGNT_IP2    $HOST_CTL_IP2
$CON_MGNT_IP3    $HOST_CTL_IP3
$COM1_MGNT_IP   $HOST_COM_IP1
$BLK1_MGNT_IP   $HOST_BLK_IP1

EOF


echocolor "Cai dat repos cho Liberty"

apt-get install software-properties-common -y
add-apt-repository cloud-archive:liberty -y

echocolor "Add repositoty Mariadb garela"

sudo apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xcbcb082a1bb943db 
sudo add-apt-repository 'deb http://ftp.osuosl.org/pub/mariadb/repo/10.0/ubuntu trusty main'

sleep 3
echocolor "UPDATE PACKAGE"
apt-get -y update && apt-get -y upgrade && apt-get -y dist-upgrade

apt-get -y install crudini
sleep 3

echocolor "REBOOT NODE $CON_MGNT_IP1"
#Reset interface

#ifdown -a; ifup -a;

sleep 3

reboot
#



