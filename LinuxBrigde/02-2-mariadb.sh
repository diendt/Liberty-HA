#!/bin/bash -ex
#
source config.cfg
source function.sh
	
echo mysql-server mysql-server/root_password password $MYSQL_PASS | debconf-set-selections
echo mysql-server mysql-server/root_password_again password $MYSQL_PASS | debconf-set-selections

sudo apt-get install -y rsync galera mariadb-galera-server netcat-openbsd mariadb-client python-mysqldb curl  --fix-missing

sleep 3

echocolor "CONFIGURING FOR GALERA"
echo "" > /etc/mysql/conf.d/mysqld_galera.cnf
galera_file=/etc/mysql/conf.d/mysqld_galera.cnf
ops_edit $galera_file mysqld query_cache_size 0
ops_edit $galera_file mysqld binlog_format ROW
ops_edit $galera_file mysqld default-storage-engine innodb
ops_edit $galera_file mysqld innodb_autoinc_lock_mode 2
ops_edit $galera_file mysqld query_cache_type 0
ops_edit $galera_file mysqld bind-address $1
ops_edit $galera_file mysqld collation-server utf8_general_ci
#ops_edit $galera_file mysqld init-connect \'SET\ NAMES\ utf8\'
ops_edit $galera_file mysqld character-set-server utf8
 # Galera Provider Configuration
ops_edit $galera_file mysqld wsrep_provider /usr/lib/galera/libgalera_smm.so
# Galera Cluster Configuration
ops_edit $galera_file mysqld wsrep_cluster_name \"opestack_cluster\"
ops_edit $galera_file mysqld wsrep_cluster_address \"gcomm://$CON_MGNT_IP1,$CON_MGNT_IP2,$CON_MGNT_IP3\"
# Galera Synchronization Congifuration
ops_edit $galera_file mysqld wsrep_sst_method rsync
ops_edit $galera_file mysqld wsrep_node_address \"$1\"
ops_edit $galera_file mysqld wsrep_node_name \"MariaDB-$1\"
