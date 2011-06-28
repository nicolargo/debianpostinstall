#!/bin/bash
# Mon script de post installation serveur Debian 5.0 aka Lenny
#
# Nicolargo - 01/2011
# GPL
#
# Syntaxe: # su - -c "./lennyserverpostinstall.sh"
# Syntaxe: or # sudo ./lennyserverpostinstall.sh
VERSION="1.1"

#=============================================================================
# Liste des applications à installer: A adapter a vos besoins
# Voir plus bas les applications necessitant un depot specifique
# Securite
LISTE="cron-apt fail2ban"
#=============================================================================

# Test que le script est lance en root
if [ $EUID -ne 0 ]; then
  echo "Le script doit être lancé en root: # sudo $0" 1>&2
  exit 1
fi


# Mise a jour de la liste des depots
#-----------------------------------

# Update 
echo "Mise a jour de la liste des depots"
aptitude update

# Upgrade
echo "Mise a jour du systeme"
aptitude safe-upgrade

# Installation
echo "Installation des logiciels suivants: $LISTE"
aptitude -y install $LISTE

# Configuration
#--------------

# Pour éviter les messages de Warning de Perl
# Source: http://charles.lescampeurs.org/2009/02/24/debian-lenny-and-perl-locales-warning-messages
dpkg-reconfigure locales

echo -n "Adresse mail pour les rapports de securite: "
read MAIL 
# cron-apt
sudo sed -i 's/# MAILTO="root"/MAILTO="'$MAIL'"/g' /etc/cron-apt/config
# fail2ban
sudo sed -i 's/destemail = root@localhost/destemail = '$MAIL'/g' /etc/fail2ban/jail.conf

# Fin du script
