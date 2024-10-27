---
title: How to Generate an SSH Key
date: 2024-09-29T19:51:46+09:00
draft: false
params:
  toc: true
---

SSH is a protocol for securely logging into remote computers, transferring files, and executing commands over a network. It encrypts communications, preventing eavesdropping and ensuring security.

This guide explains how to generate keys for use with SSH.

## Setting the Encryption Algorithm and Key Length

You can generate a key using the `ssh-keygen` command. The following example generates a key using the RSA encryption algorithm with a key length of 4096.

```
ssh-keygen -t rsa -b 4096
```

The encryption algorithm can be specified with the `-t` option. Available algorithms include:

- RSA
- DSA
- ECDSA
- Ed25519

The key length can be specified with the `-b` option.

## Setting the Save Location and File Name

```
Enter file in which to save the key (<home-directory>/.ssh/id_rsa): [<save-location-and-file-name>]
```

You will be prompted to enter a save location and file name for the key. Press Enter to accept the default location if you do not wish to specify one.

## Setting the Passphrase

```
Enter passphrase (empty for no passphrase): [<passphrase>]
Enter same passphrase again: [<passphrase>]
```

You will be prompted to set a passphrase. Setting a passphrase protects the private key. If you do not want to set a passphrase, simply press Enter.

## Key Generation

```
Your identification has been saved in <path-to-private-key>.
Your public key has been saved in <path-to-public-key>.
The key fingerprint is:
<display-fingerprint>
The key's randomart image is:
<display-randomart-image>
```

If you see this message, the key generation is complete. By default, a private key named `id_rsa` and a public key named `id_rsa.pub` will be created in the `.ssh` directory. By registering the public key on the remote host, you can establish secure SSH connections.
