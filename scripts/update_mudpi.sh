#!/bin/bash
# Fetches latest files from github
repo="mudpi/mudpi-core"
branch="master"
mudpi_dir="/etc/mudpi"
webroot_dir="/var/www/html"
mudpi_user="www-data"
user=$(whoami)

function log_error() {
	echo -e "\033[1;37;41mMudPi Install Error: $*\033[m"
	exit 1
}

if [ ! -d "$mudpi_dir" ]; then
	sudo mkdir -p $mudpi_dir || log_error "Unable to create new core install directory"
fi

if [ -d "$mudpi_dir/core" ]; then
	sudo mv $mudpi_dir/core "$mudpi_dir/core.`date +%F_%H%M%S`" || log_error "Unable to remove old core directory"
fi

echo "Cloning latest core files from github"
sudo rm -r /tmp/mudpi_core
git clone --depth 1 https://github.com/${repo} /tmp/mudpi_core || log_error "Unable to download core files from github"
sudo mv /tmp/mudpi_core $mudpi_dir/core || log_error "Unable to move Mudpi core to $mudpi_dir"
sudo chown -R $mudpi_user:$mudpi_user "$mudpi_dir" || log_error "Unable to set permissions in '$mudpi_dir'"
pip3 install -r $mudpi_dir/core/requirements.txt
