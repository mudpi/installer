<img alt="MudPi Smart Garden" title="MudPi Smart Garden" src="https://mudpi.app/img/mudPI_LOGO_small_flat.png" width="100px">

# MudPi Installer
> A guided installation through setting up MudPi on a RaspberryPi

MudPi Installer is a bash script to help download, install and configure everything needed to get MudPi running. The installer will run all the [manual installation](docs/MANUAL_INSTALL.md) tasks and take a several minutes to complete especially on slower models. You will be guided through installing [MudPi Core](https://github.com/mudpi/mudpi-core), [MudPi Assistant (Optional)](https://github.com/mudpi/assistant) and [MudPi UI (Optional)](https://github.com/mudpi/ui). MudPi will assume most of the work so its better to run on a fresh Raspbain install or a device that is not already heavily configured. Backups are made of existing files and configs in the event of an error and can be restored upon uninstall.

## Prerequisites
MudPi will install most of the needed prerequisites however you will need a few things beforehand.
* Raspbian 9 (Stretch) or 10 (Buster)
* Set Locale through raspi-config
* Internet Connected

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


## Note
MudPi installer assumes most of the work to get the pi ready. The installer does its best to preserve old configs and only alter the needed settings to operate. Although, you still may have some conflicts if you try to install MudPi on a device already running a web server or that is already dedicated to another project.


## Documentation
For full documentation visit [mudpi.app](https://mudpi.app/docs)


## Guides
For examples and guides on how to setup and use MudPi check out the [free guides available.](https://mudpi.app/guides)


## FAQ
Here are a few notes about the MudPi installer:
### Backups
Backups are located at `/etc/mudpi/backups`
### Installation Failed
Try rerunning the installer and if that fails again uninstall completely and try again.
### Uninstall
Uninstall MudPi and restore all backups:
```
sudo /etc/mudpi/installer/uninstall.sh
```

## Versioning
Breaking.Major.Minor



## Authors
* Eric Davisson  - [Website](http://ericdavisson.com)
* [Twitter.com/theDavisson](https://twitter.com/theDavisson)


## Devices Tested On
* [Raspberry Pi 2 Model B+](https://www.raspberrypi.org/products/raspberry-pi-2-model-b/)
* [Raspberry Pi 3 Model B](https://www.raspberrypi.org/products/raspberry-pi-3-model-b/)
* [Raspberry Pi 3 Model B+](https://www.raspberrypi.org/products/raspberry-pi-3-model-b/)
* [Raspberry Pi Zero](https://www.raspberrypi.org/products/raspberry-pi-zero/)

Let me know if you are able to confirm tests on any other devices

## License
This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details


<img alt="MudPi Smart Garden" title="MudPi Smart Garden" src="https://mudpi.app/img/mudPI_LOGO_small_flat.png" width="50px">

