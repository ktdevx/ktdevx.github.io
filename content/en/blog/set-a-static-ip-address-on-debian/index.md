---
title: Set a Static IP Address on Debian
date: 2025-04-20T00:49:42+09:00
draft: false
tags:
  - Debian
params:
  toc: true
---

When using Debian as a server operating system, you may need to configure it so that its IP address does not change.

This article explains how to set a static IP address on Debian.

## Check the Network Interface Information

Enter `ip a` to check the network interface information.

```
kaito@file:~$ ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host noprefixroute
       valid_lft forever preferred_lft forever
2: ens18: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether bc:24:11:6e:79:1d brd ff:ff:ff:ff:ff:ff
    altname enp0s18
    inet 192.168.2.140/24 brd 192.168.2.255 scope global dynamic ens18
       valid_lft 43045sec preferred_lft 43045sec
    inet6 2001:f76:8a0:8b00:be24:11ff:fe6e:791d/64 scope global dynamic mngtmpaddr
       valid_lft 2591844sec preferred_lft 604644sec
    inet6 fe80::be24:11ff:fe6e:791d/64 scope link
       valid_lft forever preferred_lft forever
```

In this example, the IP address of the network interface named `ens18` is set to a static address.

## Edit the Network Configuration File

To set a static IP address, edit the configuration file named `/etc/network/interfaces`.

When DHCP is enabled, there may be a line such as `iface ens18 inet dhcp`. Change `dhcp` to `static` to switch to manual configuration.

```
iface ens18 inet static
    address 192.168.2.3
    netmask 255.255.255.0
    gateway 192.168.2.1
    dns-nameservers 192.168.2.1
```

In this example, the IP address of `ens18` is configured as `192.168.2.3/24`, and the default gateway and DNS server are configured as `192.168.2.1`.

Save the file if the configuration is correct.

## Apply the Network Configuration

Run the following command to apply the configuration.

```
sudo systemctl restart networking
```

The network configuration is now applied. Enter `ip a` to verify that the settings have been applied.

```
kaito@file:~$ ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host noprefixroute
       valid_lft forever preferred_lft forever
2: ens18: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether bc:24:11:6e:79:1d brd ff:ff:ff:ff:ff:ff
    altname enp0s18
    inet 192.168.2.3/24 brd 192.168.2.255 scope global ens18
       valid_lft forever preferred_lft forever
    inet6 2001:f76:8a0:8b00:be24:11ff:fe6e:791d/64 scope global dynamic mngtmpaddr
       valid_lft 2591912sec preferred_lft 604712sec
    inet6 fe80::be24:11ff:fe6e:791d/64 scope link
       valid_lft forever preferred_lft forever
```

You can confirm that the `ens18` configuration has been applied.
