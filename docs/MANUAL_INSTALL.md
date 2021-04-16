<img alt="MudPi Smart Garden" title="MudPi Smart Garden" src="https://mudpi.app/img/mudPI_LOGO_small_flat.png" width="60px">

# Manual Installation
Below are the manual installation tasks to get MudPi installed and running on RaspberryPi. The installer will take care of this for you.

Make folders for MudPi
```
sudo mkdir /home/mudpi
sudo mkdir -p /home/mudpi/backups
sudo mkdir -p /home/mudpi/networking/defaults
sudo mkdir -p /home/mudpi/tmp
sudo mkdir -p /home/mudpi/logs
sudo mkdir -p /home/mudpi/scripts
sudo mkdir -p /home/mudpi/installer
```

Set folder ownership (use whatever user will run mudpi)
```
sudo chown -R www-data:www-data /home/mudpi
```

Do a quick update
```
sudo apt-get update
```

Update sources so we can install php7.3
```
sudo apt-get install software-properties-common
sudo apt-get -y install apt-transport-https lsb-release ca-certificates curl
sudo curl -sSL -o /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
sudo sh -c 'echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list'
```

If you are on Debian 9 (Stretch) then you need to update sources to look for new buster packages instead
```
sudo sed -i 's/stretch/buster/g' /etc/apt/sources.list
```

Update the new source lists and upgrade
```
sudo apt-get update
sudo apt-get dist-upgrade
sudo apt-get upgrade
```

Enable ssh
```
sudo systemctl enable ssh
sudo systemctl start ssh
```

Install dependancies (without prompting)
```
sudo DEBIAN_FRONTEND=noninteractive apt-get install php7.3 php7.3-cgi php7.3-common php7.3-cli php7.3-fpm php7.3-mbstring php7.3-mysql php7.3-opcache php7.3-curl php7.3-gd php7.3-curl php7.3-zip php7.3-xml php7.3-dev php-redis python3-pip supervisor nodejs npm git tmux curl wget zip unzip tmux htop libffi-dev libbz2-dev liblzma-dev libsqlite3-dev libncurses5-dev libgdbm-dev zlib1g-dev libreadline-dev libssl-dev tk-dev build-essential libncursesw5-dev libc6-dev openssl ffmpeg -y --fix-missing
```

If anything fails try fix-missing
```
sudo apt-get install --fix-missing 
```

Install pip3 (python3) packages:
```
sudo pip3 install RPi.GPIO Adafruit_DHT
```

Install composer
```
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php -r "if (hash_file('sha384', 'composer-setup.php') === '756890a4488ce9024fc62c56153228907f1545c228516cbf63f885e036d37e9a59d27d63f46af1d4d07ee0f76181c7d3') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
sudo php composer-setup.php --install-dir=/usr/local/bin --filename=composer --quiet
php -r "unlink('composer-setup.php');"
```

Install redis and change config to allow systemd to manage it
```
sudo apt install redis-server
sudo sed -i 's/supervised no/supervised systemd/g' /etc/redis/redis.conf
sudo systemctl restart redis
```

Move old installer files if there are any
```
sudo mv /home/mudpi/installer "/home/mudpi/installer.`date +%F-%R`"
```

Clone in installer files and set permissions
```
git clone --depth 1 https://github.com/mudpi/installer /tmp/mudpi_installer
sudo mv /tmp/mudpi_installer /home/mudpi/installer
sudo chown -R www-data:www-data "/home/mudpi"
```

Clone in core files and set permissions
```
git clone --depth 1 https://github.com/mudpi/mudpi-core /tmp/mudpi_core
sudo mv /tmp/mudpi_core /home/mudpi/core
sudo chown -R www-data:www-data "/home/mudpi"
```

Install MudPi required packages
```
pip3 install -r /home/mudpi/core/requirements.txt
pip3 install /home/mudpi/core/
```

Make backups of all old configs
```
sudo cp /etc/network/interfaces "/home/mudpi/backups/interfaces"
sudo cp /etc/hostapd/hostapd.conf "/home/mudpi/backups/hostapd.conf"
sudo cp /etc/dnsmasq.conf "/home/mudpi/backups/dnsmasq.conf"
sudo cp /etc/dhcpcd.conf "/home/mudpi/backups/dhcpcd.conf"
sudo cp /etc/rc.local "/home/mudpi/backups/rc.local"
sudo cp /home/mudpi/mudpi.config "/home/mudpi/backups/mudpi.config"
sudo cp /etc/sudoers "/home/mudpi/backups/sudoers"
sudo tar -czf "/home/mudpi/backups/nginx.`date +%F-%R`.tar.gz" "/etc/nginx/sites-available"
sudo cp /etc/hosts "/home/mudpi/backups/hosts"
sudo crontab -u pi -l > "/tmp/cron"
sudo mv "/tmp/cron" "/home/mudpi/backups/cron"
sudo crontab -l > "/tmp/cron_root"
sudo mv "/tmp/cron_root" "/home/mudpi/backups/cron_root"
```

Install supervsor job
```
sudo cp /home/mudpi/installer/configs/supervisor_mudpi.conf /etc/supervisor/conf.d/mudpi.conf
```

Update your hosts file by adding the following to the bottom
```
192.168.2.1 mudpi mudpi.local mudpi.home #MUDPI-apmode
10.45.12.1	clients3.google.com #MUDPI-captiveportal
10.45.12.1	clients.l.google.com #MUDPI-captiveportal
10.45.12.1	connectivitycheck.android.com #MUDPI-captiveportal
10.45.12.1	connectivitycheck.gstatic.com #MUDPI-captiveportal
10.45.12.1	play.googleapis.com #MUDPI-captiveportal
```

Update your sudoers files with visudo and add the following
```
www-data ALL=(ALL) NOPASSWD:/sbin/shutdown -h now
www-data ALL=(ALL) NOPASSWD:/sbin/reboot
www-data ALL=(ALL) NOPASSWD:/sbin/ifdown
www-data ALL=(ALL) NOPASSWD:/sbin/ifup
www-data ALL=(ALL) NOPASSWD:/sbin/dhclient
www-data ALL=(ALL) NOPASSWD:/bin/cat /etc/wpa_supplicant/wpa_supplicant.conf
www-data ALL=(ALL) NOPASSWD:/bin/cat /etc/wpa_supplicant/wpa_supplicant-wlan[0-9].conf
www-data ALL=(ALL) NOPASSWD:/bin/cp /tmp/wpa_supplicant.tmp /etc/wpa_supplicant/wpa_supplicant.conf
www-data ALL=(ALL) NOPASSWD:/bin/cp /tmp/wpa_supplicant.tmp /etc/wpa_supplicant/wpa_supplicant-wlan[0-9].conf
www-data ALL=(ALL) NOPASSWD:/bin/cp /tmp/wpa_supplicant.tmp /home/mudpi/tmp/wpa_supplicant.conf
www-data ALL=(ALL) NOPASSWD:/bin/rm /tmp/wpa_supplicant.tmp
www-data ALL=(ALL) NOPASSWD:/sbin/wpa_cli -i wlan[0-9] scan_results
www-data ALL=(ALL) NOPASSWD:/sbin/wpa_cli -i wlan[0-9] scan
www-data ALL=(ALL) NOPASSWD:/sbin/wpa_cli -i wlan[0-9] reconfigure
www-data ALL=(ALL) NOPASSWD:/sbin/wpa_cli -i wlan[0-9] select_network
www-data ALL=(ALL) NOPASSWD:/bin/cp /tmp/hostapddata /etc/hostapd/hostapd.conf
www-data ALL=(ALL) NOPASSWD:/bin/systemctl start hostapd.service
www-data ALL=(ALL) NOPASSWD:/bin/systemctl stop hostapd.service
www-data ALL=(ALL) NOPASSWD:/bin/systemctl enable hostapd.service
www-data ALL=(ALL) NOPASSWD:/bin/systemctl disable hostapd.service
www-data ALL=(ALL) NOPASSWD:/bin/systemctl start dnsmasq.service
www-data ALL=(ALL) NOPASSWD:/bin/systemctl enable dnsmasq.service
www-data ALL=(ALL) NOPASSWD:/bin/systemctl disable dnsmasq.service
www-data ALL=(ALL) NOPASSWD:/bin/systemctl stop dnsmasq.service
www-data ALL=(ALL) NOPASSWD:/bin/cp /tmp/dnsmasqdata /etc/dnsmasq.conf
www-data ALL=(ALL) NOPASSWD:/bin/cp /tmp/dhcpddata /etc/dhcpcd.conf
www-data ALL=(ALL) NOPASSWD:/bin/cp /home/mudpi/networking/dhcpcd.conf /etc/dhcpcd.conf
www-data ALL=(ALL) NOPASSWD:/sbin/ip link set wlan[0-9] down
www-data ALL=(ALL) NOPASSWD:/sbin/ip link set wlan[0-9] up
www-data ALL=(ALL) NOPASSWD:/sbin/ip -s a f label wlan[0-9]
www-data ALL=(ALL) NOPASSWD:/sbin/iw dev wlan0 scan ap-force
www-data ALL=(ALL) NOPASSWD:/usr/bin/auto_hotspot.sh
```

## Completed
Reboot
```
sudo reboot
```

## Nginx Web Server (optional)
Install Nginx (web server) and DB
```
sudo apt-get install nginx mariadb-server mariadb-client -y
```

Make sure to remove apache first if that was already installed:
```
sudo service apache2 stop
sudo update-rc.d -f apache2 remove
sudo apt-get remove apache2
```

Remove the default configs
```
sudo rm /etc/nginx/sites-enabled/default
sudo rm /etc/nginx/sites-available/default
```

## MudPi UI (optional)
Clone in UI files and set permissions
```
git clone --depth 1 https://github.com/mudpi/ui /tmp/mudpi_ui
sudo mv /tmp/mudpi_ui /var/www/html/mudpi
sudo chown -R www-data:www-data "/var/www/html/mudpi"
```

Copy config files over and create symlink
```
sudo cp /var/www/html/mudpi/configs/mudpi_ui.conf /etc/nginx/sites-available/mudpi_ui.conf
sudo ln -sf /etc/nginx/sites-available/mudpi_ui.conf /etc/nginx/sites-enabled
```

Enable php-redis
```
yes '' | sudo pecl install redis
echo "extension=redis.so" | sudo tee /etc/php/7.3/mods-available/redis.ini
sudo phpenmod redis
sudo service php-fpm7.3 restart 
```

Restart nginx
```
sudo service nginx restart
```

Install dependencies
```
composer update -d /var/www/html/mudpi
```

## MudPi Assistant (optional)
Clone in Assistant files and set permissions
```
git clone --depth 1 https://github.com/mudpi/assistant /tmp/mudpi_assistant
sudo mv /tmp/mudpi_assistant /var/www/html/mudpi
sudo chown -R www-data:www-data "/var/www/html/mudpi_assistant"
```

Copy config files over and create symlink
```
sudo cp /var/www/html/mudpi_assistant/configs/mudpi_assistant.conf /etc/nginx/sites-available/mudpi_assistant.conf
sudo ln -sf /etc/nginx/sites-available/mudpi_assistant.conf /etc/nginx/sites-enabled
```

If you are using MudPi Assistant without MudPi UI then you should install the redirect config as well to route UI traffic to assistant
```
sudo cp /home/mudpi/installer/configs/assistant_redirect.conf /etc/nginx/sites-available/assistant_redirect.conf
sudo ln -sf /etc/nginx/sites-available/assistant_redirect.conf /etc/nginx/sites-enabled
```

Restart nginx
```
sudo service nginx restart
```
