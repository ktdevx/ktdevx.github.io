---
title: Install OpenMediaVault
date: 2025-04-05T21:59:14+09:00
lastmod: 2025-04-12T19:36:21+09:00
draft: false
tags:
  - OpenMediaVault
params:
  toc: true
---

OpenMediaVault (OMV) is open-source NAS software based on Debian and designed to make it easy to build a NAS.

This article explains how to install OpenMediaVault.

## Introduction

For the server hardware, GMKtec's NucBox M5 Plus was selected.

{{< ads/nucbox-m5-plus >}}

Since the Proxmox VE virtualization platform is installed on the mini PC, a virtual machine is created there and Debian is installed on it.

When installing it in a virtual machine on Proxmox VE, also see [Create a Virtual Machine (VM) on Proxmox VE](/blog/create-vm-in-proxmox-ve).

## Download OpenMediaVault

Download the ISO image from the [OpenMediaVault download page](https://www.openmediavault.org/download). In this example, OpenMediaVault 7.4.14 was downloaded.

## Create an Installation USB Drive

Write the downloaded ISO image to a USB drive. Use an image-writing tool such as Win32 Disk Imager.

For details on using Win32 Disk Imager, see [How to Install and Use Win32 Disk Imager](/blog/install-win32-disk-imager).

## Install OpenMediaVault

Connect the USB drive to the PC on which you want to install OpenMediaVault, start the PC, and boot from the USB drive. The OpenMediaVault installation screen is displayed.

### Select the Installation Method

![OpenMediaVault installation screen](images/install-omv-1.webp)

The installation methods are displayed. Select Install and press Enter, or wait for the installation to start automatically.

### Configure the Language

![OpenMediaVault installation screen](images/install-omv-2.webp)

Configure the language displayed during installation. Select Japanese and press Enter.

### Configure the Locale

![OpenMediaVault installation screen](images/install-omv-3.webp)

Configure the locale. This setting is used to help configure the time zone and select the system locale.

Select Japan and press Enter.

### Configure the Keyboard

![OpenMediaVault installation screen](images/install-omv-4.webp)

Configure the keyboard. Select the layout that matches your keyboard and press Enter.

### Load Additional Components and Configure the Network Automatically

![OpenMediaVault installation screen](images/install-omv-5.webp)

Additional components are loaded and the network is configured automatically.

At this point, **the installer may get stuck after configuring DHCPv6 in an IPv6 environment**. See the following article for the cause and solution:

[OpenMediaVault Installation Stuck During DHCPv6 Configuration](/blog/omv-installation-stuck-in-dhcpv6-configuration)

### Configure the Hostname

![OpenMediaVault installation screen](images/install-omv-6.webp)

Configure the server hostname.

The default is `openmediavault`. If you have no specific requirement, you can leave it unchanged.

Enter a hostname, move the cursor to <Continue>, and press Enter.

### Configure the Domain Name

![OpenMediaVault installation screen](images/install-omv-7.webp)

Configure the server domain name.

The default is `local`. If you have no specific requirement, you can leave it unchanged.

Enter a domain name, move the cursor to <Continue>, and press Enter.

### Configure the Administrator Password

![OpenMediaVault installation screen](images/install-omv-8.webp)

Configure the password for the administrator user (`root`).

Enter a password, move the cursor to <Continue>, and press Enter.

![OpenMediaVault installation screen](images/install-omv-9.webp)

Enter the same password again for confirmation, move the cursor to <Continue>, and press Enter.

### Configure the Debian Package Repository

![OpenMediaVault installation screen](images/install-omv-10.webp)

Configure the Debian package repository. Select Japan and press Enter.

![OpenMediaVault installation screen](images/install-omv-11.webp)

A list of package repositories and mirrors is displayed. If you have no specific requirement, `deb.debian.org` is suitable.

Select a repository and press Enter.

### Configure the HTTP Proxy

![OpenMediaVault installation screen](images/install-omv-12.webp)

Configure the HTTP proxy.

If you need to access the internet through a proxy, enter the proxy information. Otherwise, leave it blank.

Move the cursor to <Continue> and press Enter.

### Install the Boot Loader

![OpenMediaVault installation screen](images/install-omv-13.webp)

Select the destination for the GRUB boot loader.

Select the device on which to install GRUB and press Enter.

### Restart the System

![OpenMediaVault installation screen](images/install-omv-14.webp)

Remove the USB drive used for installation, move the cursor to <Continue>, and press Enter.

The system restarts and OpenMediaVault boots.

![OpenMediaVault installation screen](images/install-omv-15.webp)

The shell login screen is displayed. The OpenMediaVault installation is complete.

## Access the OpenMediaVault Management Interface

Access the OpenMediaVault management interface.

From a web browser, access it over HTTP using the combination of the hostname and domain name (by default, `openmediavault.local`) or the IP address.

The IP address can also be checked on the shell login screen displayed earlier.

![OpenMediaVault management interface](images/omv-login.webp)

The login screen is displayed. Log in with `admin` as the username and `openmediavault` as the password.

## Change the Management Interface Language

![OpenMediaVault management interface](images/omv-lang.webp)

The management interface is in English by default, so change it to Japanese.

Click the person icon in the upper-right corner of the management interface and select Language. Select Japanese from the available languages.

The OpenMediaVault management interface is now displayed in Japanese.

## Change the Administrator Password

![OpenMediaVault management interface](images/omv-password.webp)

The administrator user (`admin`) password is `openmediavault` by default. Change it because leaving the default password is unsafe.

Click the person icon in the upper-right corner of the management interface and select Change Password.

The password change screen is displayed. Enter the password you want to use and select Save.

The password used to log in as the administrator on the OpenMediaVault management interface has now been changed.
