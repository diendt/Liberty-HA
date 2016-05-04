#!/bin/bash -ex
#
source config.cfg
source function.sh

#Create ssh password less

ssh-keygen

ssh-copy-id root@$CON_MGNT_IP1
ssh-copy-id root@$CON_MGNT_IP2
ssh-copy-id root@$CON_MGNT_IP3

cat << EOF > ~/.ssh/config

Host $HOST_CTL_IP1
   Hostname $HOST_CTL_IP1
   User root
Host $HOST_CTL_IP2
   Hostname $HOST_CTL_IP2
   User root
Host $HOST_CTL_IP3
   Hostname $HOST_CTL_IP3
   User root
   
EOF