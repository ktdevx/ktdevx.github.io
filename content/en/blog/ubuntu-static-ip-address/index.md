---
title: Assign a Static Address on Ubuntu
date: 2024-09-29T21:05:11+09:00
draft: false
params:
  toc: true
---

When using Ubuntu as a server OS, you may need to configure it so that the IP address remains consistent.

This guide explains how to set a static IP address on Ubuntu.

## Check Network Interface Information

Enter `ip address` to check your network interface information.

```
ip address
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether dc:a6:32:c4:6d:4e brd ff:ff:ff:ff:ff:ff
    inet 192.168.10.107/24 metric 100 brd 192.168.10.255 scope global dynamic eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::dea6:32ff:fec4:6d4e/64 scope link
       valid_lft forever preferred_lft forever
3: wlan0: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether dc:a6:32:c4:6d:4f brd ff:ff:ff:ff:ff:ff
```

In this example, we’ll set a static IP for the network interface named `eth0`.

## Create a Netplan Configuration File

To set a static IP, add a Netplan configuration file under the `/etc/netplan` directory.

Do not edit the existing `50-cloud-init.yaml`, as it may be overwritten by the system. Instead, create a new file. Note that configuration files are read in ascending alphabetical order.

Here, we create a file named `99-config.yaml` and configure it as follows:

```yaml
network:
    version: 2
    renderer: networkd
    ethernets:
      eth0:
        dhcp4: false
        addresses:
          - 192.168.10.2/24
        routes:
          - to: default
            via: 192.168.10.1
        nameservers:
            search: []
            addresses: [192.168.10.1]
```

In this example, we set the IP address of `eth0` to `192.168.10.2`, with a default gateway and DNS server address of `192.168.10.1`.

Save this file in the `/etc/netplan` directory if the configuration is correct.

## Apply Network Settings

Apply the settings with the following command:

```
sudo netplan apply
```

This will apply the network configuration. Enter `ip address` to confirm that the changes have taken effect.

```
ip address
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether dc:a6:32:c4:6d:4e brd ff:ff:ff:ff:ff:ff
    inet 192.168.10.2/24 brd 192.168.10.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::dea6:32ff:fec4:6d4e/64 scope link
       valid_lft forever preferred_lft forever
3: wlan0: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether dc:a6:32:c4:6d:4f brd ff:ff:ff:ff:ff:ff
```

You can confirm that the settings for `eth0` have been applied.
