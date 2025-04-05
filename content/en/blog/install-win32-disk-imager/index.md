---
title: Install and Using Win32 Disk Imager
date: 2024-09-29T21:30:39+09:00
draft: false
tags:
  - Win32 Disk Imager
params:
  toc: true
---

Win32 Disk Imager is a disk imaging tool for Windows.

This guide explains how to install and use Win32 Disk Imager.

## What is Win32 Disk Imager?

Win32 Disk Imager is a Windows tool for writing disk images to SD cards and USB drives. It supports disk images in IMG format.

![Win32 Disk Imager](images/win32-disk-imager.webp)

With this tool, you can write a disk image to a removable drive or save the contents of a removable drive as an image file.

This tool is open-source, and you can download and use it for free.

## Win32 Disk Imagerのインストール

Download the installer for Win32 Disk Imager from the [official website](https://sourceforge.net/projects/win32diskimager/), and once the download is complete, run the installer to install the tool.

During installation, you may be asked about the installation location and shortcut creation, but you can proceed with the default settings if no specific preferences are needed.

## Write a Disk Image

Write a disk image to an SD card or USB drive.

![Win32 Disk Imager](images/win32-disk-imager-write.webp)

In the "Image File" field, specify the image file you want to write, and select the target drive from "Device." Click "Write" to start the writing process.

## Read a Disk Image

Read a disk image from an SD card or USB drive.

![Win32 Disk Imager](images/win32-disk-imager-read.webp)

Specify the save location for the image file in the "Image File" field, and select the drive you want to read from under "Device." Click "Read" to start the reading process.

## Calculate Hash Values

Calculate the hash value of an image file. This allows you to compare it with the hash value provided by the image file’s source to check for corruption or tampering.

![Win32 Disk Imager](images/win32-disk-imager-hash.webp)

Specify the image file in the "Image File" field for which you want to calculate the hash, and select an algorithm from "Hash." Click "Generate" to display the hash value.

Available hash algorithms are MD5, SHA1, and SHA256.
