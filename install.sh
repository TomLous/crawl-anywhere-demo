#!/bin/bash

# README:
# To load this script on the server:

# apt-get install git
# git config --global credential.helper 'cache --timeout=3000'
# git clone https://github.com/TomLous/crawl-anywhere-demo.github


# Global vars
BASEDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

SOLR_BASE="/opt"
SOLR_LINK="$SOLR_BASE/solr"
SOLR_INSTALL=$SOLR_LINK # postfixed for installation 

ETC_DIR="$SOLR_INSTALL/server/etc"
SSL_DIR="$SOLR_INSTALL/server/etc"

TODAY=$( date +%Y-%m-%d )
MEMORY_FACTOR=0.70
HEAPSIZE=$( cat /proc/meminfo  | grep MemTotal | awk -v mem=$MEMORY_FACTOR '{printf "%1.0f", ($2 * mem)/(1024)}')

####################################################
# Increase openfile limit
root soft nofile 16184

# Check Timezone
if [ $( cat /etc/timezone 2>&1 | grep -c "Amsterdam") -eq 0 ];then
	dpkg-reconfigure tzdata
fi

# Create source/build dir
if [ ! -d "/root/build" ]; then
	mkdir /root/build
fi

# /sbin/false needed for install script
if [ ! -e /sbin/false ]; then
	ln -s /bin/false /sbin/false
fi

# Update APT cache
echo -e "\n>>> Update APT cache"
if [ $(expr $(date +%s) - $(stat -c %Y /var/cache/apt/)) -gt 3600 ];then 
	apt-get update
	echo "... ok"
else
	echo "... Already done"
fi

# Install tools
echo -e "\n>>> Installing Tools"
if [ $(dpkg-query -W -f='${Status}' sudo 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
	apt-get -y install sudo curl unzip wget gawk lrzsz
	echo "... ok"
else
	echo "... Already done"
fi

# Installing Python3 & pip
echo -e "\n>>> Installing Python3 & pip"
if [ $(dpkg-query -W -f='${Status}' python3 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
	apt-get -y install python3 python3-pip
	echo "... ok"
else
	echo "... Already done"
fi

# Installing PHP 5
echo -e "\n>>> Installing Apache2 & PHP 5"
if [ $(dpkg-query -W -f='${Status}' php5 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
	apt-get -y install apache2 php5 apache2-utils php5-curl php5-gd php5-mysql php5-mongo php-mcrypt
	a2enmod rewrite
	a2enmod vhost_alias
	a2enmod ssl
	echo "... ok"
else
	echo "... Already done"
fi

# Installing Mongo 
echo -e "\n>>> Installing Mongo DB"
if [ $(dpkg-query -W -f='${Status}' mongodb 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
	apt-get -y install mongodb
	echo "... ok"
else
	echo "... Already done"
fi


# Install the Java JDK
echo -e "\n>>> Installing Java JDK 7"
if [ $(dpkg-query -W -f='${Status}' openjdk-7-jdk 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
	apt-get -y install openjdk-7-jdk
	mkdir /usr/java
	ln -s /usr/lib/jvm/java-7-openjdk-amd64 /usr/java/default
	if [ $( cat ~/.bash_profile 2>&1 | grep -c "JAVA_HOME") -lt 1 ];then
		export JAVA_HOME="/usr/java/default"
		echo -e "\nexport JAVA_HOME=\"/usr/java/default\"" >> ~/.bash_profile
		echo -e "If you didn't soucre this, type:\nexport JAVA_HOME=\"/usr/java/default\""			
	fi

	echo "... ok"
else
	echo "... Already done"
fi

# Install Maven
echo -e "\n>>> Installing Maven"
if [ $(dpkg-query -W -f='${Status}' maven 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
	apt-get -y install maven	
	echo "... ok"
else
	echo "... Already done"
fi



# ####################################################


echo -e "\n>>> Installing latest SOLR version"
if [ ! -e $SOLR_LINK ]; then
	# Fetch SOLR version
	solrVersion=`python $BASEDIR/utils/show-latest-solr-version.py`
	echo -e "\n>> Fetching latest SOLR Version"
	echo $solrVersion
	
	SOLR_INSTALL="$SOLR_LINK-$solrVersion"
	
	echo -e "\n>>> Creating SOLR user : solr"
	if [ $(id solr 2>&1 | grep -c "No such user") -eq 1 ];then
		# Create Solr user
		useradd -d $SOLR_LINK -s /bin/bash solr
		echo "... ok"
	else
		echo "... Already done"
	fi

	# Start SOLR installation
	echo -e "\n>> Start SOLR installation"
	cd /root/build
	wget http://archive.apache.org/dist/lucene/solr/$solrVersion/solr-$solrVersion.tgz
	tar -xf solr-$solrVersion.tgz
	solr-$solrVersion/bin/install_solr_service.sh solr-$solrVersion.tgz -i $SOLR_BASE -d /var/solr -u solr -s solr -p 8983	
	sudo -u solr mkdir $SOLR_INSTALL/lib
	rm solr-$solrVersion.tgz	
	
	echo "... ok"
else
	echo "... Already done"
fi

# ###################################################


# echo -e "\n>>> Installing latest MySQL Connector/J"
# if [ $(ls -l $SOLR_INSTALL/lib  | grep -c mysql-connector-java) -eq 0 ]; then
# 	# Fetch MySQL Connector/J version
# 	mysqlConnectorJVersion=`python $BASEDIR/utils/show-latest-mysqlconnectorj-version.py`
# 	echo -e "\n>> Fetching latest MySQL Connector/J Version"
# 	echo $mysqlConnectorJVersion
	
# 	# Start MySQL Connector/J installation
# 	echo -e "\n>> Start MySQL Connector/J installation"
# 	cd /root/build
# 	wget http://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-$mysqlConnectorJVersion.tar.gz
# 	tar -xf mysql-connector-java-$mysqlConnectorJVersion.tar.gz
# 	rm mysql-connector-java-$mysqlConnectorJVersion.tar.gz
# 	cp mysql-connector-java-$mysqlConnectorJVersion/mysql-connector-java-$mysqlConnectorJVersion-bin.jar $SOLR_INSTALL/lib	
# 	echo "... ok"
# else
# 	echo "... Already done"
# fi


# ####################################################

# ### Security



# ## Add SSL support
# echo -e "\n>>> Add SSL support"
# ipAddress=$(ifconfig | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p')

# # if [ ! -f "$SSL_DIR/solr-ssl.keystore.jks" ]; then
# # 	echo "\nUse password = S0LRd4T4"
# # 	cd $SSL_DIR
# # 	keytool -genkeypair -alias solr-ssl -keyalg RSA -keysize 2048 \
# # 		-keypass S0LRd4T4 -storepass S0LRd4T4 -validity 9999 -keystore solr-ssl.keystore.jks \
# # 		-ext SAN=DNS:localhost,DNS:solr-api.data-outlet.com,DNS:solr.data-outlet.com,DNS:www.data-outlet.com,DNS:test.data-outlet.com,DNS:office.datlinq.nl,DNS:spinel.tomenmarijke.nl,IP:$ipAddress,IP:127.0.0.1,IP:127.0.1.1 \
# # 		-dname "CN=solr.data-outlet.com, OU=IT, O=Datlinq, L=Rotterdam, ST=ZH, C=NL"
# # 	keytool -importkeystore -srckeystore solr-ssl.keystore.jks -destkeystore solr-ssl.keystore.p12 -srcstoretype jks -deststoretype pkcs12
# # 	openssl pkcs12 -in solr-ssl.keystore.p12 -out solr-ssl.pem
# # 	openssl pkcs12 -nokeys -in solr-ssl.keystore.p12 -out solr-ssl.cacert.pem
	
# 	echo -e "\n>> Adding SOLR_SSL_OPTS to /var/solr/solr.in.sh"
# 	if [ $( cat /var/solr/solr.in.sh 2>&1 | grep -c "SOLR_SSL_OPTS") -eq 0 ];then
# 		echo -e "\nSOLR_SSL_OPTS=\"\$SOLR_SSL_OPTS -Djavax.net.ssl.keyStore=$SSL_DIR/solr-ssl.keystore.jks \
# 	   -Djavax.net.ssl.keyStorePassword=S0LRd4T4 \
# 	   -Djavax.net.ssl.trustStore=$SSL_DIR/solr-ssl.keystore.jks \
# 	   -Djavax.net.ssl.trustStorePassword=S0LRd4T4\"" >> /var/solr/solr.in.sh
# 		echo "... ok"
# 	else
# 		echo "... Already done"
# 	fi

  
# #     chown solr:solr $SSL_DIR -R
# # fi

echo -e "\n>> Changing HEAP to $HEAPSIZE"
if [ $( cat /var/solr/solr.in.sh 2>&1 | grep -c "SOLR_HEAP=\"$HEAPSIZE") -eq 0 ];then
	echo -e "\nSOLR_HEAP=\"${HEAPSIZE}m\"" >> /var/solr/solr.in.sh
	echo "... ok"
else
	echo "... Already done"
fi




# echo -e "\nSSL support is disabled in /var/solr/solr.in.sh, because I can't get it to work right now"

# ####################################################

# Adjusting PATH
echo -e "\n>> Adjusting PATH"
if [ $( cat ~/.bash_profile 2>&1 | grep -c "$SOLR_LINK") -lt 1 ];then
	export PATH="$PATH:$SOLR_LINK/bin"
	echo -e "\nexport PATH=\"\$PATH:$SOLR_LINK/bin\"" >> ~/.bash_profile
	echo -e "\nexport PATH=\"\$PATH:$SOLR_LINK/bin\"" >> ~/.bashrc
	echo -e "If you didn't soucre this, type:\nexport PATH=\"\$PATH:$SOLR_LINK/bin\""
	echo "... ok"
else
	echo "... Already done"
fi


# Create logrotate script
echo -e "\n>> Create logrotate script"
if [ ! -f "/etc/logrotate.d/solr" ]; then
	cp -f $BASEDIR/config-files/solr/logrotate /etc/logrotate.d/solr
	echo "... ok"
else
	echo "... Already done"
fi


# Copying .bash_profile for user solr
echo -e "\n>> Copying .bash_profile > .bashrc for user solr"
cp ~/.bash_profile /home/solr/.bash_profile
cp ~/.bashrc /home/solr/.bashrc
chown solr:solr /home/solr/.bash*
echo "... ok"



# echo -e "\n>>> (re)Starting SOLR"
# /etc/init.d/solr restart

