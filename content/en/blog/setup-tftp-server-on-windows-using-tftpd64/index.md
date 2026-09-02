---
title: Set Up a TFTP Server on Windows Using Tftpd64
date: 2025-03-16T16:44:58+09:00
draft: false
tags:
  - Tftpd64
params:
  toc: true
---

Tftpd64 is software for Windows that provides TFTP, SNTP, SYSLOG, DHCP, and DNS servers.

This article explains how to set up a TFTP server on Windows using Tftpd64.

## Install Tftpd64

The Tftpd64 installer is available as a file named `Tftpd64-<version>-setup.exe` on the [Tftpd64 official website](https://pjo2.github.io/tftpd64/). Download and run the installer.

![Tftpd64 installer](images/tftpd64-install1.webp)

The license is displayed. Review it and select I Agree to continue.

![Tftpd64 installer](images/tftpd64-install2.webp)

You can configure the installation options. After configuring them, select Next to continue.

![Tftpd64 installer](images/tftpd64-install3.webp)

Choose where to install Tftpd64. After configuring the location, select Install to start the installation.

![Tftpd64 installer](images/tftpd64-install4.webp)

When Completed! is displayed on the screen, the installation is complete. Select Close to exit the installer.

## Use Tftpd64

Run the installed `tftpd64.exe` to launch Tftpd64.

![Tftpd64](images/tftpd64-usage1.webp)

After launching Tftpd64, select Settings to open the settings screen.

![Tftpd64](images/tftpd64-usage2.webp)

The GLOBAL tab on the settings screen contains settings for Tftpd64 as a whole. Since only the TFTP server is used in this example, select only TFTP Server.

![Tftpd64](images/tftpd64-usage3.webp)

The TFTP tab contains settings related to TFTP. Set the base directory published by the TFTP server in Base Directory.

By default, Tftpd64 accepts connections from TFTP clients on all network interfaces. Select Bind TFTP to this address and specify an IP address to choose the address on which the server is published.

After configuring the settings, select OK to apply them.

![Tftpd64](images/tftpd64-usage4.webp)

A confirmation dialog is displayed. Select OK to restart Tftpd64. The TFTP setup is now complete.

Place an appropriate file in the directory and try retrieving it from a TFTP client.

![Tftpd64](images/tftpd64-usage5.webp)

You can confirm that the TFTP client can access the server.

If you cannot access the server, review the IP address and port settings and check whether security software is blocking the connection.
