---
title: 【Ubuntu】固定IPアドレスを割り当てる
date: 2024-09-29T21:05:11+09:00
draft: false
params:
  toc: true
---

サーバーのOSとしてUbuntuを利用する場合、IPアドレスが変化しないように設定する必要があります。

ここでは、UbuntuでIPアドレスを固定化する方法について解説します。

## ネットワークインターフェース情報の確認

`ip address`と入力し、ネットワークインターフェースの情報を確認します。

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

今回は、`eth0`という名前のネットワークインターフェースのIPアドレスを固定化します。

## Netplan設定ファイルの作成

IPアドレスを固定化するため、`/etc/netplan`ディレクトリ配下にNetplanの設定ファイルを追加します。

デフォルトで存在する`50-cloud-init.yaml`は、システムによって上書きされる恐れがあるため、必ず新しくファイルを作成しましょう。この時、設定ファイルは名前の昇順で参照されることに注意してください。

ここでは、ファイル名を`99-config.yaml`として、内容を以下のように編集しました。

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

この例では、`eth0`のIPアドレスが`192.168.10.2`、デフォルトゲートウェイとDNSサーバーのIPアドレスが`192.168.10.1`となるように設定しています。

内容に問題がなければ、`/etc/netplan`ディレクトリ配下にファイルを保存してください。

## ネットワーク設定の反映

以下のコマンドで設定を反映します。

```
sudo netplan apply
```

これによりネットワーク設定が反映されます。`ip address`と入力して設定が反映されたか確認しましょう。

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

`eth0`の設定が反映されていることが確認できました。
