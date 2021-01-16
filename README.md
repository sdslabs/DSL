# DSL

Darwin subsytem for Linux. Not actually a subsystem like WSL, but runs an Ubuntu 16 VM on a hypervisor ([xhyve](https://github.com/machyve/xhyve) or [hyperkit](https://github.com/moby/hyperkit)) and adds a nice frontend to manage the VM.
Goal is to make running Ubuntu or any flavour of linux as seamless as possible using existing technologies.

<p align="center"><img src="https://i.imgur.com/xHDyG8t.png" width="70%"></p>

## Installation

Head over to ![releases page](https://github.com/sdslabs/DSL/releases) to download the latest version of Ubuntu.dmg and move the App to Applications folder. On the first run, it will make you download a base image, which is 3 Gb in size. You can later make and attach other disks to the VM. Login via SSH using username `default` and password `password`.

## Licensing

We do not own the Ubuntu image - the hosted base image is derived from Ubuntu Server 16.04.5 and Canonical Ltd. is the rightful owner of Ubuntu. Please open an issue if this needs a proper licensing.
