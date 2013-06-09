#!/bin/sh
#
# Simple Firewall configuration.
#
# Author: Nicolargo
#
# chkconfig: 2345 9 91
# description: Activates/Deactivates the firewall at boot time
#
### BEGIN INIT INFO
# Provides:          firewall.sh
# Required-Start:    $syslog $network
# Required-Stop:     $syslog $network
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start firewall daemon at boot time
# Description:       Custom Firewall scrip.
### END INIT INFO

PATH=/bin:/sbin:/usr/bin:/usr/sbin

# Services that the system will offer to the network
TCP_SERVICES="22" # SSH only
UDP_SERVICES=""
# Services the system will use from the network
REMOTE_TCP_SERVICES="80 443" # web browsing
REMOTE_UDP_SERVICES="53" # DNS
# Network that will be used for remote mgmt
# (if undefined, no rules will be setup)
# NETWORK_MGMT=192.168.0.0/24
# Port used for the SSH service, define this is you have setup a
# management network but remove it from TCP_SERVICES
SSH_PORT="22"

if ! [ -x /sbin/iptables ]; then
 exit 0
fi

##########################
# Start the Firewall rules
##########################

fw_start () {

# Input traffic:
/sbin/iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
# Services
if [ -n "$TCP_SERVICES" ] ; then
for PORT in $TCP_SERVICES; do
 /sbin/iptables -A INPUT -p tcp --dport ${PORT} -j ACCEPT
done
fi
if [ -n "$UDP_SERVICES" ] ; then
for PORT in $UDP_SERVICES; do
 /sbin/iptables -A INPUT -p udp --dport ${PORT} -j ACCEPT
done
fi
# Remote management
if [ -n "$NETWORK_MGMT" ] ; then
 /sbin/iptables -A INPUT -p tcp --src ${NETWORK_MGMT} --dport ${SSH_PORT} -j ACCEPT
else
 /sbin/iptables -A INPUT -p tcp --dport ${SSH_PORT}  -j ACCEPT
fi
# Remote testing
/sbin/iptables -A INPUT -p icmp -j ACCEPT
/sbin/iptables -A INPUT -i lo -j ACCEPT
/sbin/iptables -P INPUT DROP
/sbin/iptables -A INPUT -j LOG

# Output:
/sbin/iptables -A OUTPUT -j ACCEPT -o lo
/sbin/iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
# ICMP is permitted:
/sbin/iptables -A OUTPUT -p icmp -j ACCEPT
# So are security package updates:
# Note: You can hardcode the IP address here to prevent DNS spoofing
# and to setup the rules even if DNS does not work but then you
# will not "see" IP changes for this service:
/sbin/iptables -A OUTPUT -p tcp -d security.debian.org --dport 80 -j ACCEPT
# As well as the services we have defined:
if [ -n "$REMOTE_TCP_SERVICES" ] ; then
for PORT in $REMOTE_TCP_SERVICES; do
 /sbin/iptables -A OUTPUT -p tcp --dport ${PORT} -j ACCEPT
done
fi
if [ -n "$REMOTE_UDP_SERVICES" ] ; then
for PORT in $REMOTE_UDP_SERVICES; do
 /sbin/iptables -A OUTPUT -p udp --dport ${PORT} -j ACCEPT
done
fi
# All other connections are registered in syslog
/sbin/iptables -A OUTPUT -j LOG
/sbin/iptables -A OUTPUT -j REJECT
/sbin/iptables -P OUTPUT DROP
# Other network protections
# (some will only work with some kernel versions)
echo 1 > /proc/sys/net/ipv4/tcp_syncookies
echo 0 > /proc/sys/net/ipv4/ip_forward
echo 1 > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts
echo 1 > /proc/sys/net/ipv4/conf/all/log_martians
echo 1 > /proc/sys/net/ipv4/icmp_ignore_bogus_error_responses
echo 1 > /proc/sys/net/ipv4/conf/all/rp_filter
echo 0 > /proc/sys/net/ipv4/conf/all/send_redirects
echo 0 > /proc/sys/net/ipv4/conf/all/accept_source_route

}

##########################
# Stop the Firewall rules
##########################

fw_stop () {
/sbin/iptables -F
/sbin/iptables -t nat -F
/sbin/iptables -t mangle -F
/sbin/iptables -P INPUT DROP
/sbin/iptables -P FORWARD DROP
/sbin/iptables -P OUTPUT ACCEPT
}

##########################
# Clear the Firewall rules
##########################

fw_clear () {
/sbin/iptables -F
/sbin/iptables -t nat -F
/sbin/iptables -t mangle -F
/sbin/iptables -P INPUT ACCEPT
/sbin/iptables -P FORWARD ACCEPT
/sbin/iptables -P OUTPUT ACCEPT
}

############################
# Restart the Firewall rules
############################

fw_restart () {
fw_stop
fw_start
}

##########################
# Test the Firewall rules
##########################

fw_save () {
/sbin/iptables-save > /etc/iptables.backup
}

fw_restore () {
if [ -e /etc/iptables.backup ]; then
 /sbin/iptables-restore < /etc/iptables.backup
fi
}

fw_test () {
fw_save
fw_restart
sleep 30
fw_restore
}

case "$1" in
start|restart)
 echo -n "Starting firewall..."
 fw_restart
 echo "done."
 ;;
stop)
 echo -n "Stopping firewall..."
 fw_stop
 echo "done."
 ;;
clear)
 echo -n "Clearing firewall rules..."
 fw_clear
 echo "done."
 ;;
test)
 echo -n "Test Firewall rules..."
 echo -n "Previous configuration will be restore in 30 seconds"
 fw_test
 echo -n "Configuration as been restored"
 ;;
*)
 echo "Usage: $0 {start|stop|restart|clear|test}"
 echo "Be aware that stop drop all incoming/outgoing traffic !!!"
 exit 1
 ;;
esac
exit 0
