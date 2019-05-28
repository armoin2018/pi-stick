#!/bin/bash
echo "Updating: this will take some time"
rpi-update
apt-get remove --yes wolfram-engine wolframscript geany scratch scratch2 minecraft-pi
apt-get update && apt-get upgrade --yes && apt-get autoremove --yes
apt-get install --yes curl git dnsmasq iptables bridge-utils iw nmon ethtool lshw iw openssh-server kpartx ufw
apt-get install --yes openvpn filezilla firefox-esr chromium-browser jedit clamav rkhunter lighttpd
apt-get install --yes php php-fpm php-curl php-gd php-intl php-mbstring php-mcrypt php-readline php-xml php-zip php-pear php-mysql expect geoip-bin php-gettext shellinabox
apt-get install --yes arduino

# Install Docker and Pi Hole for Docker


phpenmod mcrypt mbstring

echo "Updating Virus and Malware definitions"
freshclam
rkhunter --update
rkhunter --propupd
rkhunter -c --enable all --disable none

echo "Setting up gadget functionality"
cp /boot/config.txt /boot/config.orig
echo "dtoverlay=dwc2" >> /boot/config.txt
# Setup as Serial and Ethernet Gadget
cp /boot/cmdline.txt /boot/cmdline.orig
sed -i -e 's/$/  modules-load=dwc2,g_serial,g_ether quiet init=\/usr\/lib\/raspi-config\/init_resize.sh/' /boot/cmdline.txt
echo "options g_ether use_eem=0" >> /etc/modprobe.d/g_ether.conf
systemctl enable getty@ttyGS0.service

systemctl enable ssh
systemctl start ssh

systemctl enable multi-user.target --force 
systemctl set-default multi-user.target
ufw enable
ufw allow 22
ufw allow 53
ufw allow 67
ufw allow 80
ufw allow 443

ufw allow 5800
ufw allow 5801
ufw allow 5802
ufw allow 5900
ufw allow 5901
ufw allow 5902

echo "Setting up the users"
read -s -p "Enter your desired Password: " newpass

useradd -m -d /home/stick -s /bin/bash stick 
echo -e "$newpass\n$newpass" | passwd stick
usermod -aG sudo stick
sed -i -e "s/^pi ALL/stick ALL/g" /etc/sudoers.d/010_pi-nopasswd
echo "AllowUsers stick
DenyUsers www-data pi" >> /etc/ssh/sshd_config

cd /~
deluser -remove-home pi

# Prep for open RSD
echo "Loading More Packages: This will take some time"

export DEBIAN_FRONTEND=noninteractive
debconf-set-selections <<< 'mariadb-server-10.0 mysql-server/root_password password $newpass'
debconf-set-selections <<< 'mariadb-server-10.0 mysql-server/root_password_again password $newpass'

apt-get install --yes mariadb-server

# Securing MariaDB Install

mysql_secure_installation
apt-get install --yes phpmyadmin


echo "Setting up OpenRSD"
sed -i -e "s/SHELLINABOX_ARGS=.*/SHELLINABOX_ARGS=\"--no-beep -t\"/g" /etc/default/shellinabox
sed -i -e "s/^max_execution_time =.*/max_execution_time = 300/g" /etc/php/7.0/fpm/php.ini
echo "www-data ALL=(ALL) NOPASSWD: ALL" | sudo tee --append /etc/sudoers.d/010_pi-nopasswd
lighttpd-enable-mod fastcgi-php
service php7.0-fpm force-reload
service lighttpd force-reload

cd /var/www/html
git clone https://github.com/mitchellurgero/openrsd

echo "Setting up the Hostname"
read -s -p "Enter your desired Hostname: " newhost
hostnamectl set-hostname $newhost
sed -i -e "s/^raspberrypi/$newhost/g" /etc/hosts
sed -i -e "s/^hostname$/$newhost/g" /etc/dhcpcd.conf
cd /etc/ssh
sed -i -e "s/^raspberrypi/$newhost/g" `grep -rl rapsberrypi`


#Setup the Network
echo "allow-hotplug usb0
iface usb0 inet static
	address 10.0.99.1
	netmask 255.255.255.0
	network 10.0.99.0" > /etc/network/interfaces.d/usb0

ifdown usb0 && ifup usb0

echo "interface usb0
    static ip_address=10.0.99.1/24
    static routers=10.0.99.1
    static domain_name_servers=10.0.99.1" >> /etc/dhcpcd.conf
service dhcpcd restart

mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig
echo "interface=usb0
dhcp-range=10.0.99.2,10.0.99.254,255.255.255.0,24h" > /etc/dnsmasq.conf
systemctl start dnsmasq
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE
sh -c "iptables-save > /etc/iptables.ipv4.nat"
sed -i -e "s/^exit 0$//g" /etc/rc.local

mkdir /opt /opt/scripts /mnt /mnt/ram /images
# Create RAM Drive
echo "mount -t ramfs -o size=10m ramfs /mnt/ram" >> /opt/scripts/ramdrive.sh
chmod +x /opt/scripts/ramdrive.sh


# Create Mass Storage Device
read -p "How big of Filesystem do you want to create (MB): " storagesize
if [ "$storagesize" -gt "0"]; then 
dd if=/dev/zero of=/images/usb.img bs=1MB count=$storagesize
kpartx -a /images/usb.img
mkfs -t vfat /dev/mapper/loop0p1
kpartx -d /images/usb.img 
modprobe g_file_storage file=/images/usb.img
fi 




echo "iptables-restore < /etc/iptables.ipv4.nat
/opt/scripts/ramdrive.sh
/opt/scripts/connect_mass_storage.sh
exit 0" >> /etc/rc.local



# Update our boot Sequence

# Install pi-hole
echo "Installing Pi-Hole"
curl -sSL https://install.pi-hole.net | bash

# Setup Mass Storage Device 
# TODO Encrypted Storage File
mkdir /media

# Setting up ram drive 



echo "Reboot Now"

# http://web.archive.org/web/20140718080413/http://aryo.info:80/labs/captive-portal-using-php-and-iptables.html