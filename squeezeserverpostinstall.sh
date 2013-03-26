#!/bin/bash
# Mon script de post installation serveur Debian 6.0 aka Squeeze
#
# Nicolargo - 12/2011
# GPL
#
# Syntaxe: # su - -c "./squeezeserverpostinstall.sh"
# Syntaxe: or # sudo ./squeezeserverpostinstall.sh
VERSION="1.31"

#=============================================================================
# Liste des applications à installer: A adapter a vos besoins
# Voir plus bas les applications necessitant un depot specifique
# Securite
LISTE="cron-apt fail2ban logwatch lsb-release"
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
sed -i 's/# MAILTO="root"/MAILTO="'$MAIL'"/g' /etc/cron-apt/config
# fail2ban
sed -i 's/destemail = root@localhost/destemail = '$MAIL'/g' /etc/fail2ban/jail.conf
# logwatch
sed -i 's/logwatch --output mail/logwatch --output mail --mailto '$MAIL' --detail high/g' /etc/cron.daily/00logwatch

echo "Autres action à faire si besoin:"
echo "- Securisé le serveur avec un Firewall"
echo "  > http://www.debian.org/doc/manuals/securing-debian-howto/ch-sec-services.en.html"
echo "  > https://raw.github.com/nicolargo/debianpostinstall/master/firewall.sh"
echo "- Securisé le daemon SSH"
echo "  > http://www.debian-administration.org/articles/455"
echo "- Permettre l'envoi de mail"
echo "  > http://blog.nicolargo.com/2011/12/debian-et-les-mails-depuis-la-ligne-de-commande.html"

# Fin du script
