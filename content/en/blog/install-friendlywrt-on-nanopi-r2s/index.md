---
title: Install FriendlyWrt on NanoPi R2S
date: 2024-09-29T21:35:25+09:00
draft: false
params:
  toc: true
---

Installing FriendlyWrt on a NanoPi R2S allows anyone to easily set up a router.

This guide explains how to install FriendlyWrt on the NanoPi R2S.

## Introduction

The NanoPi R2S is a single-board computer manufactured by FriendlyElec. With two Ethernet ports, it is ideal for use as router hardware.

FriendlyWrt is an OpenWrt-based OS provided by FriendlyElec. It is open-source and suitable for developing routers, NAS, and IoT applications.

## Download FriendlyWrt

Go to the [official download link](https://drive.google.com/drive/folders/1H56Yl3G5kBAE_JGaYT2O_D8xKsBP7kZv) and download the FriendlyWrt image file from `01_Official images/01_SD card images`.

The available FriendlyWrt image files include:

|Image File                                        |Details                                          |
|--------------------------------------------------|-------------------------------------------------|
|rk3328-sd-friendlywrt-21.02-YYYYMMDD.img.gz       |Based on OpenWrt 21.02                           |
|rk3328-sd-friendlywrt-21.02-docker-YYYYMMDD.img.gz|Based on OpenWrt 21.02 (Docker container support)|
|rk3328-sd-friendlywrt-23.05-YYYYMMDD.img.gz       |Based on OpenWrt 22.03                           |
|rk3328-sd-friendlywrt-23.05-docker-YYYYMMDD.img.gz|Based on OpenWrt 22.03 (Docker container support)|

The files are compressed in gzip format, so use 7-Zip or a similar tool to extract them.

## Write FriendlyWrt to the microSD

Write the downloaded FriendlyWrt image to a microSD card.

Insert the microSD card into your PC, and use a tool like Win32 Disk Imager to write the OS to it. It is recommended to use a microSD card with at least 8GB of storage.

## Boot FriendlyWrt

Insert the microSD card with FriendlyWrt into the NanoPi and power it on to start the system.

After a short time, you will be able to connect via HTTP or SSH. The connection details are as follows:

Hostname: FriendlyWrt  
IPv4 Address: 192.168.2.1  
IPv6 Address: [fd00:ab:cd::1]

Log in with the username `root` and the password `password`.

## Recommended Security Settings

Before using the NanoPi, it is recommended to connect via SSH and perform the following security settings.

### Change the Login Password

Use the `passwd` command to change the password for the `root` user.

```
passwd
Changing password for root
New password: <password>
Retype password: <retype-password>
passwd: password for root changed by root
```

From this point, you can log in with the new password.

### Configure SSH Access Settings

Use the following commands to restrict SSH access to the LAN only and change the port number to a custom value.

```
uci set dropbear.@dropbear[0].Interface=lan
uci set dropbear.@dropbear[0].Port=<port-number>
```

If there are no issues, apply the settings with the following commands:

```
uci commit dropbear
service dropbear restart
```

The changes will take effect, and you’ll need to use the new port number for SSH access.

### Restrict Access to LuCI

Use the following commands to limit LuCI access to local devices only.

```
uci set uhttpd.main.listen_http=192.168.2.1:80
uci add_list uhttpd.main.listen_http=[fd00:ab:cd::1]:80
uci set uhttpd.main.listen_https=192.168.2.1:443
uci add_list uhttpd.main.listen_https=[fd00:ab:cd::1]:443
```

If there are no issues, apply the settings with the following commands:

```
uci commit uhttpd
uci uhttpd restart
```

The changes will take effect.
