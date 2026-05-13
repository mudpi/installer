#!/bin/bash

# This bash script is used to install MudPi
# author: Eric Davisson @theDavisson <hi@ericdavisson.com>
# license: MIT

set -euo pipefail

repo="mudpi/mudpi-core"
repo_installer="mudpi/installer"
repo_assistant="mudpi/assistant"
repo_ui="mudpi/ui"
branch="master"
mudpi_dir="/home/mudpi"
webroot_dir="/var/www/html"
mudpi_user="mudpi"
web_user="www-data"
hostname="mudpi"
venv_dir="${mudpi_dir}/venv"
maroon='\033[0;35m'
green='\033[1;32m'
reset='\033[0m'
user=$(whoami)
ip=$(hostname -I)

VERSION=$(curl -s "https://api.github.com/repos/${repo}/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")')
os_version=$(sed 's/\..*//' /etc/debian_version 2>/dev/null || echo "0")
arch=$(dpkg --print-architecture 2>/dev/null || uname -m)

force_yes=0
apt_option=""
nginx_option=0
assistant_option=0
ui_option=0
ap_mode_option=0
zigbee2mqtt_option=0

usage=$(cat << 'EOF'
Usage: install.sh [OPTION]\n
-y, --yes, --force-yes\n\tForces "yes" answer to all prompts
-b, --branch <name>\n\tOverrides the default git branch (master)
-h, --help\n\tOutputs usage notes and exits
-v, --version\n\tOutputs release info and exits\n
EOF
)

while :; do
	case "${1:-}" in
		-y|--yes|--force-yes)
		force_yes=1
		apt_option="-y"
		;;
		-b|--branch)
		branch="${2:-master}"
		shift
		;;
		-h|--help)
		printf "$usage"
		exit 0
		;;
		-v|--version)
		printf "MudPi v${VERSION} - Smart Automation for the Garden & Home\n"
		exit 0
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
	echo -e '███╗   ███╗██╗   ██╗██████╗ ██████╗ ██╗'
	echo -e '████╗ ████║██║   ██║██╔══██╗██╔══██╗██║'
	echo -e '██╔████╔██║██║   ██║██║  ██║██████╔╝██║'
	echo -e '██║╚██╔╝██║██║   ██║██║  ██║██╔═══╝ ██║'
	echo -e '██║ ╚═╝ ██║╚██████╔╝██████╔╝██║     ██║'
	echo -e '╚═╝     ╚═╝ ╚═════╝ ╚═════╝ ╚═╝     ╚═╝'
	echo -e "Version: $VERSION"
	echo -e '_________________________________________________'
	echo -e "${maroon}The next few steps will guide you through the installation process."
	echo -e "${reset}"
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

# Determine Raspberry Pi OS version (based on Debian)
version_msg="Unknown Raspberry Pi OS Version"
php_version=""
php_package=""

if [ "$os_version" -ge "13" ] 2>/dev/null; then
	version_msg="Raspberry Pi OS (Trixie / Debian 13)"
	php_version="8.4"
elif [ "$os_version" -eq "12" ] 2>/dev/null; then
	version_msg="Raspberry Pi OS (Bookworm / Debian 12)"
	php_version="8.2"
else
	echo "Raspberry Pi OS based on Debian ${os_version} is unsupported."
	echo "This installer requires Bookworm (Debian 12) or newer."
	echo "Please flash a fresh Raspberry Pi OS image from https://www.raspberrypi.com/software/"
	exit 1
fi

php_package="php${php_version} php${php_version}-cgi php${php_version}-common php${php_version}-cli php${php_version}-fpm php${php_version}-mbstring php${php_version}-mysql php${php_version}-opcache php${php_version}-curl php${php_version}-gd php${php_version}-zip php${php_version}-xml php${php_version}-redis php${php_version}-dev"

# Detect system architecture
arch_msg="Unknown architecture"
if [ "$arch" = "arm64" ] || [ "$arch" = "aarch64" ]; then
	arch_msg="ARM64 (aarch64)"
elif [ "$arch" = "armhf" ] || [ "$arch" = "armv7l" ]; then
	arch_msg="ARM32 (armhf)"
else
	log_warning "Unexpected architecture: ${arch}. Proceeding anyway."
	arch_msg="${arch}"
fi

function installationSetup()
{
	log_info "Confirm Settings"
	echo "Detected ${version_msg}"
	echo "Architecture: ${arch_msg}"
	echo "MudPi install directory: ${mudpi_dir}"
	echo -n "Use ${webroot_dir} for web root? [Y/n]: "
	if [ "$force_yes" == 0 ]; then
		read answer < /dev/tty
		if [ "$answer" != "${answer#[Nn]}" ]; then
			read -e -p "Enter alternate directory: " -i "/var/www/html" webroot_dir < /dev/tty
		fi
	else
		echo -e
	fi
	echo "Web directory root: ${webroot_dir}"

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

function setupUser() {
	if ! id "$mudpi_user" >/dev/null 2>&1; then
		echo "Creating user ${mudpi_user} with password: mudpiapp"
		sudo adduser "$mudpi_user" --gecos "MudPi,1,1,1" --disabled-password
		echo "$mudpi_user:mudpiapp" | sudo chpasswd

		local groups="gpio,i2c,spi,audio,video,www-data,sudo,dialout"
		if id "pi" >/dev/null 2>&1; then
			groups="pi,${groups}"
		fi
		sudo usermod -a -G "$groups" "$mudpi_user"
	else
		echo "User $mudpi_user already exists"
	fi

	sudo usermod -a -G www-data "$user" 2>/dev/null || true
	sudo usermod -a -G video,gpio,spi,i2c www-data 2>/dev/null || true
}

function makeDirectories()
{
	echo "Creating directories..."
	if [ ! -d "$mudpi_dir" ]; then
		echo "$mudpi_dir directory doesn't exist. Creating..."
		sudo mkdir -p "$mudpi_dir"
	else
		log_warning "$mudpi_dir directory already exists."
	fi
	sudo mkdir -p "${mudpi_dir}"/{backups,networking/defaults,tmp,scripts,installer,img,video,logs}
	sudo touch "${mudpi_dir}/logs/output.log"
	sudo touch "${mudpi_dir}/logs/error.log"

	sudo chown -R "${mudpi_user}:${mudpi_user}" "$mudpi_dir" || log_error "Unable to change file ownership for '$mudpi_dir'"
	sudo chmod 775 "$mudpi_dir/logs"
}

function installDependencies()
{
	log_info "Installing required packages"
	sudo apt-get update

	sudo apt-get install $apt_option software-properties-common apt-transport-https \
		lsb-release ca-certificates curl wget gnupg || log_error "Unable to install base packages"

	sudo apt-get update
	sudo apt-get $apt_option dist-upgrade
	sudo apt-get $apt_option upgrade

	local base_packages="python3-pip python3-venv python3-dev supervisor git tmux curl wget zip unzip htop build-essential"
	local lib_packages="libffi-dev libbz2-dev liblzma-dev libsqlite3-dev libncurses5-dev libgdbm-dev zlib1g-dev libreadline-dev libssl-dev tk-dev libncursesw5-dev libc6-dev openssl"
	local media_packages="ffmpeg libatlas-base-dev libgpiod2"

	if ! sudo DEBIAN_FRONTEND=noninteractive apt-get install $apt_option --fix-missing \
		$php_package $base_packages $lib_packages $media_packages; then
		log_warning "Failed to install dependencies. Trying to fix and reinstall..."
		sudo apt-get install --fix-missing
		sudo DEBIAN_FRONTEND=noninteractive apt-get install $apt_option --fix-missing \
			$php_package $base_packages $lib_packages $media_packages || log_error "Unable to install dependencies"
	else
		echo "Main dependencies successfully installed"
	fi

	log_info "Setting up Python virtual environment at ${venv_dir}"
	sudo -u "$mudpi_user" python3 -m venv --system-site-packages "$venv_dir" || {
		sudo python3 -m venv --system-site-packages "$venv_dir"
		sudo chown -R "${mudpi_user}:${mudpi_user}" "$venv_dir"
	}
	sudo -u "$mudpi_user" "${venv_dir}/bin/pip" install --upgrade pip setuptools wheel

	log_info "Installing GPIO libraries"
	sudo -u "$mudpi_user" "${venv_dir}/bin/pip" install rpi-lgpio gpiozero || log_warning "Unable to install GPIO packages (may not be on a Raspberry Pi)"

	if [ -f "/usr/local/bin/composer" ] || command -v composer &>/dev/null; then
		log_info "Composer already installed!"
	else
		log_info "Installing Composer..."
		local EXPECTED_CHECKSUM="$(php -r 'copy("https://composer.github.io/installer.sig", "php://stdout");')"
		php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
		local ACTUAL_CHECKSUM="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"
		if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]; then
			rm -f composer-setup.php
			log_error "Composer installer checksum verification failed"
		fi
		sudo php composer-setup.php --install-dir=/usr/local/bin --filename=composer || log_error "Problem installing Composer"
		rm -f composer-setup.php
	fi

	log_info "Installing Redis"
	sudo apt-get install $apt_option redis-server || log_error "Unable to install Redis"
	sudo sed -i 's/supervised no/supervised systemd/g' /etc/redis/redis.conf 2>/dev/null || true
	sudo systemctl restart redis || log_error "Unable to restart Redis"
	sudo systemctl enable redis-server || true

	log_info "Installing MQTT Broker (Mosquitto)"
	sudo apt-get install $apt_option mosquitto mosquitto-clients || log_error "Unable to install MQTT Broker"
	sudo systemctl enable mosquitto.service || log_error "Unable to enable MQTT"
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
	if systemctl is-active --quiet apache2 2>/dev/null; then
		sudo systemctl stop apache2
		sudo systemctl disable apache2
	fi
	sudo apt-get remove $apt_option apache2 2>/dev/null || true
	sudo apt-get install $apt_option nginx mariadb-server mariadb-client
}

function askAssistantInstall() {
	echo "MudPi Assistant is a web interface for first time configurations"
	echo -n "Install mudpi-assistant and enable web configs? [y/N]: "
	if [ "$force_yes" == 0 ]; then
		read answer < /dev/tty
		if [ "$answer" != "${answer#[Yy]}" ]; then
			assistant_option=1
		else
			echo -e
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

function askAPModeInstall() {
	echo -n "Configure Wi-Fi Access Point (hotspot) mode? [y/N]: "
	if [ "$force_yes" == 0 ]; then
		read answer < /dev/tty
		if [ "$answer" != "${answer#[Yy]}" ]; then
			ap_mode_option=1
		else
			echo -e
		fi
	else
		ap_mode_option=1
	fi
}

function askZigbee2MQTTInstall() {
	echo "Zigbee2MQTT bridges Zigbee devices to MQTT (requires a Zigbee USB adapter)"
	echo -n "Install Zigbee2MQTT? [y/N]: "
	if [ "$force_yes" == 0 ]; then
		read answer < /dev/tty
		if [ "$answer" != "${answer#[Yy]}" ]; then
			zigbee2mqtt_option=1
		else
			echo -e
		fi
	else
		zigbee2mqtt_option=1
	fi
}

function installZigbee2MQTT() {
	log_info "Installing Zigbee2MQTT"

	if command -v node &>/dev/null; then
		local node_major
		node_major=$(node --version | sed 's/v\([0-9]*\).*/\1/')
		if [ "$node_major" -ge 20 ]; then
			log_info "Node.js $(node --version) already installed"
		else
			log_warning "Node.js $(node --version) is too old, installing LTS..."
			sudo curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
			sudo apt-get install $apt_option nodejs || log_error "Unable to install Node.js"
		fi
	else
		log_info "Installing Node.js LTS..."
		sudo curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
		sudo apt-get install $apt_option nodejs || log_error "Unable to install Node.js"
	fi

	sudo apt-get install $apt_option make g++ gcc libsystemd-dev || log_error "Unable to install Zigbee2MQTT build dependencies"

	sudo corepack enable || log_warning "corepack enable failed, pnpm may need manual install"

	log_info "Node.js $(node --version) ready"

	local z2m_dir="/opt/zigbee2mqtt"

	if [ -d "$z2m_dir" ]; then
		log_warning "Existing Zigbee2MQTT installation found at ${z2m_dir}"
		echo -n "Back up and reinstall? [Y/n]: "
		if [ "$force_yes" == 0 ]; then
			read answer < /dev/tty
			if [ "$answer" != "${answer#[Nn]}" ]; then
				log_info "Keeping existing Zigbee2MQTT installation"
				return 0
			fi
		fi
		sudo systemctl stop zigbee2mqtt 2>/dev/null || true
		sudo mv "$z2m_dir" "${z2m_dir}.$(date +%F_%H%M%S)"
	fi

	sudo mkdir -p "$z2m_dir"
	sudo chown -R "${mudpi_user}:" "$z2m_dir"

	log_info "Cloning Zigbee2MQTT repository..."
	sudo -u "$mudpi_user" git clone --depth 1 https://github.com/Koenkk/zigbee2mqtt.git "$z2m_dir" || log_error "Unable to clone Zigbee2MQTT"

	log_info "Installing Zigbee2MQTT dependencies (this may take a few minutes)..."
	cd "$z2m_dir"
	sudo -u "$mudpi_user" pnpm install --frozen-lockfile || log_error "Unable to install Zigbee2MQTT dependencies"
	cd - > /dev/null

	log_info "Installing Zigbee2MQTT systemd service"
	sudo cp "$mudpi_dir/installer/configs/zigbee2mqtt.service" /etc/systemd/system/zigbee2mqtt.service || log_error "Unable to install Zigbee2MQTT service file"
	sudo sed -i "s/User=mudpi/User=${mudpi_user}/g" /etc/systemd/system/zigbee2mqtt.service
	sudo systemctl daemon-reload
	sudo systemctl enable zigbee2mqtt

	log_info "Zigbee2MQTT installed successfully!"
	echo ""
	echo "  Zigbee2MQTT is installed but NOT started yet."
	echo "  Plug in your Zigbee adapter, then start with:"
	echo "    sudo systemctl start zigbee2mqtt"
	echo ""
	echo "  On first start, open the onboarding UI at:"
	echo "    http://${ip}:8080"
	echo ""
	echo "  Logs: sudo journalctl -u zigbee2mqtt -f"
	echo "  Update: cd /opt/zigbee2mqtt && ./update.sh"
	echo ""
}

function installAPMode() {
	log_info "Setting up Access Point support via NetworkManager"

	if ! command -v nmcli &>/dev/null; then
		log_error "NetworkManager (nmcli) is required but not found. Cannot configure AP mode."
	fi

	local ap_ssid="MudPi"
	local ap_password="mudpi1234"
	local ap_iface="wlan0"

	echo -n "Access Point SSID [${ap_ssid}]: "
	if [ "$force_yes" == 0 ]; then
		read answer < /dev/tty
		if [ -n "$answer" ]; then
			ap_ssid="$answer"
		fi
	else
		echo -e
	fi

	echo -n "Access Point password [${ap_password}]: "
	if [ "$force_yes" == 0 ]; then
		read answer < /dev/tty
		if [ -n "$answer" ]; then
			ap_password="$answer"
		fi
	else
		echo -e
	fi

	sudo nmcli connection delete mudpi-hotspot 2>/dev/null || true

	sudo nmcli connection add type wifi ifname "$ap_iface" con-name mudpi-hotspot \
		autoconnect no ssid "$ap_ssid" \
		wifi.mode ap wifi.band bg wifi.channel 7 \
		ipv4.addresses 192.168.4.1/24 ipv4.method shared \
		wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$ap_password" || log_error "Failed to create hotspot connection profile"

	log_info "Hotspot profile 'mudpi-hotspot' created (SSID: ${ap_ssid})"
	echo "Start manually: sudo nmcli connection up mudpi-hotspot"
	echo "Stop:           sudo nmcli connection down mudpi-hotspot"

	log_info "Auto AP Mode will start the hotspot when no Wi-Fi network is available."
	echo -n "Enable Auto AP Mode service? [Y/n]: "
	if [ "$force_yes" == 0 ]; then
		read answer < /dev/tty
		if [ "$answer" != "${answer#[Nn]}" ]; then
			echo -e
		else
			enableAutoAPMode
		fi
	else
		enableAutoAPMode
	fi
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
		sudo mkdir -p "$mudpi_dir/installer" || log_error "Unable to create mudpi installer directory"
	fi

	if [ -d "$mudpi_dir/installer/.git" ]; then
		sudo mv "$mudpi_dir/installer" "$mudpi_dir/installer.$(date +%F_%H%M%S)" || log_error "Unable to back up old installer directory"
	fi

	log_info "Cloning latest installer files from GitHub"
	git clone --depth 1 "https://github.com/${repo_installer}" /tmp/mudpi_installer || log_error "Unable to download installer files from GitHub"
	sudo mv /tmp/mudpi_installer "$mudpi_dir/installer" || log_error "Unable to move MudPi installer to $mudpi_dir/installer"
	sudo chown -R "$mudpi_user:$mudpi_user" "$mudpi_dir" || log_error "Unable to set permissions in '$mudpi_dir/installer'"
}

function downloadMudpiCoreFiles()
{
	if [ ! -d "$webroot_dir" ]; then
		sudo mkdir -p "$webroot_dir" || log_error "Unable to create new webroot directory"
	fi

	if [ -d "$mudpi_dir/core" ]; then
		sudo mv "$mudpi_dir/core" "$mudpi_dir/core.$(date +%F_%H%M%S)" || log_error "Unable to back up old core directory"
	fi

	log_info "Cloning latest core files from GitHub"
	git clone --depth 1 -b "$branch" "https://github.com/${repo}" /tmp/mudpi_core || log_error "Unable to download core files from GitHub"
	sudo mv /tmp/mudpi_core "$mudpi_dir/core" || log_error "Unable to move MudPi core to $mudpi_dir"
	sudo chown -R "$mudpi_user:$mudpi_user" "$mudpi_dir" || log_error "Unable to set permissions in '$mudpi_dir'"
	sudo chmod g+w "$mudpi_dir/core" || log_error "Unable to set write permissions in $mudpi_dir"

	log_info "Installing MudPi core Python package into virtual environment"
	if [ -f "$mudpi_dir/core/requirements.txt" ]; then
		sudo -u "$mudpi_user" "${venv_dir}/bin/pip" install -r "$mudpi_dir/core/requirements.txt"
	fi
	sudo -u "$mudpi_user" "${venv_dir}/bin/pip" install "$mudpi_dir/core" || log_error "Problem installing MudPi core Python package"
}

function downloadAssistantFiles()
{
	if [ ! -d "$webroot_dir" ]; then
		sudo mkdir -p "$webroot_dir" || log_error "Unable to create new webroot directory"
	fi

	if [ -d "$webroot_dir/mudpi_assistant" ]; then
		sudo mv "${webroot_dir}/mudpi_assistant" "${webroot_dir}/mudpi_assistant.$(date +%F_%H%M%S)" || log_error "Unable to back up old assistant webroot directory"
	fi

	log_info "Cloning latest assistant files from GitHub"
	git clone --depth 1 "https://github.com/${repo_assistant}" /tmp/mudpi_assistant || log_error "Unable to download assistant files from GitHub"
	sudo mv /tmp/mudpi_assistant "$webroot_dir" || log_error "Unable to move MudPi assistant to web root"
	composer update -d "${webroot_dir}/mudpi_assistant" || log_error "Unable to run composer install"
	sudo chown -R "$mudpi_user:$mudpi_user" "${webroot_dir}/mudpi_assistant" || log_error "Unable to set permissions in '$webroot_dir'"
	sudo find "${webroot_dir}/mudpi_assistant" -type d -exec chmod 755 {} + || log_error "Unable to set permissions in '$webroot_dir'"
	sudo find "${webroot_dir}/mudpi_assistant" -type f -exec chmod 644 {} + || log_error "Unable to set permissions in '$webroot_dir'"
}

function downloadUIFiles()
{
	if [ ! -d "$webroot_dir" ]; then
		sudo mkdir -p "$webroot_dir" || log_error "Unable to create new webroot directory"
	fi

	if [ -d "$webroot_dir/mudpi" ]; then
		sudo mv "${webroot_dir}/mudpi" "${webroot_dir}/mudpi.$(date +%F_%H%M%S)" || log_error "Unable to back up old UI webroot directory"
	fi

	log_info "Cloning latest UI files from GitHub"
	git clone --depth 1 "https://github.com/${repo_ui}" /tmp/mudpi || log_error "Unable to download UI files from GitHub"
	sudo mv /tmp/mudpi "$webroot_dir" || log_error "Unable to move MudPi UI to web root"
	sleep 1
	composer update -d "${webroot_dir}/mudpi" || log_error "Unable to run composer install"
	sudo chown -R "$mudpi_user:$mudpi_user" "${webroot_dir}/mudpi" || log_error "Unable to set permissions in '$webroot_dir'"
	sudo find "${webroot_dir}/mudpi" -type d -exec chmod 755 {} + || log_error "Unable to set permissions in '$webroot_dir'"
	sudo find "${webroot_dir}/mudpi" -type f -exec chmod 644 {} + || log_error "Unable to set permissions in '$webroot_dir'"
}

function backupConfigs()
{
	echo "Making backups of current configs..."
	local ts
	ts="$(date +%F_%H%M%S)"

	if [ -f /etc/hostapd/hostapd.conf ]; then
		sudo cp /etc/hostapd/hostapd.conf "$mudpi_dir/backups/hostapd.conf.${ts}"
		sudo ln -sf "$mudpi_dir/backups/hostapd.conf.${ts}" "$mudpi_dir/backups/hostapd.conf"
	fi

	if [ -f /etc/dnsmasq.conf ]; then
		sudo cp /etc/dnsmasq.conf "$mudpi_dir/backups/dnsmasq.conf.${ts}"
		sudo ln -sf "$mudpi_dir/backups/dnsmasq.conf.${ts}" "$mudpi_dir/backups/dnsmasq.conf"
	fi

	if [ -f /etc/rc.local ]; then
		sudo cp /etc/rc.local "$mudpi_dir/backups/rc.local.${ts}"
		sudo ln -sf "$mudpi_dir/backups/rc.local.${ts}" "$mudpi_dir/backups/rc.local"
	fi

	if [ -f "$mudpi_dir/core/mudpi.config" ]; then
		sudo cp "$mudpi_dir/core/mudpi.config" "$mudpi_dir/backups/mudpi.config.${ts}"
		sudo ln -sf "$mudpi_dir/backups/mudpi.config.${ts}" "$mudpi_dir/backups/mudpi.config"
	fi

	if [ -f /etc/sudoers ]; then
		sudo cp /etc/sudoers "$mudpi_dir/backups/sudoers.${ts}"
		sudo ln -sf "$mudpi_dir/backups/sudoers.${ts}" "$mudpi_dir/backups/sudoers"
	fi

	if [ -f /etc/redis/redis.conf ]; then
		sudo cp /etc/redis/redis.conf "$mudpi_dir/backups/redis.conf.${ts}"
		sudo ln -sf "$mudpi_dir/backups/redis.conf.${ts}" "$mudpi_dir/backups/redis.conf"
	fi

	if [ -d /etc/nginx ]; then
		sudo tar -czf "$mudpi_dir/backups/nginx.${ts}.tar.gz" "/etc/nginx/sites-available" 2>/dev/null || true
	fi

	if [ -d /etc/NetworkManager/system-connections ]; then
		sudo tar -czf "$mudpi_dir/backups/networkmanager.${ts}.tar.gz" "/etc/NetworkManager/system-connections" 2>/dev/null || true
	fi

	if [ -f /etc/hosts ]; then
		sudo cp /etc/hosts "$mudpi_dir/backups/hosts.${ts}"
		sudo ln -sf "$mudpi_dir/backups/hosts.${ts}" "$mudpi_dir/backups/hosts"
	fi

	sudo crontab -u "$user" -l > "/tmp/cron.${ts}" 2>/dev/null || true
	if [ -s "/tmp/cron.${ts}" ]; then
		sudo mv "/tmp/cron.${ts}" "$mudpi_dir/backups/cron.${ts}"
		sudo ln -sf "$mudpi_dir/backups/cron.${ts}" "$mudpi_dir/backups/cron"
	else
		rm -f "/tmp/cron.${ts}"
	fi

	sudo crontab -l > "/tmp/cron_root.${ts}" 2>/dev/null || true
	if [ -s "/tmp/cron_root.${ts}" ]; then
		sudo mv "/tmp/cron_root.${ts}" "$mudpi_dir/backups/cron_root.${ts}"
		sudo ln -sf "$mudpi_dir/backups/cron_root.${ts}" "$mudpi_dir/backups/cron_root"
	else
		rm -f "/tmp/cron_root.${ts}"
	fi
}

function installDefaultConfigs() {
	log_info "Moving over default configurations..."
	sudo cp "$mudpi_dir/installer/configs/supervisor_mudpi.conf" /etc/supervisor/conf.d/mudpi.conf || log_error "Unable to install supervisor job"

	# Update supervisor config to use the virtualenv python
	sudo sed -i "s|command=python3|command=${venv_dir}/bin/python3|g" /etc/supervisor/conf.d/mudpi.conf 2>/dev/null || true
	sudo sed -i "s|command=/usr/bin/python3|command=${venv_dir}/bin/python3|g" /etc/supervisor/conf.d/mudpi.conf 2>/dev/null || true

	sudo cp "$mudpi_dir/installer/scripts/update_mudpi.sh" /usr/bin/update_mudpi || log_error "Unable to install update_mudpi script file"
	sudo chmod +x /usr/bin/update_mudpi || log_error "Unable to assign permissions for /usr/bin/update_mudpi"

	if [ "$ui_option" == 1 ]; then
		sudo rm -f /etc/nginx/sites-enabled/default
		sudo rm -f /etc/nginx/sites-available/default

		sudo cp "$webroot_dir/mudpi/configs/mudpi_ui.conf" /etc/nginx/sites-available/mudpi_ui.conf || log_error "Unable to install UI nginx config"
		sudo ln -sf /etc/nginx/sites-available/mudpi_ui.conf /etc/nginx/sites-enabled

		if [ -f /etc/nginx/sites-available/assistant_redirect.conf ]; then
			log_info "Detected assistant redirect config. Removing assistant_redirect.conf"
			sudo rm -f /etc/nginx/sites-enabled/assistant_redirect.conf
			sudo rm -f /etc/nginx/sites-available/assistant_redirect.conf
		fi

		sudo sed -i "s|php7\.[0-9]-fpm|php${php_version}-fpm|g" /etc/nginx/sites-available/mudpi_ui.conf 2>/dev/null || true
	fi

	if [ "$assistant_option" == 1 ]; then
		sudo cp "$webroot_dir/mudpi_assistant/configs/mudpi_assistant.conf" /etc/nginx/sites-available/mudpi_assistant.conf || log_error "Unable to install mudpi_assistant nginx config"
		sudo ln -sf /etc/nginx/sites-available/mudpi_assistant.conf /etc/nginx/sites-enabled
		if [ "$ui_option" == 0 ]; then
			sudo cp "$mudpi_dir/installer/configs/assistant_redirect.conf" /etc/nginx/sites-available/assistant_redirect.conf || log_error "Unable to install assistant_redirect nginx config"
			sudo ln -sf /etc/nginx/sites-available/assistant_redirect.conf /etc/nginx/sites-enabled
		fi

		sudo sed -i "s|php7\.[0-9]-fpm|php${php_version}-fpm|g" /etc/nginx/sites-available/mudpi_assistant.conf 2>/dev/null || true
	fi

	if [ "$nginx_option" == 1 ]; then
		echo "Installing MudPi Web Dashboard..."
		echo "Visit 'mudpi.local' or the assigned Pi IP: $ip"
		sudo nginx -t || log_error "Nginx config test failed (check the configs)"
		sudo systemctl restart nginx || log_error "Unable to restart nginx"
	fi

	sudo systemctl daemon-reload
}

function updateHostname() {
	log_info "Checking hostname..."
	local current_hostname
	current_hostname=$(cat /etc/hostname | tr -d '[:space:]')
	if [ "$current_hostname" = "raspberrypi" ]; then
		sudo hostnamectl set-hostname "$hostname"
		log_info "Updated hostname to '${hostname}'"
	else
		log_info "Hostname already set to '${current_hostname}'"
	fi
}

function updateHostsFile() {
	log_info "Checking hosts file..."

	if sudo grep -q "raspberrypi" /etc/hosts; then
		sudo sed -i "s/raspberrypi/$hostname/g" /etc/hosts
		log_info "Updated hosts file: raspberrypi -> ${hostname}"
	fi

	if ! sudo grep -q "#MUDPI" /etc/hosts; then
		log_info "Adding MudPi entries to hosts file..."
		echo "# MudPi local hostname entries #MUDPI" | sudo tee -a /etc/hosts > /dev/null
		echo "127.0.1.1 ${hostname} ${hostname}.local ${hostname}.home #MUDPI" | sudo tee -a /etc/hosts > /dev/null
	else
		log_info "Hosts file already has MudPi entries"
	fi
}

function updateSudoersFile() {
	log_info "Checking sudoers file..."

	commands=(
		'/sbin/shutdown -h now'
		'/sbin/reboot'
		'/bin/systemctl start hostapd.service'
		'/bin/systemctl stop hostapd.service'
		'/bin/systemctl enable hostapd.service'
		'/bin/systemctl disable hostapd.service'
		'/usr/bin/nmcli *'
		'/bin/systemctl restart NetworkManager'
		'/bin/systemctl restart nginx'
		'/bin/systemctl restart supervisor'
		'/bin/systemctl restart mosquitto'
		'/bin/systemctl restart redis-server'
		'/home/mudpi/scripts/*'
		'/home/mudpi/installer/scripts/*'
		'/usr/bin/update_mudpi'
	)

	if [ "$(sudo grep -c "${web_user}.*NOPASSWD" /etc/sudoers)" -ne "${#commands[@]}" ]; then
		log_info "Updating sudoers file..."
		sudo sed -i "/${web_user}/d" /etc/sudoers
		for cmd in "${commands[@]}"; do
			echo "${web_user} ALL=(ALL) NOPASSWD:${cmd}" | sudo EDITOR="tee -a" visudo > /dev/null || log_error "Unable to update /etc/sudoers"
		done
	else
		log_info "Sudoers file already up to date"
	fi
}

function enableAutoAPMode() {
	log_info "Enabling Auto AP Mode Service"

	local auto_ap_script="/usr/bin/auto_hotspot"
	cat << 'APSCRIPT' | sudo tee "$auto_ap_script" > /dev/null
#!/bin/bash
# Auto AP Mode: starts hotspot if no known Wi-Fi network is in range
if nmcli -t -f TYPE,STATE connection show --active | grep -q "wifi:activated"; then
	exit 0
fi
if nmcli -t -f SSID device wifi list --rescan yes | grep -qf <(nmcli -t -f NAME connection show | grep -v mudpi-hotspot); then
	exit 0
fi
nmcli connection up mudpi-hotspot 2>/dev/null || true
APSCRIPT
	sudo chmod +x "$auto_ap_script"

	(sudo crontab -l 2>/dev/null | grep -v auto_hotspot; echo "*/5 * * * * /usr/bin/auto_hotspot") | sudo crontab - || log_error "Failed to enable auto_hotspot cron job"
	log_info "Auto AP Mode enabled (runs every 5 minutes)"
	echo "Disable by removing the cron entry: sudo crontab -e"
}

function displaySuccess() {
	echo -e "${green}"
	echo "============================================="
	echo "  MudPi installed successfully!"
	echo "============================================="
	echo -e "${reset}"
	echo "Python virtual environment: ${venv_dir}"
	echo "Activate it with: source ${venv_dir}/bin/activate"
	echo ""
	echo "It is recommended to reboot the system now."
	echo "Run: sudo reboot"
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
	askZigbee2MQTTInstall
	setupUser
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
	if [ "$zigbee2mqtt_option" == 1 ]; then
		installZigbee2MQTT
	fi
	installDefaultConfigs
	updateSudoersFile
	updateHostsFile
	updateHostname
	displaySuccess
}

installMudpi
