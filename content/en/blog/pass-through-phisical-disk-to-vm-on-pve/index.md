---
title: Pass Through a Physical Disk to a Virtual Machine on Proxmox VE
date: 2025-04-06T23:47:16+09:00
draft: false
tags:
  - Proxmox VE
params:
  toc: true
---

This article explains how to pass through a physical disk to a virtual machine on Proxmox VE.

## Introduction

Before passing through a physical disk to the virtual machine, check the disks currently connected to it with the `lsblk` command.

```
root@openmediavault:~# lsblk
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda      8:0    0   32G  0 disk
|-sda1   8:1    0   31G  0 part /
|-sda2   8:2    0    1K  0 part
`-sda5   8:5    0  975M  0 part [SWAP]
sr0     11:0    1 1024M  0 rom
```

In this example, a 1 TB physical disk is connected through to the virtual machine.

## Check the Disk

Check the model number of the physical disk, then connect it to the server where Proxmox VE is installed.

After connecting it, run `ls -l /dev/disk/by-id/` in the Proxmox VE shell to check the disk.

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

`/dev/disk/by-id/` is a directory containing symbolic links to storage devices on Linux.

Names such as `/dev/sdX` can change depending on the boot or connection order. Links in `/dev/disk/by-id/` use device-specific IDs, so they are very useful when you want to always access the same disk.

The path to the disk connected in this example was `/dev/disk/by-id/ata-TOSHIBA_DT01ACA100_X7P8MYTFS`. Make a note of it.

## Pass Through the Disk to the Virtual Machine

Use the `qm set` command to pass through a physical disk to the virtual machine.

```
qm set <VM ID> -scsi<SCSI interface number> <path to physical disk>
```

The following configuration was used in this example.

```
root@pve:~# qm set 100 -scsi1 /dev/disk/by-id/ata-TOSHIBA_DT01ACA100_X7P8MYTFS
update VM 100: -scsi1 /dev/disk/by-id/ata-TOSHIBA_DT01ACA100_X7P8MYTFS
```

The specified physical disk is connected to the virtual machine with VM ID 100 through SCSI1.

## Check the Passed-Through Disk

After passing through the physical disk, restart the virtual machine and log in to its shell.

Check the disk with the `lsblk` command.

```
root@openmediavault:~# lsblk
NAME   MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
sda      8:0    0   32G  0 disk
|-sda1   8:1    0   31G  0 part /
|-sda2   8:2    0     1K  0 part
`-sda5   8:5    0  975M  0 part [SWAP]
sdb      8:16   0 931.5G  0 disk
`-sdb1   8:17   0 931.5G  0 part
sr0     11:0    1  1024M  0 rom
```

You can confirm that the physical disk has been passed through successfully.
