#!/bin/bash
#
# My own script to install/upgrade NGinx+PHP5_FPM+MemCached from sources
# Mon script d'installation/maj de NGinx+PHP5_FPM+MemCached depuis les sources
#
# Nicolargo - 03/2013
# LGPL
#
# Syntaxe: # su - -c "./nginxautoinstall.sh"
# Syntaxe: or # sudo ./nginxautoinstall.sh
#
VERSION="1.1315-128"

##############################
# Version de NGinx a installer

#NGINX_VERSION="1.3.15"   # The dev version
NGINX_VERSION="1.2.8"   # The stable version

###############################
# Liste des modules a installer

NGINX_MODULES=" --with-http_dav_module --http-client-body-temp-path=/var/lib/nginx/body --with-http_ssl_module --http-proxy-temp-path=/var/lib/nginx/proxy --with-http_stub_status_module --http-fastcgi-temp-path=/var/lib/nginx/fastcgi --with-debug --with-http_flv_module --with-http_realip_module --with-http_mp4_module"

##############################

# Variables globales
#-------------------

APT_GET="apt-get -q -y --force-yes"
WGET="wget --no-check-certificate"
DATE=`date +"%Y%m%d%H%M%S"`
LOG_FILE="/tmp/nginxautoinstall-$DATE.log"

# Functions
#-----------------------------------------------------------------------------

displaymessage() {
  echo "$*"
}

displaytitle() {
  displaymessage "------------------------------------------------------------------------------"
  displaymessage "$*"  
  displaymessage "------------------------------------------------------------------------------"

}

displayerror() {
  displaymessage "$*" >&2
}

# First parameter: ERROR CODE
# Second parameter: MESSAGE
displayerrorandexit() {
  local exitcode=$1
  shift
  displayerror "$*"
  exit $exitcode
}

# First parameter: MESSAGE
# Others parameters: COMMAND (! not |)
displayandexec() {
  local message=$1
  echo -n "[En cours] $message"
  shift
  echo ">>> $*" >> $LOG_FILE 2>&1
  sh -c "$*" >> $LOG_FILE 2>&1
  local ret=$?
  if [ $ret -ne 0 ]; then
    echo -e "\r\e[0;31m   [ERROR]\e[0m $message"
  else
    echo -e "\r\e[0;32m      [OK]\e[0m $message"
  fi
  return $ret
}

# Debut de l'installation
#-----------------------------------------------------------------------------

# Test que le script est lance en root
if [ $EUID -ne 0 ]; then
  echo "Le script doit √™tre lanc√© en root (droits administrateur)" 1>&2
  exit 1
fi

displaytitle "Install prerequisites"

# R√©cup√©ration GnuPG key pour DotDeb
grep -rq '^deb\ .*dotdeb' /etc/apt/sources.list.d/*.list /etc/apt/sources.list > /dev/null 2>&1
if [ $? -ne 0 ]
then
  displayandexec "Install the DotDeb repository" "wget http://www.dotdeb.org/dotdeb.gpg ; cat dotdeb.gpg | apt-key add - ; rm -f dotdeb.gpg"
fi

displayandexec "Install lsb_release" "apt-get install lsb-release"
if [ `lsb_release -sc` == "squeeze" ]
then
  # Squeeze

  # Ajout DotDeb package (http://www.dotdeb.org/)
  grep -rq '^deb\ .*packages\.dotdeb' /etc/apt/sources.list.d/*.list /etc/apt/sources.list > /dev/null 2>&1
  if [ $? -ne 0 ]
  then  
    echo -e "\n## DotDeb Package\ndeb http://packages.dotdeb.org squeeze all\ndeb-src http://packages.dotdeb.org squeeze all\n" >> /etc/apt/sources.list
  fi

else
  # Lenny and older

  # Ajout DotDeb package (http://www.dotdeb.org/)
  grep -rq '^deb\ .*packages\.dotdeb' /etc/apt/sources.list.d/*.list /etc/apt/sources.list > /dev/null 2>&1
  if [ $? -ne 0 ]
  then  
    echo -e "\n## DotDeb Package\ndeb http://packages.dotdeb.org oldstable all\ndeb-src http://packages.dotdeb.org oldstable all\n" >> /etc/apt/sources.list
  fi

  # Ajout DotDeb PHP 5.3 (http://www.dotdeb.org/)
  grep -rq '^deb\ .*php53\.dotdeb' /etc/apt/sources.list.d/*.list /etc/apt/sources.list > /dev/null 2>&1
  if [ $? -ne 0 ]
  then
    echo -e "\n## DotDeb PHP 5.3\ndeb http://php53.dotdeb.org oldstable all\ndeb-src http://php53.dotdeb.org oldstable all\n" >> /etc/apt/sources.list
  fi

fi

# MaJ des depots
displayandexec "Update the repositories list" $APT_GET update

# Pre-requis
displayandexec "Install development tools" $APT_GET install build-essential libpcre3-dev libssl-dev zlib1g-dev php5-dev
displayandexec "Install PHP-FPM5" $APT_GET install php5-cli php5-common php5-mysql php5-suhosin php5-fpm php-pear php5-apc php5-gd php5-curl
displayandexec "Install MemCached" $APT_GET install libcache-memcached-perl php5-memcache memcached
displayandexec "Install Redis" $APT_GET install redis-server php5-redis

displaytitle "Install NGinx version $NGINX_VERSION"

# Telechargement des fichiers
displayandexec "Download NGinx version $NGINX_VERSION" $WGET http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz

# Extract
displayandexec "Uncompress NGinx version $NGINX_VERSION" tar zxvf nginx-$NGINX_VERSION.tar.gz

# Configure
cd nginx-$NGINX_VERSION
displayandexec "Configure NGinx version $NGINX_VERSION" ./configure --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --pid-path=/var/run/nginx.pid --lock-path=/var/lock/nginx.lock --http-log-path=/var/log/nginx/access.log $NGINX_MODULES

# Compile
displayandexec "Compile NGinx version $NGINX_VERSION" make

# Install or Upgrade
TAGINSTALL=0
if [ -x /usr/local/nginx/sbin/nginx ]
then
	# Upgrade
	cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.$DATE
	displayandexec "Upgrade NGinx to version $NGINX_VERSION" make install

else
	# Install
	displayandexec "Install NGinx version $NGINX_VERSION" make install
	TAGINSTALL=1
fi

# Post installation
if [ $TAGINSTALL == 1 ]
then
	displayandexec "Post installation script for NGinx version $NGINX_VERSION" "cd .. ; mkdir /var/lib/nginx ; mkdir /etc/nginx/conf.d ; mkdir /etc/nginx/sites-enabled ; mkdir /var/www ; chown -R www-data:www-data /var/www"
fi

# Download the default configuration file
# Nginx + default site
if [ $TAGINSTALL == 1 ]
then
	displayandexec "Init the default configuration file for NGinx" "$WGET https://raw.github.com/nicolargo/debianpostinstall/master/nginx.conf ; $WGET https://raw.github.com/nicolargo/debianpostinstall/master/default-site ; mv nginx.conf /etc/nginx/ ; mv default-site /etc/nginx/sites-enabled/"
fi

# Download the init script
displayandexec "Install the NGinx init script" "$WGET https://raw.github.com/nicolargo/debianpostinstall/master/nginx ; mv nginx /etc/init.d/ ; chmod 755 /etc/init.d/nginx ; /usr/sbin/update-rc.d -f nginx defaults"

# Log file rotate
cat > /etc/logrotate.d/nginx <<EOF
/var/log/nginx/*_log {
	missingok
	notifempty
	sharedscripts
	postrotate
		/bin/kill -USR1 \`cat /var/run/nginx.pid 2>/dev/null\` 2>/dev/null || true
	endscript
}
EOF

displaytitle "Start processes"

# Start PHP5-FPM and NGinx
if [ $TAGINSTALL == 1 ]
then
	displayandexec "Start PHP" /etc/init.d/php5-fpm start
	displayandexec "Start NGinx" /etc/init.d/nginx start
else
	displayandexec "Restart PHP" /etc/init.d/php5-fpm restart
	displayandexec "Restart NGinx" "killall nginx ; /etc/init.d/nginx start"
fi

# Summary
echo ""
echo "------------------------------------------------------------------------------"
echo "                    NGinx + PHP5-FPM installation finished"
echo "------------------------------------------------------------------------------"
echo "NGinx configuration folder:       /etc/nginx"
echo "NGinx default site configuration: /etc/nginx/sites-enabled/default-site"
echo "NGinx default HTML root:          /var/www"
echo ""
echo "Installation script  log file:	$LOG_FILE"
echo ""
echo "Notes: If you use IpTables add the following rules"
echo "iptables -A INPUT -i lo -s localhost -d localhost -j ACCEPT"
echo "iptables -A OUTPUT -o lo -s localhost -d localhost -j ACCEPT"
echo "iptables -A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT"
echo "iptables -A INPUT  -p tcp --dport http -j ACCEPT"
echo ""
echo "If you want to manage your PHP session with Redis,"
echo "just add this two line in the /etc/php5/fpm/php.ini file:"
echo "  session.save_handler = redis"
echo "  session.save_path = \"tcp://127.0.0.1:6379?weight=1\""
echo "------------------------------------------------------------------------------"
echo ""

# Fin du script
