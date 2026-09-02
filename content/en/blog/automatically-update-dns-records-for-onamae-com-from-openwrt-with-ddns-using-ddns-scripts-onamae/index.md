---
title: Automatically Update Onamae.com DNS Records from OpenWrt Using DDNS
date: 2025-05-11T22:33:36+09:00
draft: false
tags:
  - OpenWrt
params:
  toc: true
---

## Introduction

The Onamae.com Dynamic DNS (DDNS) client supports only Windows. However, using ddns-scripts-onamae, you can update Onamae.com DNS records from a router running OpenWrt.

ddns-scripts-onamae is a submodule of the ddns-scripts package, which supports DDNS management on OpenWrt. It provides a function for automatically updating DNS records for Onamae.com, a widely used domain registrar in Japan.

This allows you to keep a hostname registered with Onamae.com synchronized with the latest IP address using an OpenWrt router, even when your internet connection does not have a static IP address.

This article explains how to automatically update Onamae.com DNS records from OpenWrt using DDNS and ddns-scripts-onamae.

## Install ddns-scripts-onamae

Visit the [ddns-scripts-onamae download site](https://github.com/ktdevx/ddns-scripts-onamae/releases) and check the latest package version. In this example, v1.0.2 is used.

Access OpenWrt over SSH and download the package with `wget`.

```
wget -O /tmp/ddns-scripts-onamae.ipk https://github.com/ktdevx/ddns-scripts-onamae/releases/download/v1.0.2/ddns-scripts-onamae_1.0.2-r1_all.ipk
```

The ddns-scripts-onamae package is saved as `ddns-scripts-onamae.ipk` in `/tmp`. Install it with `opkg install`.

```
opkg update
opkg install /tmp/ddns-scripts-onamae.ipk
```

The ddns-scripts-onamae installation is complete.

## Configure DDNS

Open `/etc/config/ddns` in a text editor and append the following configuration.

```
config service "example_com"
    option service_name "onamae.com"
    option lookup_host  "example.com"
    option domain       "@example.com"
    option username     "<Onamae.com Navi ID>"
    option password     "<Onamae.com Navi password>"
    option interface    "wan"
    option ip_source    "network"
    option ip_network   "wan"
    option use_ipv6     "0"
    option enabled      "1"
```

This adds a service named `example_com` that updates the `example.com` domain with the IP address of `wan`. Change the following settings for your environment.

| Setting | Details |
| --- | --- |
| lookup_host | Domain name (FQDN) whose IP address is updated |
| domain | Domain name to update (`subdomain@domain`) |
| username | Onamae.com Navi ID |
| password | Onamae.com Navi password |
| interface / ip_network | Network from which to read the IP address |

For a subdomain, configure `lookup_host` and `domain` as follows.

```
    option lookup_host  "sub.example.com"
    option domain       "sub@example.com"
```

After configuring the service, restart it with the following command.

```
service ddns restart
```

The DDNS configuration is complete. DNS records are now updated automatically.
