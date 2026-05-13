#!/bin/bash
#
# Update MudPi core to the latest release from GitHub
#

repo="mudpi/mudpi-core"
branch="master"
mudpi_dir="/home/mudpi"
venv_dir="${mudpi_dir}/venv"
mudpi_user="mudpi"

function log_info() {
	echo -e "\033[1;32mMudPi Update: $*\033[m"
}

function log_error() {
	echo -e "\033[1;37;41mMudPi Update Error: $*\033[m"
	exit 1
}

if [ ! -d "$mudpi_dir" ]; then
	sudo mkdir -p "$mudpi_dir" || log_error "Unable to create install directory"
fi

if [ -d "$mudpi_dir/core" ]; then
	sudo mv "$mudpi_dir/core" "$mudpi_dir/core.$(date +%F_%H%M%S)" || log_error "Unable to back up old core directory"
fi

log_info "Cloning latest core files from GitHub"
sudo rm -rf /tmp/mudpi_core
git clone --depth 1 -b "$branch" "https://github.com/${repo}" /tmp/mudpi_core || log_error "Unable to download core files from GitHub"
sudo mv /tmp/mudpi_core "$mudpi_dir/core" || log_error "Unable to move MudPi core to $mudpi_dir"
sudo chown -R "$mudpi_user:$mudpi_user" "$mudpi_dir" || log_error "Unable to set permissions in '$mudpi_dir'"

log_info "Installing dependencies into virtual environment"
if [ ! -d "$venv_dir" ]; then
	log_info "Virtual environment not found, creating at ${venv_dir}"
	sudo -u "$mudpi_user" python3 -m venv --system-site-packages "$venv_dir" || log_error "Unable to create virtual environment"
fi

if [ -f "$mudpi_dir/core/requirements.txt" ]; then
	sudo -u "$mudpi_user" "${venv_dir}/bin/pip" install -r "$mudpi_dir/core/requirements.txt" || log_error "Unable to install requirements"
fi
sudo -u "$mudpi_user" "${venv_dir}/bin/pip" install "$mudpi_dir/core" || log_error "Unable to install MudPi core package"

log_info "Restarting MudPi service"
sudo supervisorctl restart mudpi 2>/dev/null || true

log_info "MudPi core updated successfully!"
