#!/bin/bash
# Mon script d'installation automatique de NGinx (depuis les sources)
#
# Nicolargo - 01/2011
# GPL
#
# Syntaxe: # su - -c "./nginxautoinstall.sh"
# Syntaxe: or # sudo ./nginxautoinstall.sh
VERSION="1.1"

##############################
# Version de NGinx a installer

NGINX_VERSION="0.8.54"

##############################
# Debut de l'installation

# Test que le script est lance en root
if [ $EUID -ne 0 ]; then
  echo "Le script doit être lancé en root: # sudo $0" 1>&2
  exit 1
fi

# Récupération GnuPG key pour DotDeb
grep '^deb\ .*dotdeb' /etc/apt/sources.list > /dev/null
if [ $? -ne 0 ]
then
  wget http://www.dotdeb.org/dotdeb.gpg
  cat dotdeb.gpg | apt-key add -
  rm -f dotdeb.gpg
fi

# Ajout DotDeb package (http://www.dotdeb.org/)
grep '^deb\ .*packages\.dotdeb' /etc/apt/sources.list > /dev/null
if [ $? -ne 0 ]
then
  echo -e "\n## DotDeb Package\ndeb http://packages.dotdeb.org stable all\ndeb-src http://packages.dotdeb.org stable all\n" >> /etc/apt/sources.list
fi

# Ajout DotDeb PHP 5.3 (http://www.dotdeb.org/)
grep '^deb\ .*php53\.dotdeb' /etc/apt/sources.list > /dev/null
if [ $? -ne 0 ]
then
  echo -e "\n## DotDeb PHP 5.3\ndeb http://php53.dotdeb.org stable all\ndeb-src http://php53.dotdeb.org stable all\n" >> /etc/apt/sources.list
fi

# MaJ des depots
aptitude update

# Pre-requis
aptitude install build-essential libpcre3-dev libssl-dev zlib1g-dev 
aptitude install php5-cli php5-common php5-mysql php5-suhosin php5-fpm php5-cgi php-pear php5-xcache php5-gd php5-curl
aptitude install libcache-memcached-perl php5-memcache memcached

# Telechargement des fichiers
wget http://sysoev.ru/nginx/nginx-$NGINX_VERSION.tar.gz

# Extract
tar zxvf nginx-$NGINX_VERSION.tar.gz 

# Configure
cd nginx-$NGINX_VERSION
./configure   --conf-path=/etc/nginx/nginx.conf   --error-log-path=/var/log/nginx/error.log   --pid-path=/var/run/nginx.pid   --lock-path=/var/lock/nginx.lock   --http-log-path=/var/log/nginx/access.log   --with-http_dav_module   --http-client-body-temp-path=/var/lib/nginx/body   --with-http_ssl_module   --http-proxy-temp-path=/var/lib/nginx/proxy   --with-http_stub_status_module   --http-fastcgi-temp-path=/var/lib/nginx/fastcgi   --with-debug   --with-http_flv_module 

# Compile
make

# Install
make install

# Post installation
cd ..
mkdir /var/lib/nginx
mkdir /etc/nginx/conf.d
mkdir /etc/nginx/sites-enabled
mkdir /var/www
chown -R www-data:www-data /var/www

# Download the init script
wget http://svn.nicolargo.com/debianpostinstall/trunk/nginx
mv nginx /etc/init.d/
chmod 755 /etc/init.d/nginx
/usr/sbin/update-rc.d -f nginx defaults

# Download the default configuration file
# Nginx + default site
wget http://svn.nicolargo.com/debianpostinstall/trunk/nginx.conf
wget http://svn.nicolargo.com/debianpostinstall/trunk/default-site
mv nginx.conf /etc/nginx/
mv default-site /etc/nginx/sites-enabled/

# Start PHP5-FPM and NGinx
/etc/init.d/php5-fpm start
/etc/init.d/nginx start

# Summary
echo ""
echo "--------------------------------------"
echo "NGinx + PHP5-FPM installation finished"
echo "--------------------------------------"
echo "NGinx configuration folder:       /etc/nginx"
echo "NGinx default site configuration: /etc/nginx/sites-enabled/default-site"
echo "NGinx default HTML root:          /var/www"
echo ""
echo "If you use IpTables add the following rules:"
echo "iptables -A INPUT -i lo -s localhost -d localhost -j ACCEPT"
echo "iptables -A OUTPUT -o lo -s localhost -d localhost -j ACCEPT"
echo "iptables -A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT"
echo "iptables -A INPUT  -p tcp --dport http -j ACCEPT"
echo "--------------------------------------"
echo ""

# Fin du script
