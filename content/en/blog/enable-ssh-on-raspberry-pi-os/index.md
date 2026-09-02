---
title: Enable SSH Access on Raspberry Pi OS
date: 2024-09-30T00:16:27+09:00
draft: false
tags:
  - Raspberry Pi
  - SSH
params:
  toc: true
---

Raspberry Pi OS is an operating system for Raspberry Pi devices provided by the Raspberry Pi Foundation. Enabling SSH access allows you to access your Raspberry Pi remotely.

This article explains how to enable SSH access on Raspberry Pi OS.

## Launch the Configuration Tool

Run the following command to launch the Raspberry Pi configuration tool.

```
sudo raspi-config
```

## Enable the SSH Server

![raspi-config](images/raspi-config-1.webp)

After running the command, the configuration screen is displayed. Move the cursor to Interface Options and press Enter.

![raspi-config](images/raspi-config-2.webp)

The interfaces for which you can enable or disable settings are displayed. Move the cursor to SSH and press Enter.

![raspi-config](images/raspi-config-3.webp)

You are asked whether to enable the SSH server. Select Yes.

![raspi-config](images/raspi-config-4.webp)

The SSH server is enabled. Press Enter to return to the top of the configuration screen.

![raspi-config](images/raspi-config-5.webp)

Select Finish to close the configuration tool.

## Restart the SSH Server

Run the following command to restart the SSH server.

```
sudo systemctl restart ssh
```

SSH access is now enabled on Raspberry Pi OS. You can access the Raspberry Pi remotely over SSH from another computer.
