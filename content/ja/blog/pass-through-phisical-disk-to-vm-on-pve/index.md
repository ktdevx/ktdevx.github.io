---
title: Proxmox VE上の仮想マシンに物理ディスクをパススルーする
date: 2025-04-06T23:47:16+09:00
draft: false
tags:
  - Proxmox VE
params:
  toc: true
---

ここでは、Proxmox VE上の仮想マシンに物理ディスクをパススルーする方法について説明します。

## はじめに

仮想マシンに物理ディスクをパススルーする前に、現在仮想マシンに接続されているディスクを`lsblk`コマンドで確認してみます。

```
root@openmediavault:~# lsblk
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda      8:0    0   32G  0 disk
|-sda1   8:1    0   31G  0 part /
|-sda2   8:2    0    1K  0 part
`-sda5   8:5    0  975M  0 part [SWAP]
sr0     11:0    1 1024M  0 rom
```

今回はここに1TBの物理ディスクをパススルーして接続します。

## ディスクの確認

物理ディスクの型番を確認後、Proxmox VEがインストールされたサーバーにディスクを接続しましょう。

接続後、Proxmox VEのシェルで`ls -l /dev/disk/by-id/`と打ってディスクを確認します。

```
root@pve:~# ls -l /dev/disk/by-id/
total 0
lrwxrwxrwx 1 root root  9 Apr  6 23:28 ata-TOSHIBA_DT01ACA100_X7P8MYTFS -> ../../sda
lrwxrwxrwx 1 root root 10 Apr  6 23:28 ata-TOSHIBA_DT01ACA100_X7P8MYTFS-part1 -> ../../sda1
lrwxrwxrwx 1 root root 10 Apr  5 22:12 dm-name-pve-root -> ../../dm-1
lrwxrwxrwx 1 root root 10 Apr  5 22:12 dm-name-pve-swap -> ../../dm-0
lrwxrwxrwx 1 root root 10 Apr  5 22:46 dm-name-pve-vm--100--disk--0 -> ../../dm-6
...
```

`/dev/disk/by-id/`は、Linuxにおいてストレージデバイスへのシンボリックリンクが集められたディレクトリです。

`/dev/sdX`のような名前は、起動順や接続順で変わる可能性がありますが、`/dev/disk/by-id/`のリンクは、デバイス固有のIDを使ってアクセスできるパスを提供するため、**常に同じディスクをマウントしたい**場合に非常に便利です。

今回接続したディスクへのパスは`/dev/disk/by-id/ata-TOSHIBA_DT01ACA100_X7P8MYTFS`でした。これを控えておきましょう。

## ディスクを仮想マシンにパススルー

仮想マシンに物理ディスクをパススルーするには、`qm set`コマンドを使用します。

```
qm set <VM ID> -scsi<SCSIインターフェースの番号> <物理ディスクへのパス>
```

今回は以下のように設定しました。

```
root@pve:~# qm set 100 -scsi1 /dev/disk/by-id/ata-TOSHIBA_DT01ACA100_X7P8MYTFS
update VM 100: -scsi1 /dev/disk/by-id/ata-TOSHIBA_DT01ACA100_X7P8MYTFS
```

これにより、VM IDが100の仮想マシンに、SCSI1を介して、指定した物理ディスクが接続されます。

## パススルーしたディスクの確認

物理ディスクをパススルーした後、仮想マシンを再起動して仮想マシンのシェルにログインしましょう。

`lsblk`コマンドでディスクを確認してみます。

```
root@openmediavault:~# lsblk
NAME   MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
sda      8:0    0    32G  0 disk
|-sda1   8:1    0    31G  0 part /
|-sda2   8:2    0     1K  0 part
`-sda5   8:5    0   975M  0 part [SWAP]
sdb      8:16   0 931.5G  0 disk
`-sdb1   8:17   0 931.5G  0 part
sr0     11:0    1  1024M  0 rom
```

無事、物理ディスクがパススルー出来ていることを確認できました。
