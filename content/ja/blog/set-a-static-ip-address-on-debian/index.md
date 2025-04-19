---
title: Debianで静的IPアドレスを設定する
date: 2025-04-20T00:49:42+09:00
draft: false
tags:
  - Debian
params:
  toc: true
---

サーバーのOSとしてDebianを利用する場合、IPアドレスが変化しないように設定する必要があります。

ここでは、DebianでIPアドレスを固定化する方法について解説します。

## ネットワークインターフェース情報の確認

`ip a`と入力し、ネットワークインターフェースの情報を確認します。

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

今回は、`ens18`という名前のネットワークインターフェースのIPアドレスを固定化します。

## ネットワーク設定ファイルの編集

IPアドレスを固定化するため、`/etc/network/interfaces`という名前の設定ファイルを編集します。

DHCPが有効な設定になっていると、`iface ens18 inet dhcp`といったような行があるかと思います。このdhcpの箇所をstaticに変更することで手動設定に変更します。

```
iface ens18 inet static
    address 192.168.2.3
    netmask 255.255.255.0
    gateway 192.168.2.1
    dns-nameservers 192.168.2.1
```

この例では、`ens18`のIPアドレスが`192.168.2.3/24`、デフォルトゲートウェイとDNSサーバーのIPアドレスが`192.168.2.1`となるように設定しています。

内容に問題がなければファイルを保存してください。

## ネットワーク設定の反映

以下のコマンドで設定を反映します。

```
sudo systemctl restart networking
```

これによりネットワーク設定が反映されます。`ip a`と入力して設定が反映されたか確認しましょう。

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

`ens18`の設定が反映されていることが確認できました。
