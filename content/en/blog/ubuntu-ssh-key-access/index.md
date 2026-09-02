---
title: Connect to Ubuntu over SSH Using Public Key Authentication
date: 2025-03-06T22:45:49+09:00
draft: false
tags:
  - Ubuntu
  - SSH
params:
  toc: true
---

When connecting to Ubuntu over SSH, using public key authentication instead of password authentication can improve security. This article explains how to configure SSH public key authentication.

## Generate a Public and Private Key Pair

First, generate an SSH key pair on the client. In this example, the ED25519 key algorithm is used.

```
ssh-keygen -t ed25519
```

The following page explains how to generate SSH keys in detail.

[How to Generate an SSH Key](/blog/generate-ssh-key)

When you run the command above, the private and public keys are generated in the `~/.ssh/` directory.

## Copy the Public Key to the Server

Copy the public key you generated to the SSH server.

```
ssh-copy-id <username>@<hostname> -i <path-to-public-key>
```

Alternatively, you can manually add the public key contents to the server's `~/.ssh/authorized_keys` file.

## Change the SSH Configuration

For improved security, disable SSH connections using passwords so that connections can be made only with public key authentication.

To change the SSH configuration, edit the server's `/etc/ssh/sshd_config` file with a text editor. Check and change the following settings.

```
PubkeyAuthentication yes
PasswordAuthentication no
```

Restart SSH to apply the changes.

```
sudo systemctl restart ssh
```

## Verify the SSH Connection

Try connecting over SSH from the client.

```
ssh <username>@<hostname> -i <path-to-private-key>
```

If you can log in, the public key authentication setup is complete.
