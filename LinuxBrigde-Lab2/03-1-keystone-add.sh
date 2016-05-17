#!/bin/bash -ex

source config.cfg
source function.sh

#echo "Create Database for Keystone"

cat << EOF | mysql -uroot -p$MYSQL_PASS
CREATE DATABASE keystone;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '$KEYSTONE_DBPASS';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '$KEYSTONE_DBPASS';
FLUSH PRIVILEGES;
EOF

echocolor "Install Openstack components on $2"

sleep 3
 
echo "manual" > /etc/init/keystone.override
 

apt-get -y install keystone python-openstackclient apache2 libapache2-mod-wsgi memcached python-memcache  --fix-missing 
 
#/* Back-up file keystone.conf
filekeystone=/etc/keystone/keystone.conf

test -f $filekeystone.orig || cp $filekeystone $filekeystone.orig

#Config file /etc/keystone/keystone.conf

ops_edit $filekeystone DEFAULT verbose True
ops_edit $filekeystone DEFAULT admin_token $TOKEN_PASS
ops_edit $filekeystone DEFAULT log_dir /var/log/keystone
ops_edit $filekeystone DEFAULT public_bind_host $2
ops_edit $filekeystone DEFAULT admin_bind_host $2


#ops_edit $filekeystone DEFAULT bind_host $2

ops_edit $filekeystone database \
connection mysql+pymysql://keystone:$KEYSTONE_DBPASS@$1/keystone

ops_edit $filekeystone identity driver keystone.identity.backends.sql.Identity
ops_edit $filekeystone catalog driver keystone.catalog.backends.sql.Catalog
ops_edit $filekeystone identity memcache servers localhost:11211

ops_edit $filekeystone token provider uuid
ops_edit $filekeystone token driver memcache
ops_edit $filekeystone revoke driver sql

#
su -s /bin/sh -c "keystone-manage db_sync" keystone
 
HOST_NAME=`cat /etc/hosts | grep $2 | awk '{print $2}'`
echo "ServerName $HOST_NAME" >>  /etc/apache2/apache2.conf

cat << EOF > /etc/apache2/sites-available/wsgi-keystone.conf
Listen $2:5000
Listen $2:35357

<VirtualHost $2:5000>
    WSGIDaemonProcess keystone-public processes=5 threads=1 user=keystone group=keystone display-name=%{GROUP}
    WSGIProcessGroup keystone-public
    WSGIScriptAlias / /usr/bin/keystone-wsgi-public
    WSGIApplicationGroup %{GLOBAL}
    WSGIPassAuthorization On
    <IfVersion >= 2.4>
      ErrorLogFormat "%{cu}t %M"
    </IfVersion>
    ErrorLog /var/log/apache2/keystone.log
    CustomLog /var/log/apache2/keystone_access.log combined

    <Directory /usr/bin>
        <IfVersion >= 2.4>
            Require all granted
        </IfVersion>
        <IfVersion < 2.4>
            Order allow,deny
            Allow from all
        </IfVersion>
    </Directory>
</VirtualHost>

<VirtualHost $2:35357>
    WSGIDaemonProcess keystone-admin processes=5 threads=1 user=keystone group=keystone display-name=%{GROUP}
    WSGIProcessGroup keystone-admin
    WSGIScriptAlias / /usr/bin/keystone-wsgi-admin
    WSGIApplicationGroup %{GLOBAL}
    WSGIPassAuthorization On
    <IfVersion >= 2.4>
      ErrorLogFormat "%{cu}t %M"
    </IfVersion>
    ErrorLog /var/log/apache2/keystone.log
    CustomLog /var/log/apache2/keystone_access.log combined

    <Directory /usr/bin>
        <IfVersion >= 2.4>
            Require all granted
        </IfVersion>
        <IfVersion < 2.4>
            Order allow,deny
            Allow from all
        </IfVersion>
    </Directory>
</VirtualHost>

 
EOF

cat << EOF > /etc/apache2/sites-available/000-default.conf 
  
<VirtualHost $2:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html
    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>

EOF

cat << EOF > /etc/apache2/ports.conf 
  
# If you just change the port or add more ports here, you will likely also 
# have to change the VirtualHost statement in
# /etc/apache2/sites-enabled/000-default.conf

Listen $2:80     

<IfModule ssl_module>
        Listen $2:443
</IfModule>

<IfModule mod_gnutls.c>
        Listen $2:443
</IfModule>

# vim: syntax=apache ts=4 sw=4 sts=4 sr noet

EOF


 
ln -sf /etc/apache2/sites-available/wsgi-keystone.conf /etc/apache2/sites-enabled

service apache2 restart

test -f /var/lib/keystone/keystone.db && rm -f /var/lib/keystone/keystone.db


echocolor "Tao bien moi truong"
sleep 5

echo "export OS_PROJECT_DOMAIN_ID=default" > admin-openrc.sh
echo "export OS_USER_DOMAIN_ID=default" >> admin-openrc.sh
echo "export OS_PROJECT_NAME=admin" >> admin-openrc.sh
echo "export OS_TENANT_NAME=admin" >> admin-openrc.sh
echo "export OS_USERNAME=admin" >> admin-openrc.sh
echo "export OS_PASSWORD=$ADMIN_PASS"  >> admin-openrc.sh
echo "export OS_AUTH_URL=http://$VIP:35357/v3" >> admin-openrc.sh
echo "export OS_VOLUME_API_VERSION=2"   >> admin-openrc.sh

sleep 5
echocolor  "Execute environment script"
chmod +x admin-openrc.sh
#cat  admin-openrc.sh >> /etc/profile

#test -f rm /etc/apache2/sites-enabled/wsgi-keystone.conf && echo "CO DAY" || echo "DEO CO"
test -f /root/admin-openrc.sh || cp  /root/script/admin-openrc.sh /root/admin-openrc.sh
source admin-openrc.sh


echo "export OS_PROJECT_DOMAIN_ID=default" > demo-openrc.sh
echo "export OS_USER_DOMAIN_ID=default" >> demo-openrc.sh
echo "export OS_PROJECT_NAME=demo" >> demo-openrc.sh
echo "export OS_TENANT_NAME=demo" >> demo-openrc.sh
echo "export OS_USERNAME=demo" >> demo-openrc.sh
echo "export OS_PASSWORD=$ADMIN_PASS"  >> demo-openrc.sh
echo "export OS_AUTH_URL=http://$VIP:35357/v3" >> demo-openrc.sh
echo "export OS_VOLUME_API_VERSION=2"  >> demo-openrc.sh

chmod +x demo-openrc.sh
#cp  demo-openrc.sh /root/demo-openrc.sh
test -f /root/demo-openrc.sh || cp  /root/script/demo-openrc.sh /root/demo-openrc.sh


