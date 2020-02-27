<img alt="MudPi Smart Garden" title="MudPi Smart Garden" src="https://mudpi.app/img/mudPI_LOGO_small_flat.png" width="100px">

# MudPi Installer
> A guided installation to download and setup MudPi on a RaspberryPi

MudPi Installer is a bash script to help download, install and configure everything needed to get MudPi running. You will be guided through installing [MudPi Core](https://github.com/mudpi/mudpi-core), [MudPi Assistant (Optional)](https://github.com/mudpi/assistant) and [MudPi UI (Optional)](https://github.com/mudpi/ui). The installer will run all the [manual installation](docs/MANUAL_INSTALL.md) tasks and take a several minutes to complete (especially on older models).

## Prerequisites
MudPi will install most of the needed prerequisites however you will need a few things beforehand.
* Raspbian 9 (Stretch) or 10 (Buster)
* Set Locale through raspi-config
* Internet Connection

If you haven't already also do a quick update and reboot.
```
sudo apt-get update
sudo apt-get upgrade
sudo reboot
```


## Installation
Install MudPi from your RaspberryPi terminal using:
```
curl -sL https://install.mudpi.app | bash
```


### Note
MudPi Installer assumes most of the work so its ideal to run on a fresh Raspbian install or pi that is not already heavily configured for other purposes. The installer does its best to preserve old configs and only alter the needed settings to operate. Although, you still may have some conflicts if you try to install MudPi on a device already running a web server or that is already dedicated to another project.


## Documentation
For full documentation visit [mudpi.app](https://mudpi.app/docs)


## FAQ
Here are a common questions about the MudPi installer and some solutions. When in doubt remove it all and reinstall.
#### Installation Failed?
Try rerunning the installer and if that fails again uninstall completely and try again.
#### Where are backups stored?
Backups are located at `/etc/mudpi/backups`. The uninstaller will restore those for you automatically.
#### Uninstall
Uninstall MudPi and restore all backups:
```
sudo /etc/mudpi/installer/uninstall.sh
```
#### Default Access Point Static IP
`192.168.2.1`
#### Default Access Point Password
`MudPi123`
#### Auto AP Mode?
Auto AP Mode is a script that will trigger the access point in the event Wifi is not connected. Remove the cron jobs using `sudo crontab -e` to disable it. AP Mode checks every 10 minutes by default.
#### Something not right with Auto AP?
First check the logs `/etc/mudpi/logs/auto_hotspot.log` and look at scan results `/etc/mudpi/tmp/nearbynetworklist.txt`.
#### Access Point activated after reboot even with saved Wifi configs
Sometimes when the pi first boots it may try to run programs too soon. The Auto AP Mode might not have been able to determine a wifi connection yet so it defaulted to AP Mode. It will reconnect shortly on the next scan and turn off the AP.
#### Do I neeed Assistant Installed?
If you are using this installer and already established a Wifi connection then *probably not*. It is mainly to help me build multiple units at scale internally.
#### Problems on Debian 9 (Stretch)?
Verified on pi zero w running Debian 9.4 (stretch), however I reccomend upgrading to buster. It was hard to even find an archive of old releases on the Raspberrypi main site.
#### Invalid Operation?
Something got borked. Fresh raspbian install time.

## Authors
* Eric Davisson  - [Website](http://ericdavisson.com)
* [Twitter.com/theDavisson](https://twitter.com/theDavisson)

## Community
* Discord  - [Join](https://discord.gg/daWg2YH)
* [Twitter.com/MudpiApp](https://twitter.com/mudpiapp)

## Devices Tested On
* [Raspberry Pi 2 Model B+](https://www.raspberrypi.org/products/raspberry-pi-2-model-b/)
* [Raspberry Pi 3 Model B](https://www.raspberrypi.org/products/raspberry-pi-3-model-b/)
* [Raspberry Pi 3 Model B+](https://www.raspberrypi.org/products/raspberry-pi-3-model-b/)
* [Raspberry Pi Zero](https://www.raspberrypi.org/products/raspberry-pi-zero/)

Let me know if you are able to confirm tests on any other devices

## Versioning
Breaking.Major.Minor

## License
This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details


<img alt="MudPi Smart Garden" title="MudPi Smart Garden" src="https://mudpi.app/img/mudPI_LOGO_small_flat.png" width="50px">

