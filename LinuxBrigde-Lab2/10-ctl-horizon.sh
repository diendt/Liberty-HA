#!/bin/bash -ex

source config.cfg
source functions.sh

echocolor "START INSTALLING OPS DASHBOARD"
###################
sleep 5

echocolor "Installing Dashboard package on $CON_MGNT_IP1"
sleep 3


./10-ctl-horizon-add.sh $CON_MGNT_IP1

echocolor "Installing Dashboard package on $CON_MGNT_IP3"
sleep 3

scp -r ./10-ctl-horizon-add.sh root@$CON_MGNT_IP2:/root/script/10-ctl-horizon-add.sh
ssh root@$CON_MGNT_IP2  << EOF
	cd script
	source config.cfg
	source function.sh
	/root/script/10-ctl-horizon-add.sh $CON_MGNT_IP2
	reboot
EOF

echocolor "Installing Dashboard package on $CON_MGNT_IP3"
sleep 3

scp -r ./10-ctl-horizon-add.sh root@$CON_MGNT_IP3:/root/script/10-ctl-horizon-add.sh
ssh root@$CON_MGNT_IP3  << EOF
	cd script
	source config.cfg
	source function.sh
	/root/script/10-ctl-horizon-add.sh $CON_MGNT_IP3
	reboot
EOF