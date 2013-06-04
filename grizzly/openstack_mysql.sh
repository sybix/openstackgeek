#!/bin/bash

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "You need to be 'root' dude." 1>&2
   exit 1
fi

. ./setuprc

if [ -z $DBENGINE ]
then
        export DBENGINE="mysql"
fi
if [ $DBENGINE != "mysql" ] && [ $DBENGINE != "postgresql" ]
then
        echo "Unknow db engine"
fi

# throw in a few other services we need installed
apt-get install rabbitmq-server memcached python-memcache -y

# now let's install MySQL
echo;
echo "##############################################################################################"
echo;
echo "Setting up MySQL now.  You will be prompted to set a MySQL root password by the setup process."
echo;
echo "##############################################################################################"
echo;

if [ $DBENGINE  = "mysql" ]
then
	# mysql
	apt-get install -y mysql-server python-mysqldb

	# make mysql listen on 0.0.0.0
	sudo sed -i '/^bind-address/s/127.0.0.1/0.0.0.0/g' /etc/mysql/my.cnf

	# restart
	service mysql restart
elif [ $DBENGINE  = "postgresql" ]
then
	# postgresql
	apt-get install -y postgresql python-psycopg2
	
	# make postgresql listen on 0.0.0.0
	sed -i '/^#listen_addresses/s/localhost/*/g' /etc/postgresql/9.1/main/postgresql.conf 
	sed -i '/^#listen_addresses/s/#listen_addresses/listen_addresses/g' /etc/postgresql/9.1/main/postgresql.conf 
	
	service postgresql restart
fi
# wait for restart
sleep 4 

echo;
echo "##############################################################################################"
echo;
echo "Creating OpenStack databases and users.  Use the same password you gave the MySQL setup."
echo;
echo "##############################################################################################"
echo;

# load service pass from config env
service_pass=$SG_SERVICE_PASSWORD

# we create a quantum db irregardless of whether the user wants to install quantum
if [ $DBENGINE  = "mysql" ]
then
	mysql -u root -p <<EOF
CREATE DATABASE nova;
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY '$service_pass';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '$service_pass';
CREATE DATABASE glance;
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '$service_pass';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '$service_pass';
CREATE DATABASE keystone;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '$service_pass';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '$service_pass';
CREATE DATABASE quantum;
GRANT ALL PRIVILEGES ON quantum.* TO 'quantum'@'%' IDENTIFIED BY '$service_pass';
GRANT ALL PRIVILEGES ON quantum.* TO 'quantum'@'localhost' IDENTIFIED BY '$service_pass';
EOF
elif [ $DBENGINE  = "postgresql" ]
then
	su - postgres -c "psql -c \"CREATE user nova;\""
	su - postgres -c "psql -c \"ALTER user nova with password '$service_pass';\""
	su - postgres -c "psql -c \"CREATE DATABASE nova;\""
	su - postgres -c "psql -c \"GRANT ALL PRIVILEGES ON database nova TO  nova;\""
	su - postgres -c "psql -c \"CREATE user glance;\""
	su - postgres -c "psql -c \"ALTER user glance with password '$service_pass';\""
	su - postgres -c "psql -c \"CREATE DATABASE glance;\""
	su - postgres -c "psql -c \"GRANT ALL PRIVILEGES ON database glance TO glance;\""
	su - postgres -c "psql -c \"CREATE user keystone;\""
	su - postgres -c "psql -c \"ALTER user keystone with password '$service_pass';\""
	su - postgres -c "psql -c \"CREATE DATABASE keystone;\""
	su - postgres -c "psql -c \"GRANT ALL PRIVILEGES ON database keystone TO  keystone;\""
	su - postgres -c "psql -c \"CREATE user quantum;\""
	su - postgres -c "psql -c \"ALTER user quantum with password '$service_pass';\""
	su - postgres -c "psql -c \"CREATE DATABASE quantum;\""
	su - postgres -c "psql -c \"GRANT ALL PRIVILEGES ON database quantum TO  quantum;\""

fi
echo;
echo "#######################################################################################"
echo;
echo "Run './openstack_keystone.sh' now."
echo;
echo "#######################################################################################"
echo;
