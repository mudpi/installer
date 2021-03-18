#!/bin/bash
	
# This bash script is used to install Mudpi
# author: Eric Davisson @theDavisson <hi@ericdavisson.com>
# license: MIT

repo="mudpi/mudpi-core"
repo_installer="mudpi/installer"
repo_assistant="mudpi/assistant"
repo_ui="mudpi/ui"
branch="master"
mudpi_dir="/etc/mudpi"
webroot_dir="/var/www/html"
mudpi_user="www-data"
maroon='\033[0;35m'
green='\033[1;32m'
user=$(whoami)
# Grab some version details
VERSION=$(curl -s "https://api.github.com/repos/${repo}/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")' )
rasp_version=`sed 's/\..*//' /etc/debian_version`

# Manual options to bypass prompts
force_yes=0 #Option to force yes through any prompts
nginx_option=0
assistant_option=0
ui_option=0
ap_mode_option=0

# usage notes
usage=$(cat << EOF
Usage: install.sh [OPTION]\n
-y, --yes, --force-yes\n\Forces "yes" answer to all prompts
-b, --branch <name>\n\tOverrides the default git branch (master)
-h, --help\n\tOutputs usage notes and exits
-v, --version\n\tOutputs release info and exits\n
EOF
)

# command-line options
while :; do
	case $1 in
		-y|--yes|--force-yes)
		force_yes=1
		apt_option="-y"
		;;
		-b|--branch)
		branch="$2"
		shift
		;;
		-h|--help)
		printf "$usage"
		exit 1
		;;
		-v|--version)
		printf "MudPi v${VERSION} - Configurable automated smart garden for RaspberryPi\n"
		exit 1
	;;
		-*|--*)
		echo "Unknown option: $1"
		printf "$usage"
		exit 1
		;;
		*)
		break
		;;
	esac
	shift
done

function displayWelcome() {
	echo -e "${green}\n"
	echo -e ' __  __           _ _____ _ '
	echo -e '|  \/  |         | |  __ (_)'
	echo -e '| \  / |_   _  __| | |__) | '
	echo -e '| |\/| | | | |/ _` |  ___/ | '
	echo -e '| |  | | |_| | (_| | |   | | '
	echo -e '|_|  |_|\__,_|\__,_|_|   |_| '
	echo -e "Version: $VERSION"
	echo -e '_________________________________________________'
	echo -e "${maroon}The next few steps will guide you through the installation process."
	echo -e ''
}

function log_info() {
	echo -e "\033[1;32mMudPi Install: $*\033[m"
}

function log_error() {
	echo -e "\033[1;37;41mMudPi Install Error: $*\033[m"
	exit 1
}

function log_warning() {
	echo -e "\033[1;33mWarning: $*\033[m"
}

# Determine Raspbian version
version_msg="Unknown Raspbian Version"
if [ "$rasp_version" -eq "10" ]; then
	version_msg="Raspbian 10.0 (Buster)"
	php_version="7.3"
	php_package="php${php_version} php${php_version}-cgi php${php_version}-common php${php_version}-cli php${php_version}-fpm php${php_version}-mbstring php${php_version}-mysql php${php_version}-opcache php${php_version}-curl php${php_version}-gd php${php_version}-curl php${php_version}-zip php${php_version}-xml php-redis"
elif [ "$rasp_version" -eq "9" ]; then
	version_msg="Raspbian 9.0 (Stretch)" 
	php_version="7.3"
	php_package="php${php_version} php${php_version}-cgi php${php_version}-common php${php_version}-cli php${php_version}-fpm php${php_version}-mbstring php${php_version}-mysql php${php_version}-opcache php${php_version}-curl php${php_version}-gd php${php_version}-curl php${php_version}-zip php${php_version}-xml php-redis"
elif [ "$rasp_version" -lt "9" ]; then
	echo "Raspbian ${rasp_version} is unsupported. Please upgrade."
	exit 1
fi

function installationSetup() 
{
	log_info "Confirm Settings"
	echo "Detected ${version_msg}" 
	echo "Install directory: ${mudpi_dir}"
	echo -n "Install to web server root directory: ${webroot_dir}? [Y/n]: "
	if [ "$force_yes" == 0 ]; then
		read answer < /dev/tty
		if [ "$answer" != "${answer#[Nn]}" ]; then
			read -e -p < /dev/tty "Enter alternate  directory: " -i "/var/www/html" webroot_dir
		fi
	else
		echo -e
	fi
	echo "Install to directory: ${webroot_dir}"

	echo -n "Complete installation with these settings? [Y/n]: "
	if [ "$force_yes" == 0 ]; then
		read answer < /dev/tty
		if [ "$answer" != "${answer#[Nn]}" ]; then
			echo "Installation aborted."
			exit 0
		fi
	else
		echo -e
	fi

}

function makeDirectories() 
{
	#Make Mudpi folders and move configs
	echo "Creating directories..."
	if [ ! -d "$mudpi_dir" ]; then
		echo "$mudpi_dir directory doesn't exist. Creating..."
		sudo mkdir -p $mudpi_dir
	else
		log_warning "$mudpi_dir already directory exists."
	fi
	sudo mkdir -p ${mudpi_dir}/backups
	sudo mkdir -p ${mudpi_dir}/networking/defaults
	sudo mkdir -p ${mudpi_dir}/tmp
	sudo mkdir -p ${mudpi_dir}/logs
	sudo mkdir -p ${mudpi_dir}/scripts
	sudo mkdir -p ${mudpi_dir}/installer

	sudo chown -R ${mudpi_user}:${mudpi_user} $mudpi_dir || log_error "Unable to change file ownership for '$mudpi_dir'"
}

# Runs a system software update to make sure we're using all fresh packages
function installDependencies() 
{
	log_info "Installing required packages"
	sudo apt-get update
	sudo apt-get install software-properties-common
	if [ "$rasp_version" -eq "9" ]; then
		sudo sed -i 's/stretch/buster/g' /etc/apt/sources.list
	fi
	sudo apt-get -y install apt-transport-https lsb-release ca-certificates curl
	sudo curl -sSL -o /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
	sudo sh -c 'echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list'
	sudo apt-get update
	sudo apt-get dist-upgrade
	sudo apt-get upgrade
	# retry check if dependencies fail
	if ! sudo DEBIAN_FRONTEND=noninteractive apt-get install $php_package python3-pip supervisor nodejs npm git tmux curl wget zip unzip tmux htop libffi-dev libbz2-dev liblzma-dev libsqlite3-dev libncurses5-dev libgdbm-dev zlib1g-dev libreadline-dev libssl-dev tk-dev build-essential libncursesw5-dev libc6-dev openssl -y --fix-missing; then
		# try a fix and install one more time
		log_warning "Failed to install dependencies. Trying to fix-missing and reinstall..."
		sudo apt-get install --fix-missing 
		sudo DEBIAN_FRONTEND=noninteractive apt-get install $php_package python3-pip supervisor nodejs npm git tmux curl wget zip unzip tmux htop libffi-dev libbz2-dev liblzma-dev libsqlite3-dev libncurses5-dev libgdbm-dev zlib1g-dev libreadline-dev libssl-dev tk-dev build-essential libncursesw5-dev libc6-dev openssl -y --fix-missing || log_error "Unable to install dependencies"
	else
		echo "Main Depepencies Successfully Installed"
	fi
	sudo apt-get install ffmpeg -y --fix-missing || log_error "Unable to install ffmpeg"
	sudo pip3 install RPi.GPIO Adafruit_DHT || log_error "Unable to install pip3 packages"
	if [ -f "/usr/local/bin/composer" ]; then
		log_info "Composer already installed!"
	else
		mkdir -p $HOME/.local/bin
		sudo wget https://raw.githubusercontent.com/composer/getcomposer.org/76a7060ccb93902cd7576b67264ad91c8a2700e2/web/installer -O - -q | sudo php -- --quiet --install-dir=$HOME/.local/bin --filename=composer || log_error "Problem installing composer"
		export PATH="$HOME/.local/bin:$PATH"
	fi
	rm composer-setup.php
	sudo apt-get install redis-server -y || log_error "Unable to install redis"
	sudo sed -i 's/supervised no/supervised systemd/g' /etc/redis/redis.conf || log_error "Unable to update /etc/redis/redis.conf"
	sudo systemctl restart redis || log_error "Unable to restart redis"
}

function askNginxInstall() {
	if [ -d /etc/nginx ]; then
		log_info "Detected Nginx already installed!"
		nginx_option=1
	else
		echo -n "Install nginx for web server? [Y/n]: "
		if [ "$force_yes" == 0 ]; then
			read answer < /dev/tty
			if [ "$answer" != "${answer#[Nn]}" ]; then
				echo -e
			else
				nginx_option=1
			fi
		else
			nginx_option=1
		fi
	fi
}

function installNginx() {
	log_info "Setting up web server support"
	sudo service apache2 stop
	sudo update-rc.d -f apache2 remove
	sudo apt-get remove apache2
	sudo apt-get install nginx mariadb-server mariadb-client -y
}

function askAssistantInstall() {
	echo "MudPi Assistant is a web interface for first time configurations"
	echo -n "Install mudpi-assistant and enable web configs? [Y/n]: "
	if [ "$force_yes" == 0 ]; then
		read answer < /dev/tty
		if [ "$answer" != "${answer#[Nn]}" ]; then
			echo -e
		else
			assistant_option=1
		fi
	else
		assistant_option=1
	fi
}

function askUIInstall() {
	echo "MudPi UI is a lightweight web interface to monitor MudPi"
	echo -n "Install mudpi-ui and enable dashboard? [Y/n]: "
	if [[ "$force_yes" == 0 ]]; then
		read answer < /dev/tty
		if [ "$answer" != "${answer#[Nn]}" ]; then
			echo -e
		else
			ui_option=1
		fi
	else
		ui_option=1
	fi
}

# ask to install access point
function askAPModeInstall() {
	echo -n "Install hostapd and make Access Point configuration? [Y/n]: "
	if [ "$force_yes" == 0 ]; then
		read answer < /dev/tty
		if [ "$answer" != "${answer#[Nn]}" ]; then
			echo -e
		else
			ap_mode_option=1
		fi
	else
		ap_mode_option=1
	fi
}

function installAPMode() {
	log_info "Setting up Access Point support"
	sudo apt-get install hostapd dnsmasq -y || log_error "Unable to install hostapd dnsmasq"
	sudo systemctl stop hostapd
	sudo systemctl stop dnsmasq
	sudo systemctl unmask hostapd
	sudo systemctl disable hostapd
	sudo systemctl disable dnsmasq
}

function EnableSSH() 
{
	log_info "Enabling SSH for remote access"
	sudo systemctl enable ssh
	sudo systemctl start ssh
}

function downloadInstallerFiles() 
{
	if [ ! -d "$mudpi_dir/installer" ]; then
		sudo mkdir -p $mudpi_dir/installer || log_error "Unable to create new mudpi root directory"
	fi

	if [ -d "$mudpi_dir/installer" ]; then
		sudo mv $mudpi_dir/installer "$mudpi_dir/installer.`date +%F_%H%M%S`" || log_error "Unable to remove old webroot directory"
	fi

	log_info "Cloning latest installer files from github"
	git clone --depth 1 https://github.com/${repo_installer} /tmp/mudpi_installer || log_error "Unable to download installer files from github"
	sudo mv /tmp/mudpi_installer $mudpi_dir/installer || log_error "Unable to move Mudpi installer to $mudpi_dir/installer"
	sudo chown -R $mudpi_user:$mudpi_user "$mudpi_dir" || log_error "Unable to set permissions in '$mudpi_dir/installer'"
}

# Fetches latest files from github
function downloadMudpiCoreFiles() 
{
	if [ ! -d "$webroot_dir" ]; then
		sudo mkdir -p $webroot_dir || log_error "Unable to create new webroot directory"
	fi

	if [ -d "$mudpi_dir/core" ]; then
		sudo mv $mudpi_dir/core "$mudpi_dir/core.`date +%F_%H%M%S`" || log_error "Unable to remove old core directory"
	fi

	log_info "Cloning latest core files from github"
	git clone --depth 1 https://github.com/${repo} /tmp/mudpi_core || log_error "Unable to download core files from github"
	sudo mv /tmp/mudpi_core $mudpi_dir/core || log_error "Unable to move Mudpi core to $mudpi_dir"
	sudo chown -R $mudpi_user:$mudpi_user "$mudpi_dir" || log_error "Unable to set permissions in '$mudpi_dir'"
	sudo pip3 install -r $mudpi_dir/core/requirements.txt
}

# Fetches latest files from github
function downloadAssistantFiles() 
{
	if [ ! -d "$webroot_dir" ]; then
		sudo mkdir -p $webroot_dir || log_error "Unable to create new webroot directory"
	fi

	if [ -d "$webroot_dir/mudpi_assistant" ]; then
		sudo mv ${webroot_dir}/mudpi_assistant "${webroot_dir}/mudpi_assistant.`date +%F_%H%M%S`" || log_error "Unable to remove old assistant webroot directory"
	fi

	log_info "Cloning latest assistant files from github"
	git clone --depth 1 https://github.com/${repo_assistant} /tmp/mudpi_assistant || log_error "Unable to download assistant files from github"
	sudo mv /tmp/mudpi_assistant $webroot_dir || log_error "Unable to move Mudpi to web root"
	composer update -d${webroot_dir}/mudpi_assistant || log_error "Unable to run composer install"
	sudo chown -R $mudpi_user:$mudpi_user "${webroot_dir}/mudpi_assistant" || log_error "Unable to set permissions in '$webroot_dir'"
	sudo find ${webroot_dir}/mudpi_assistant -type d -exec chmod 1755 {} + || log_error "Unable to set permissions in '$webroot_dir'"
	sudo find ${webroot_dir}/mudpi_assistant -type f -exec chmod 1644 {} + || log_error "Unable to set permissions in '$webroot_dir'"

}


# Fetches latest files from github
function downloadUIFiles() 
{
	if [ ! -d "$webroot_dir" ]; then
		sudo mkdir -p $webroot_dir || log_error "Unable to create new webroot directory"
	fi

	if [ -d "$webroot_dir/mudpi" ]; then
		sudo mv ${webroot_dir}/mudpi "${webroot_dir}/mudpi.`date +%F_%H%M%S`" || log_error "Unable to remove old ui webroot directory"
	fi

	log_info "Cloning latest ui files from github"
	git clone --depth 1 https://github.com/${repo_ui} /tmp/mudpi || log_error "Unable to download ui files from github"
	sudo mv /tmp/mudpi $webroot_dir || log_error "Unable to move Mudpi UI to web root"
	sleep 1
	composer update -d ${webroot_dir}/mudpi || log_error "Unable to run composer install"
	sudo chown -R $mudpi_user:$mudpi_user "${webroot_dir}/mudpi" || log_error "Unable to set permissions in '$webroot_dir'"
	sudo find ${webroot_dir}/mudpi -type d -exec chmod 755 {} + || log_error "Unable to set permissions in '$webroot_dir'"
	sudo find ${webroot_dir}/mudpi -type f -exec chmod 644 {} + || log_error "Unable to set permissions in '$webroot_dir'"
}

# Check for existing /etc/network/interfaces and /etc/hostapd/hostapd.conf files
function backupConfigs() 
{
	echo "Making backups of current configs..."
	if [ -f /etc/network/interfaces ]; then
		sudo cp /etc/network/interfaces "$mudpi_dir/backups/interfaces.`date +%F_%H%M%S`"
		sudo ln -sf "$mudpi_dir/backups/interfaces.`date +%F_%H%M%S`" "$mudpi_dir/backups/interfaces"
	fi

	if [ -f /etc/hostapd/hostapd.conf ]; then
		sudo cp /etc/hostapd/hostapd.conf "$mudpi_dir/backups/hostapd.conf.`date +%F_%H%M%S`"
		sudo ln -sf "$mudpi_dir/backups/hostapd.conf.`date +%F_%H%M%S`" "$mudpi_dir/backups/hostapd.conf"
	fi

	if [ -f /etc/dnsmasq.conf ]; then
		sudo cp /etc/dnsmasq.conf "$mudpi_dir/backups/dnsmasq.conf.`date +%F_%H%M%S`"
		sudo ln -sf "$mudpi_dir/backups/dnsmasq.conf.`date +%F_%H%M%S`" "$mudpi_dir/backups/dnsmasq.conf"
	fi

	if [ -f /etc/dhcpcd.conf ]; then
		sudo cp /etc/dhcpcd.conf "$mudpi_dir/backups/dhcpcd.conf.`date +%F_%H%M%S`"
		sudo ln -sf "$mudpi_dir/backups/dhcpcd.conf.`date +%F_%H%M%S`" "$mudpi_dir/backups/dhcpcd.conf"
		cat /etc/dhcpcd.conf | sudo tee -a ${mudpi_dir}/networking/defaults
	fi

	if [ -f /etc/rc.local ]; then
		sudo cp /etc/rc.local "$mudpi_dir/backups/rc.local.`date +%F_%H%M%S`"
		sudo ln -sf "$mudpi_dir/backups/rc.local.`date +%F_%H%M%S`" "$mudpi_dir/backups/rc.local"
	fi

	if [ -f /etc/mudpi/core/mudpi.config ]; then
		sudo cp $mudpi_dir/mudpi.config "$mudpi_dir/backups/mudpi.config.`date +%F_%H%M%S`"
		sudo ln -sf "$mudpi_dir/backups/mudpi.config.`date +%F_%H%M%S`" "$mudpi_dir/backups/mudpi.config"
	fi

	if [ -f /etc/sudoers ]; then
		sudo cp /etc/sudoers "$mudpi_dir/backups/sudoers.`date +%F_%H%M%S`"
		sudo ln -sf "$mudpi_dir/backups/sudoers.`date +%F_%H%M%S`" "$mudpi_dir/backups/sudoers"
	fi

	if [ -f /etc/redis/redis.conf ]; then
		sudo cp /etc/redis/redis.conf "$mudpi_dir/backups/redis.conf.`date +%F_%H%M%S`"
		sudo ln -sf "$mudpi_dir/backups/redis.conf.`date +%F_%H%M%S`" "$mudpi_dir/backups/redis.conf"
	fi
	
	if [ -d /etc/nginx ]; then
		sudo tar -czf "$mudpi_dir/backups/nginx.`date +%F_%H%M%S`.tar.gz" "/etc/nginx/sites-available"
	fi

	if [ -f /etc/hosts ]; then
		sudo cp /etc/hosts "$mudpi_dir/backups/hosts.`date +%F_%H%M%S`"
		sudo ln -sf "$mudpi_dir/backups/hosts.`date +%F_%H%M%S`" "$mudpi_dir/backups/hosts"
	fi

	sudo crontab -u "$user" -l > "/tmp/cron.`date +%F_%H%M%S`"
	sudo mv "/tmp/cron.`date +%F_%H%M%S`" "$mudpi_dir/backups/cron.`date +%F_%H%M%S`"
	sudo ln -sf "$mudpi_dir/backups/cron.`date +%F_%H%M%S`" "$mudpi_dir/backups/cron"
	sudo crontab -l > "/tmp/cron_root.`date +%F_%H%M%S`"
	sudo mv "/tmp/cron_root.`date +%F_%H%M%S`" "$mudpi_dir/backups/cron.`date +%F_%H%M%S`"
	sudo ln -sf "$mudpi_dir/backups/cron_root.`date +%F_%H%M%S`" "$mudpi_dir/backups/cron_root"
}

function installDefaultConfigs() {
	log_info "Moving over default configurations..."
	sudo cp $mudpi_dir/installer/configs/supervisor_mudpi.conf /etc/supervisor/conf.d/mudpi.conf || log_error "Unable to install supervisor job"
	sudo cp $mudpi_dir/installer/scripts/update_mudpi.sh /usr/bin/update_mudpi || log_error "Unable to install update_mudpi script file"
	sudo chmod +x /usr/bin/update_mudpi || log_error "Unable to assign permissions for /usr/bin/update_mudpi"

	if [ "$ui_option" == 1 ]; then
		sudo rm /etc/nginx/sites-enabled/default
		sudo rm /etc/nginx/sites-available/default

		sudo cp $webroot_dir/mudpi/configs/mudpi_ui.conf /etc/nginx/sites-available/mudpi_ui.conf || log_error "Unable to install ui nginx config"
		sudo ln -sf /etc/nginx/sites-available/mudpi_ui.conf /etc/nginx/sites-enabled

		if [ -f /etc/nginx/sites-available/assistant_redirect.conf ]; then
			log_info "Detected assistant redirect config. Removing assistant_redirect.conf"
			sudo rm /etc/nginx/sites-enabled/assistant_redirect.conf
			sudo rm /etc/nginx/sites-available/assistant_redirect.conf
		fi
	fi

	if [ "$assistant_option" == 1 ]; then
		sudo cp $webroot_dir/mudpi_assistant/configs/mudpi_assistant.conf /etc/nginx/sites-available/mudpi_assistant.conf || log_error "Unable to install mudpi_assistant nginx config"
		sudo ln -sf /etc/nginx/sites-available/mudpi_assistant.conf /etc/nginx/sites-enabled
		if [ "$ui_option" == 0 ]; then
			sudo cp $mudpi_dir/installer/configs/assistant_redirect.conf /etc/nginx/sites-available/assistant_redirect.conf || log_error "Unable to install assistant_redirect nginx config"
			sudo ln -sf /etc/nginx/sites-available/assistant_redirect.conf /etc/nginx/sites-enabled
		fi
	fi

	if [ "$nginx_option" == 1 ]; then
		echo "Installing MudPi Web Dashboard..."
		echo "Visit 'mudpi.home' or the assigned pi IP"
		sudo service nginx restart || log_error "Unable to restart nginx (check the configs)"
	fi

	sudo systemctl daemon-reload



	if [ "$ap_mode_option" == 1 ]; then
		if [ -f /etc/default/hostapd ]; then
			sudo mv /etc/default/hostapd /tmp/default_hostapd.old || log_error "Unable to remove old /etc/default/hostapd file"
		fi
		sudo cp $mudpi_dir/installer/configs/default_hostapd /etc/default/hostapd || log_error "Unable to move hostapd defaults file"
		sudo cp $mudpi_dir/installer/configs/hostapd.conf /etc/hostapd/hostapd.conf || log_error "Unable to move hostapd configuration file"
		sudo cp $mudpi_dir/installer/configs/dnsmasq.conf /etc/dnsmasq.conf || log_error "Unable to move dnsmasq configuration file"
		sudo cp $mudpi_dir/installer/configs/dhcpcd.conf /etc/dhcpcd.conf || log_error "Unable to move dhcpcd configuration file"


		sudo cp $mudpi_dir/installer/scripts/stop_hotspot.sh /usr/bin/stop_hotspot || log_error "Unable to install stop_hotspot script file"
		sudo chmod +x /usr/bin/stop_hotspot || log_error "Unable to assign permissions for /usr/bin/stop_hostspot"
		sudo cp $mudpi_dir/installer/scripts/start_hotspot.sh /usr/bin/start_hotspot || log_error "Unable to install start_hotspot script file"
		sudo chmod +x /usr/bin/start_hotspot || log_error "Unable to assign permissions for /usr/bin/start_hostspot"

		# enable hotspot helper service
		log_info "Auto AP Mode will auto start the Access Point when Wifi is not connected."
		echo -n "Enable Auto AP Mode control service (Recommended)? [Y/n]: "
		if [ "$force_yes" == 0 ]; then
			read answer < /dev/tty
			if [ "$answer" != "${answer#[Nn]}" ]; then
				echo -e
			else
				enableAutoAPMode
			fi
		else
			echo -e
			enableAutoAPMode
		fi
	fi
}

function updateHostname() {

	log_info "Checking hostname file...."

	# Check if file needs patching
	if [ $(sudo grep "raspberrypi" /etc/hostname) ]
	then
		sudo sed -i "s/raspberrypi/mudpi/g" /etc/hostname
		log_info "Updating hostname file..."
	else
		log_info "Hostname already updated!"
	fi
}


function updateHostsFile() {

	log_info "Checking hosts file...."

	# Set commands array
	newhosts=(
		'192.168.2.1 mudpi mudpi.local mudpi.home #MUDPI-apmode'
		'10.45.12.1	clients3.google.com #MUDPI-captiveportal'
		'10.45.12.1	clients.l.google.com #MUDPI-captiveportal'
		'10.45.12.1	connectivitycheck.android.com #MUDPI-captiveportal'
		'10.45.12.1	connectivitycheck.gstatic.com #MUDPI-captiveportal'
		'10.45.12.1	play.googleapis.com #MUDPI-captiveportal'
	)

	# Check if file needs patching
	if [ $(sudo grep -c "#MUDPI" /etc/hosts) -ne ${#newhosts[@]} ]
	then
		# Sudoers file has incorrect number of commands. Wiping them out.
		log_info "Cleaning hosts file..."
		sudo sed -i "s/raspberrypi/mudpi/g" /etc/hosts
		sudo sed -i "/#MUDPI/d" /etc/hosts
		log_info "Updating hosts file..."
		# patch /etc/sudoers file
		for hostline in "${newhosts[@]}"
		do
			sudo echo "$hostline" >> /etc/hosts
		done
	else
		log_info "Hosts file already updated!"
	fi
}

function updateSudoersFile() {

	log_info "Checking sudoers file...."

	commands=(
		'/sbin/shutdown -h now'
		'/sbin/reboot'
		'/sbin/ifdown'
		'/sbin/ifup'
		'/sbin/dhclient'
		'/sbin/dhclient wlan[0-9]'
		'/bin/cat /etc/wpa_supplicant/wpa_supplicant.conf'
		'/bin/cat /etc/wpa_supplicant/wpa_supplicant-wlan[0-9].conf'
		'/bin/cp /tmp/wpa_supplicant.tmp /etc/wpa_supplicant/wpa_supplicant.conf'
		'/bin/cp /tmp/wpa_supplicant.tmp /etc/wpa_supplicant/wpa_supplicant-wlan[0-9].conf'
		'/bin/cp /tmp/wpa_supplicant.tmp /etc/mudpi/tmp/wpa_supplicant.conf'
		'/bin/rm /tmp/wpa_supplicant.tmp'
		'/bin/rm -r /tmp/mudpi_core'
		'/sbin/wpa_cli -i wlan[0-9] scan_results'
		'/sbin/wpa_cli -i wlan[0-9] scan'
		'/sbin/wpa_cli -i wlan[0-9] reconfigure'
		'/sbin/wpa_cli -i wlan[0-9] select_network'
		'/sbin/iwconfig wlan[0-9]'
		'/bin/cp /tmp/hostapddata /etc/hostapd/hostapd.conf'
		'/bin/systemctl start hostapd.service'
		'/bin/systemctl stop hostapd.service'
		'/bin/systemctl enable hostapd.service'
		'/bin/systemctl disable hostapd.service'
		'/bin/systemctl start dnsmasq.service'
		'/bin/systemctl enable dnsmasq.service'
		'/bin/systemctl disable dnsmasq.service'
		'/bin/systemctl stop dnsmasq.service'
		'/bin/cp /tmp/dnsmasqdata /etc/dnsmasq.conf'
		'/bin/cp /tmp/dhcpddata /etc/dhcpcd.conf'
		'/bin/cp /etc/mudpi/networking/dhcpcd.conf /etc/dhcpcd.conf'
		'/sbin/ip link set wlan[0-9] down'
		'/sbin/ip link set wlan[0-9] up'
		'/sbin/ip -s a f label wlan[0-9]'
		'/sbin/iw dev wlan[0-9] scan ap-force'
		'/sbin/iwgetid wlan[0-9] -r'
		'/etc/mudpi/scripts'
		'/etc/mudpi/scripts/update_mudpi.sh'
		'/usr/bin/auto_hotspot'
		'/usr/bin/start_hotspot'
		'/usr/bin/stop_hotspot'
		'/usr/bin/update_mudpi'
	)

	# Check if sudoers needs patching
	if [ $(sudo grep -c $mudpi_user /etc/sudoers) -ne ${#commands[@]} ]
	then
		# Sudoers file has incorrect number of commands. Wiping them out.
		log_info "Cleaning sudoers file..."
		sudo sed -i "/$mudpi_user/d" /etc/sudoers
		log_info "Updating sudoers file..."
		# patch /etc/sudoers file
		for cmd in "${commands[@]}"
		do
			sudo bash -c "echo \"$mudpi_user ALL=(ALL) NOPASSWD:${cmd}\" | (EDITOR=\"tee -a\" visudo)" \ || log_error "Unable to update /etc/sudoers"
			IFS=$'\n'
		done
	else
		log_info "Sudoers file already updated!"
	fi

	# Add symlink to prevent wpa_cli commands from breaking with multiple wlan interfaces
	log_info "Symlinked wpa_supplicant hooks for multiple wlan interfaces"
	if [ ! -f /usr/share/dhcpcd/hooks/10-wpa_supplicant ]; then
		sudo ln -s /usr/share/dhcpcd/hooks/10-wpa_supplicant /etc/dhcp/dhclient-enter-hooks.d/
	fi

}

function enableAutoAPMode() {
	log_info "Enabling Auto AP Mode Service"
	echo "Disable by commenting out the lines in sudo crontab -e with a '#'"
	sudo cp $mudpi_dir/installer/scripts/auto_hotspot.sh /usr/bin/auto_hotspot || log_error "Unable to install auto_hotspot script file"
	sudo chmod +x /usr/bin/auto_hotspot || log_error "Unable to assign permissions for /usr/bin/auto_hostspot"
	sudo crontab $mudpi_dir/installer/configs/cron.txt || log_error "Failed to enable auto_hotspot cronjob"
}

function displaySuccess() {
	echo -e "${green}MudPi installed successfully!"
	echo "--"
	echo -e "${maroon}Add mudpi.conf to /etc/mudpi/core before rebooting"
	echo "--"
	echo "It is recommended to reboot the system now. 'sudo reboot'"
	if [ "$force_yes" == 1 ]; then
		sudo reboot || log_error "Unable to reboot"
	fi
}

function installMudpi() {
	displayWelcome
	installationSetup
	askNginxInstall
	askUIInstall
	askAssistantInstall
	askAPModeInstall
	EnableSSH
	installDependencies
	makeDirectories
	backupConfigs
	downloadInstallerFiles
	downloadMudpiCoreFiles
	if [ "$nginx_option" == 1 ]; then
		installNginx
	fi
	if [ "$ui_option" == 1 ]; then
		downloadUIFiles
	fi
	if [ "$assistant_option" == 1 ]; then
		downloadAssistantFiles
	fi
	if [ "$ap_mode_option" == 1 ]; then
		installAPMode
	fi
	installDefaultConfigs
	sudo usermod -a -G www-data pi
	sudo usermod -a -G video,gpio,spi,i2c www-data
	sudo chmod 775 /etc/mudpi/logs
	updateHostsFile
	updateSudoersFile
	updateHostname
	displaySuccess
}

installMudpi
