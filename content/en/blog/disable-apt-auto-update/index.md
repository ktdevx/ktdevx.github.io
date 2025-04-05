---
title: Disable Automatic Updates for APT Packages
date: 2024-09-29T19:22:50+09:00
draft: false
tags:
  - APT
params:
  toc: true
---

When packages are updated automatically, there is a chance that software that was previously working may suddenly stop functioning.

This guide explains how to disable automatic updates for APT packages.

## Check Automatic Update Settings

The automatic update settings are located in the `20auto-upgrades` file within the `/etc/apt/apt.conf.d` directory. Below is an example of the settings:

```
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
```

`Update-Package-Lists` indicates automatic package updates, while `Unattended-Upgrade` represents automatic package upgrades. A value of `1` enables the setting, and `0` disables it.

## Disable Automatic Updates

To disable automatic package updates and upgrades, edit `20auto-upgrades` as shown below:

```
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Unattended-Upgrade "0";
```

This will disable automatic updates for packages.
