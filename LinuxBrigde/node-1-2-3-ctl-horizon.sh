#!/bin/bash -ex

source config.cfg

###################
echo "########## START INSTALLING OPS DASHBOARD ##########"
###################
sleep 5

echo "########## Installing Dashboard package ##########"
apt-get -y install openstack-dashboard   --fix-missing 
apt-get -y remove --auto-remove openstack-dashboard-ubuntu-theme


# echo "########## Fix bug in apache2 ##########"
# sleep 5
# Fix bug apache in ubuntu 14.04
# echo "ServerName localhost" > /etc/apache2/conf-available/servername.conf
# sudo a2enconf servername 

echo "########## Creating redirect page ##########"

filehtml=/var/www/html/index.html
test -f $filehtml.orig || cp $filehtml $filehtml.orig
rm $filehtml
touch $filehtml
cat << EOF >> $filehtml
<html>
<head>
<META HTTP-EQUIV="Refresh" Content="0.5; URL=http://$CON_EXT_IP/horizon">
</head>
<body>
<center> <h1>Dang chuyen den Dashboard cua OpenStack</h1> </center>
</body>
</html>
EOF
# Allowing insert password in dashboard ( only apply in image )
sed -i "s/'can_set_password': False/'can_set_password': True/g" /etc/openstack-dashboard/local_settings.py


#sed -i 's/OPENSTACK_HOST = "127.0.0.1"/#OPENSTACK_HOST ="127.0.0.1"/g' /etc/openstack-dashboard/local_settings.py
#echo "OPENSTACK_HOST ="$VIP"" >> /etc/openstack-dashboard/local_settings.py

## /* Restarting apache2 and memcached
service apache2 restart
service memcached restart
echo "########## Config Horizon ##########"
echo "edit file /etc/openstack-dashboard/local_settings.py"
echo "Replace OPENSTACK_HOST = "127.0.0.1" --> OPENSTACK_HOST = $VIP "
echo "Replace  LOCATION on CACHES: 127.0.0.1:11211, 'CON_MGNT_IPX'"
echo "################################################################"

echo "########## Finish setting up Horizon ##########"

echo "########## LOGIN INFORMATION IN HORIZON ##########"
echo "URL: http://$VIP/horizon"
echo "User: admin or demo"
echo "Password:" $ADMIN_PASS


