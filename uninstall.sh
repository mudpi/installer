#!/bin/bash
mudpi_dir="/etc/mudpi"
mudpi_user="www-data"
version=`sed 's/\..*//' /etc/debian_version`
webroot_dir="/var/www/html" 
user=$(whoami)

# Determine Raspbian version
version_msg="Unknown Raspbian Version"
if [ "$rasp_version" -eq "10" ]; then
	version_msg="Raspbian 10.0 (Buster)"
	php_package="php7.3-cgi"
elif [ "$rasp_version" -eq "9" ]; then
	version_msg="Raspbian 9.0 (Stretch)" 
	php_package="php7.2-cgi" # might be version 7.0 CHECK ME
elif [ "$rasp_version" -lt "9" ]; then
	echo "Raspbian ${rasp_version} is unsupported. Please upgrade."
	exit 1
fi

phpcgiconf=""
if [ "$php_package" = "php7.3-cgi" ]; then
	phpcgiconf="/etc/php/7.3/cgi/php.ini"
elif [ "$php_package" = "php7.2-cgi" ]; then
	phpcgiconf="/etc/php/7.2/cgi/php.ini"
fi

function log_info() {
	echo -e "\033[1;32mMudPi Uninstall: $*\033[m"
}

function log_error() {
	echo -e "\033[1;37;41mMudPi Uninstall Error: $*\033[m"
	exit 1
}

function confirm_uninstall() {
	log_info "The Following System Info was Detected"
	echo "Detected ${version_msg}" 
	echo "Install directory: ${mudpi_dir}"
	echo "Web directory: ${webroot_dir}"
	echo -n "Proceed with MudPi Uninstall? [y/N]: "
	read answer
	if [[ $answer != "y" ]]; then
		echo "Uninstall aborted."
		exit 0
	fi
}

function restore_backups() {
	if [ -d "$mudpi_dir/backups" ]; then
		if [ -f "$mudpi_dir/backups/interfaces" ]; then
			echo -n "Restore interfaces file from backup? [y/N]: "
			read answer
			if [[ $answer -eq 'y' ]]; then
				sudo cp "$mudpi_dir/backups/interfaces" /etc/network/interfaces
			fi
		fi
		if [ -f "$mudpi_dir/backups/hostapd.conf" ]; then
			echo -n "Restore hostapd configuration file from backup? [y/N]: "
			read answer
			if [[ $answer -eq 'y' ]]; then
				sudo cp "$mudpi_dir/backups/hostapd.conf" /etc/hostapd/hostapd.conf
			fi
		fi
		if [ -f "$mudpi_dir/backups/dnsmasq.conf" ]; then
			echo -n "Restore dnsmasq configuration file from backup? [y/N]: "
			read answer
			if [[ $answer -eq 'y' ]]; then
				sudo cp "$mudpi_dir/backups/dnsmasq.conf" /etc/dnsmasq.conf
			fi
		fi
		if [ -f "$mudpi_dir/backups/dhcpcd.conf" ]; then
			echo -n "Restore dhcpcd.conf file from backup? [y/N]: "
			read answer
			if [[ $answer -eq 'y' ]]; then
				sudo cp "$mudpi_dir/backups/dhcpcd.conf" /etc/dhcpcd.conf
			fi
		fi
		if [ -f "$mudpi_dir/backups/rc.local" ]; then
			echo -n "Restore rc.local file from backup? [y/N]: "
			read answer
			if [[ $answer -eq 'y' ]]; then
				sudo cp "$mudpi_dir/backups/rc.local" /etc/rc.local
			fi
		fi
	fi
	if [ -f "$mudpi_dir/backups/cron" ]; then
		echo -n "Restore cron file from backup? [y/N]: "
		read answer
		if [[ $answer -eq 'y' ]]; then
			sudo crontab -u "$user" "$mudpi_dir/backups/cron"
		fi
	fi
	if [ -f "$mudpi_dir/backups/cron_root" ]; then
		echo -n "Restore root cron file from backup? [y/N]: "
		read answer
		if [[ $answer -eq 'y' ]]; then
			sudo crontab "$mudpi_dir/backups/cron_root"
		fi
	fi
}

function remove_mudpi_directories() {
	log_info "Removing MudPi Directories..."
	if [ ! -d "$mudpi_dir" ]; then
		log_error "MudPi directory not found."
	fi

	if [ ! -d "$webroot_dir/mudpi" ]; then
		echo "MudPi UI directory not found."
	fi

	if [ ! -d "$webroot_dir/mudpi_assistant" ]; then
		echo "MudPi Assistant directory not found."
	fi

	sudo rm -rf "$webroot_dir"/mudpi*
	sudo rm /etc/nginx/sites-enabled/mudpi_ui.conf
	sudo rm /etc/nginx/sites-enabled/mudpi_assistant.conf
	sudo rm /etc/nginx/sites-enabled/assistant_redirect.conf
	sudo rm /etc/nginx/sites-available/mudpi_ui.conf
	sudo rm /etc/nginx/sites-available/mudpi_assistant.conf
	sudo rm /etc/nginx/sites-available/assistant_redirect.conf
	sudo rm -rf "$mudpi_dir"

}

function remove_mudpi_scripts() {
	if [ ! -f "/usr/bin/auto_hotspot" ]; then
		echo "MudPi auto AP Mode not found."
	fi

	if [ ! -f "/usr/bin/start_hotspot" ]; then
		echo "MudPi start_hotspot not found."
	fi

	if [ ! -f "/usr/bin/stop_hotspot" ]; then
		echo "MudPi stop_hotspot not found."
	fi

	sudo rm -rf /usr/bin/stop_hotspot
	sudo rm -rf /usr/bin/start_hotspot
	sudo rm -rf /usr/bin/auto_hotspot

}

function remove_dependancy_packages() {
	log_info "Removing installed dependacy packages"
	echo -n "Remove the following installed packages? ffmpeg $php_package hostapd dnsmasq htop [y/N]: "
	read answer
	if [ "$answer" != 'n' ] && [ "$answer" != 'N' ]; then
		echo "Removing packages."
		sudo apt-get remove ffmpeg $php_package hostapd dnsmasq htop
		sudo apt-get autoremove
	else
		echo "Leaving dependancy packages installed."
	fi
}

function remove_nginx() {
	log_info "Removing web server"
	echo -n "Remove nginx and disable web server? (You may have other sites!) [y/N]: "
	read answer
	if [ "$answer" != 'n' ] && [ "$answer" != 'N' ]; then
		echo "Removing nginx."
		sudo apt-get remove nginx mariadb-server mariadb-client
		sudo apt-get autoremove
	else
		echo "Leaving nginx installed."
	fi
}

function remove_supervisor() {
	log_info "Removing supervisor"
	echo -n "Remove supervisor and disable running jobs? (You may have other jobs!) [y/N]: "
	read answer
	if [ "$answer" != 'n' ] && [ "$answer" != 'N' ]; then
		echo "Removing supervisor."
		sudo apt-get remove supervisor
		sudo apt-get autoremove
	else
		sudo rm -rf /etc/supervisor/conf.d/mudpi*
		echo "Leaving supervisor installed."
	fi
}

function clean_sudoers_file() {
	# should this check for only our commands?
	sudo sed -i '/www-data/d' /etc/sudoers
}

function clean_hosts_file() {
	# should this check for only our commands?
	sudo sed -i '/#MUDPI/d' /etc/hosts
}

function uninstall_mudpi() {
	confirm_uninstall
	restore_backups
	remove_mudpi_directories
	remove_mudpi_scripts
	remove_dependancy_packages
	remove_nginx
	remove_supervisor
	clean_sudoers_file
	clean_hosts_file
}

uninstall_mudpi