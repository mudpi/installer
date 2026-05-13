<img alt="MudPi Smart Garden" title="MudPi Smart Garden" src="https://mudpi.app/img/mudPI_LOGO_small_flat.png" width="100px">

# MudPi Installer
> A guided installation tool to download and set up MudPi on a Raspberry Pi or other Linux SBC.

MudPi Installer helps download, install and configure everything needed to get MudPi running. You will be guided through installing [MudPi Core](https://github.com/mudpi/mudpi-core), [MudPi Assistant (Optional)](https://github.com/mudpi/assistant) and [MudPi UI (Optional)](https://github.com/mudpi/ui). The installer handles all the [manual installation](docs/MANUAL_INSTALL.md) tasks and takes several minutes to complete (especially on older models).

## Prerequisites
MudPi will install most of the needed prerequisites, however you will need a few things beforehand.
* Raspberry Pi OS **Bookworm** (Debian 12) or **Trixie** (Debian 13)
* Set locale through `raspi-config`
* Internet connection
* Python 3.11+

If you haven't already, do a quick update and reboot:
```bash
sudo apt-get update
sudo apt-get upgrade
sudo reboot
```

## Installation
Install MudPi by running the following command in the terminal on your device:
```bash
curl -sL https://install.mudpi.app | bash
```
_Install times vary depending on device. ~10-15 mins_

### Options
```
-y, --yes, --force-yes    Forces "yes" answer to all prompts
-b, --branch <name>       Overrides the default git branch (master)
-h, --help                Outputs usage notes and exits
-v, --version             Outputs release info and exits
```

Install a specific branch:
```bash
curl -sL https://install.mudpi.app | bash -s -- -b feature
```

Fully unattended install:
```bash
curl -sL https://install.mudpi.app | bash -s -- -y
```

### What Gets Installed
The installer sets up the following components:
* **Python virtual environment** at `/home/mudpi/venv` with MudPi core and dependencies
* **PHP** (8.2 on Bookworm, 8.4 on Trixie) for the web interfaces
* **Nginx** web server (optional)
* **Redis** for state management and pub/sub
* **Mosquitto** MQTT broker for messaging
* **Supervisor** to manage the MudPi background process
* **GPIO libraries** (`rpi-lgpio`, `gpiozero`) for hardware interaction

### Note
MudPi Installer assumes most of the setup, so it is ideal to run on a fresh Raspberry Pi OS install or a Pi that is not already heavily configured for other purposes. The installer does its best to preserve existing configs and only alter the settings needed to operate. You may still encounter conflicts if you install MudPi on a device already running a web server or dedicated to another project.

## Documentation
For full documentation visit [mudpi.app](https://mudpi.app/docs)

## FAQ

#### Login for `mudpi` user?
Default password is `mudpiapp`. Change this before deploying to production with `sudo passwd mudpi`.

#### Where is MudPi installed?
MudPi core lives at `/home/mudpi/core`. Python packages are installed in a virtual environment at `/home/mudpi/venv`. Activate it with:
```bash
source /home/mudpi/venv/bin/activate
```

#### Installation failed?
Try rerunning the installer. If that fails again, uninstall completely and try on a fresh image.

#### Where are backups stored?
Backups are located at `/home/mudpi/backups`. The uninstaller will restore those for you automatically.

#### Uninstall
Uninstall MudPi and restore all backups:
```bash
sudo /home/mudpi/installer/uninstall.sh
```

#### Default Access Point IP
`192.168.4.1`

#### Default Access Point Password
The password is set during installation (default: `mudpi1234`). The hotspot is managed through NetworkManager. To change it:
```bash
sudo nmcli connection modify mudpi-hotspot wifi-sec.psk "new-password"
```

#### Auto AP Mode?
Auto AP Mode is a cron job that checks for Wi-Fi connectivity every 5 minutes. If no known network is in range, it activates the `mudpi-hotspot` access point via NetworkManager. Disable it by removing the cron entry:
```bash
sudo crontab -e
```

#### Something not right with Auto AP?
Check the logs at `/home/mudpi/logs/auto_hotspot.log` and scan results at `/home/mudpi/tmp/nearbynetworklist.txt`. You can also check hotspot status directly:
```bash
nmcli connection show mudpi-hotspot
nmcli device wifi list
```

#### Access Point activates after reboot even with saved Wi-Fi configs?
On boot, the Auto AP Mode script waits 2 minutes before its first check. If Wi-Fi hasn't connected yet, it may briefly activate the hotspot. It will reconnect on the next scan cycle (5 minutes) once Wi-Fi becomes available.

#### Do I need Assistant installed?
If you are using this installer and already have a Wi-Fi connection established, then probably not. It is mainly useful for headless first-time setup and building multiple units at scale.

#### Raspberry Pi 5 compatibility?
Yes. The installer uses `rpi-lgpio` and `gpiozero` for GPIO access, which are compatible with the Pi 5's RP1 chip. The older `RPi.GPIO` library is not used.

## Authors
* Eric Davisson  - [Website](http://ericdavisson.com)

## Community
* Discord  - [Join](https://discord.gg/daWg2YH)

## Versioning
Breaking.Major.Minor

## License
This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details

<img alt="MudPi Smart Garden" title="MudPi Smart Garden" src="https://mudpi.app/img/mudPI_LOGO_small_flat.png" width="50px">
