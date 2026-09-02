---
title: Build an OpenVPN Server on OpenWrt for Remote Access to Your Home Network
date: 2025-04-30T23:28:18+09:00
draft: false
tags:
  - OpenVPN
  - OpenWrt
  - VPN
params:
  toc: true
---

OpenVPN is an open-source VPN technology that provides an encrypted VPN tunnel and secure access to your home network while away. This article explains how to build an OpenVPN server on an OpenWrt router and connect multiple clients.

**Audience:** Users with OpenWrt installed and SSH access  
**Prerequisites:** [OpenWrt installation](/blog/install-friendlywrt-on-nanopi-r2s), administrator access, and basic terminal/SSH knowledge

## Environment

| Item | Value |
| --- | --- |
| OS | OpenWrt 24.10.0 or later |
| VPN protocol | OpenVPN UDP 1194 |
| VPN network | 10.8.0.0/24 |
| Encryption | AES-128-CBC |
| Authentication | SHA256 |
| CA validity | 3650 days (10 years) |
| Certificate validity | 825 days |

## Install the Packages

Update the OpenWrt package list and install the OpenVPN packages.

```bash
opkg update
opkg install openvpn-openssl openvpn-easy-rsa
```

| Package | Description |
| --- | --- |
| **openvpn-openssl** | Main OpenVPN package with SSL/TLS support |
| **openvpn-easy-rsa** | Tool for generating and managing the CA and certificates |
| **luci-app-openvpn** (optional) | Interface for managing OpenVPN in the LuCI web UI |
| **luci-i18n-openvpn-ja** (optional) | Japanese OpenVPN localization for LuCI |

## Set the Environment Variables

Edit `/etc/profile.d/50-openvpn-easy-rsa.sh` in a text editor.

```bash
# default PKI dir
export EASYRSA=${EASYRSA:-/etc/easy-rsa}
export EASYRSA_PKI=${EASYRSA_PKI:-$EASYRSA/pki}
export EASYRSA_VARS_FILE=${EASYRSA_VARS_FILE:-$EASYRSA/vars}
export EASYRSA_TEMP_DIR=${EASYRSA_TEMP_DIR:-${TMPDIR:-/tmp/}}
```

Save the file. The contents of profile.d are applied at login, so log in again or run `. /etc/profile.d/50-openvpn-easy-rsa.sh` to apply the settings. This sets the Easy-RSA base directory and PKI path in the environment variables.

## Build the Certificate Authority (CA)

Build the CA with Easy-RSA's `build-ca` command.

```
root@router:~# easyrsa build-ca

* Using Easy-RSA configuration:
  /etc/easy-rsa/vars

* Using SSL: openssl OpenSSL 3.0.16 11 Feb 2025 (Library: OpenSSL 3.0.16 11 Feb 2025)


Enter New CA Key Passphrase:<passphrase>

Confirm New CA Key Passphrase:<passphrase-confirmation>
Using configuration from /tmp//2f994ff4/temp.5.1
...omitted...
Enter PEM pass phrase:<passphrase>
Verifying - Enter PEM pass phrase:<passphrase-confirmation>
-----
You are about to be asked to enter information that will be incorporated
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN.
There are quite a few fields but you can leave some blank
For some fields there will be a default value,
If you enter '.', the field will be left blank.
-----
Common Name (eg: your user, host, or server name) [Easy-RSA CA]:<common-name>

Notice
------
CA creation complete. Your new CA certificate is at:
* /etc/easy-rsa/pki/ca.crt
```

This creates the CA certificate `ca.crt` in `/etc/easy-rsa/pki` and the CA private key `ca.key` in `/etc/easy-rsa/pki/private/`. Copy the CA certificate to `/etc/openvpn`.

```
root@router:~# cp /etc/easy-rsa/pki/ca.crt /etc/openvpn
```

The CA setup is complete.

## Create the Server Certificate and Private Key

Generate the server certificate and key with Easy-RSA's `build-server-full` command. In this example, the server is named `server`; `nopass` is used because no passphrase is configured.

```
root@router:~# easyrsa build-server-full <server-name> nopass

* Using Easy-RSA configuration:
  /etc/easy-rsa/vars

* Using SSL: openssl OpenSSL 3.0.16 11 Feb 2025 (Library: OpenSSL 3.0.16 11 Feb 2025)

...omitted...
-----

Notice
------
Keypair and certificate request completed. Your files are:
* req: /etc/easy-rsa/pki/reqs/<server-name>.req
* key: /etc/easy-rsa/pki/private/<server-name>.key

You are about to sign the following certificate.
Please check over the details shown below for accuracy. Note that this request
has not been cryptographically verified. Please be sure it came from a trusted
source or that you have verified the request checksum with the sender.

Request subject, to be signed as a server certificate
for '825' days:

subject=
    commonName                = <server-name>


Type the word 'yes' to continue, or any other input to abort.
  Confirm request details: yes

Using configuration from /tmp//d5a3377e/temp.4.1
Enter pass phrase for /etc/easy-rsa/pki/private/ca.key:<passphrase>
Check that the request matches the signature
Signature ok
The Subject's Distinguished Name is as follows
commonName            :ASN.1 12:'<server-name>'
Certificate is to be certified until Aug  4 09:43:06 2027 GMT (825 days)

Write out database with 1 new entries
Database updated

Notice
------
Certificate created at:
* /etc/easy-rsa/pki/issued/<server-name>.crt

Notice
------
Inline file created:
* /etc/easy-rsa/pki/inline/<server-name>.inline
```

This creates the server certificate `server.crt` in `/etc/easy-rsa/pki/issued` and the server private key `server.key` in `/etc/easy-rsa/pki/private/`. Move them to `/etc/openvpn`.

```
root@router:~# mv /etc/easy-rsa/pki/issued/server.crt /etc/easy-rsa/pki/private/server.key /etc/openvpn
```

## Generate the DH Parameters

Generate the random parameters required for encryption with Easy-RSA's `gen-dh` command.

```
root@router:~# easyrsa gen-dh

* Using Easy-RSA configuration:
  /etc/easy-rsa/vars

* Using SSL: openssl OpenSSL 3.0.16 11 Feb 2025 (Library: OpenSSL 3.0.16 11 Feb 2025)

Generating DH parameters, 2048 bit long safe prime
...omitted...
DH parameters appear to be ok.

Notice
------

DH parameters of size 2048 created at:
* /etc/easy-rsa/pki/dh.pem
```

After a while, `dh.pem` is created in `/etc/easy-rsa/pki`. Move it to `/etc/openvpn`.

```
root@router:~# mv /etc/easy-rsa/pki/dh.pem /etc/openvpn
```

## Generate the TLS-Auth Key

Generate a TLS-Auth key to use the TLS-Auth feature. It authenticates packets at the start of a VPN session with HMAC and discards unauthorized packets.

```
openvpn --genkey secret /etc/openvpn/ta.key
```

This creates `ta.key` in `/etc/openvpn`.

## Create the Server Configuration

Create `/etc/openvpn/server.conf` and configure routes for client connections.

```
port 1194
proto udp
dev tun

# SSL/TLS certificates and keys
ca /etc/openvpn/ca.crt
cert /etc/openvpn/server.crt
key /etc/openvpn/server.key
dh /etc/openvpn/dh.pem
tls-auth /etc/openvpn/ta.key 0

# VPN client network
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist /var/lib/openvpn/ipp.txt

# Push a route to the home network to VPN clients
push "route 192.168.1.0 255.255.255.0"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"

# Encryption and authentication
cipher AES-128-CBC
auth SHA256
tls-version-min 1.2

# Keepalive and logging
keepalive 10 120
user nobody
persist-key
persist-tun
status /var/log/openvpn-status.log
log /var/log/openvpn.log
verb 3
explicit-exit-notify 1
```

| Parameter | Value | Description |
| --- | --- | --- |
| `port` | 1194 | UDP port on which OpenVPN listens |
| `proto` | udp | Protocol (UDP or TCP) |
| `dev` | tun | VPN tunnel device |
| `server` | 10.8.0.0/24 | IP address range for VPN clients |
| `push "route ..."` | 192.168.1.0/24 | Notifies clients of the route to the home LAN |
| `push "dhcp-option DNS"` | 8.8.8.8 | DNS server used by clients |
| `cipher` | AES-128-CBC | Encryption method |
| `auth` | SHA256 | HMAC authentication algorithm |
| `tls-version-min` | 1.2 | Minimum TLS version |
| `keepalive` | 10 120 | Sends keepalives every 10 seconds and considers the connection lost after 120 seconds without a response |
| `user nobody` | - | Runs OpenVPN as an unprivileged user |
| `persist-key` | - | Retains key files when restarting |
| `persist-tun` | - | Retains the virtual interface when restarting |
| `status` | `/var/log/openvpn-status.log` | Log of connected clients |
| `verb` | 3 | Log detail level |

### Check the Home LAN Address

Change `push "route 192.168.1.0 255.255.255.0"` to the address range of your home network. Check it with the following command.

```bash
root@router:~# ip a

# Example output
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP qlen 1000
    link/ether xx:xx:xx:xx:xx:xx brd ff:ff:ff:ff:ff:ff
    inet 192.168.1.1/24 bcast 192.168.1.255 scope global eth0
       valid_lft forever preferred_lft forever
```

In this example, the home LAN is `192.168.1.0/24`. Replace it with the address used in your environment.

## Start and Verify the OpenVPN Server

Start OpenVPN after saving the server configuration.

```bash
root@router:~# /etc/init.d/openvpn start
root@router:~# /etc/init.d/openvpn status
running
root@router:~# /etc/init.d/openvpn enable
```

Check that port 1194 is listening.

```bash
root@router:~# netstat -tlnup | grep 1194

# Example output
udp        0      0 0.0.0.0:1194            0.0.0.0:*                           1234/openvpn
```

The setup is successful if the `openvpn` process is listening on port 1194.

## Add the Network Interface

Check the tun device added by OpenVPN.

```
root@router:~# ip a
...omitted...
12: tun0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UNKNOWN qlen 500
    link/[65534]
    inet 10.8.0.1 peer 10.8.0.2/32 scope global tun0
       valid_lft forever preferred_lft forever
    inet6 fe80::7ef9:4674:b626:2a37/64 scope link flags 800
       valid_lft forever preferred_lft forever
...omitted...
```

The device named `tun0` has been added. Add it to the network interfaces as `vpn` by appending the following to `/etc/config/network`.

```
config interface 'vpn'
    option proto 'none'
    option ifname 'tun0'
```

Restart the network.

```
root@router:~# service network restart
```

## Configure the Firewall

Edit `/etc/config/firewall`. Place the `vpn` interface in the same zone as `lan` by adding `list network 'vpn'` to the `lan` zone.

```bash
config zone
    option name 'lan'
    option input 'ACCEPT'
    option output 'ACCEPT'
    option forward 'ACCEPT'
    list network 'lan'
    list network 'vpn'
```

Add a rule to allow OpenVPN connections from `wan`.

```bash
config rule
        option name 'Allow-OpenVPN'
        option src 'wan'
        option dest_port '1194'
        option proto 'udp'
        option target 'ACCEPT'
```

Restart the firewall.

```
root@router:~# service firewall restart
```

## Create a Client Certificate and Private Key

Generate the client certificate and key with Easy-RSA's `build-client-full` command. In this example, the client is named `client` and uses `nopass`.

```
root@router:~# easyrsa build-client-full <client-name> nopass

* Using Easy-RSA configuration:
  /etc/easy-rsa/vars

* Using SSL: openssl OpenSSL 3.0.16 11 Feb 2025 (Library: OpenSSL 3.0.16 11 Feb 2025)

...omitted...
-----

Notice
------
Keypair and certificate request completed. Your files are:
* req: /etc/easy-rsa/pki/reqs/<client-name>.req
* key: /etc/easy-rsa/pki/private/<client-name>.key

You are about to sign the following certificate.
Please check over the details shown below for accuracy. Note that this request
has not been cryptographically verified. Please be sure it came from a trusted
source or that you have verified the request checksum with the sender.

Request subject, to be signed as a client certificate
for '825' days:

subject=
    commonName                = <client-name>


Type the word 'yes' to continue, or any other input to abort.
  Confirm request details: yes

Using configuration from /tmp//23e0cc20/temp.4.1
Enter pass phrase for /etc/easy-rsa/pki/private/ca.key:
Check that the request matches the signature
Signature ok
The Subject's Distinguished Name is as follows
commonName            :ASN.1 12:'<client-name>'
Certificate is to be certified until Aug  5 10:10:15 2027 GMT (825 days)

Write out database with 1 new entries
Database updated

Notice
------
Certificate created at:
* /etc/easy-rsa/pki/issued/<client-name>.crt

Notice
------
Inline file created:
* /etc/easy-rsa/pki/inline/<client-name>.inline
```

This creates `client.crt` in `/etc/easy-rsa/pki/issued` and `client.key` in `/etc/easy-rsa/pki/private/`.

## Create and Place the Client Configuration

Create a client configuration file (`.ovpn`) using the certificate and key generated by Easy-RSA.

Copy the client files generated on the server to `/tmp`.

```bash
root@router:~# cp /etc/easy-rsa/pki/issued/client.crt /tmp/
root@router:~# cp /etc/easy-rsa/pki/private/client.key /tmp/
root@router:~# cp /etc/openvpn/ca.crt /tmp/
root@router:~# cp /etc/openvpn/ta.key /tmp/
```

Create `client.ovpn` with the following template.

```
client
dev tun
proto udp
remote <OpenWrt-global-IP-address> 1194
resolv-retry infinite
nobind

# Security settings
remote-cert-tls server
cipher AES-128-CBC
auth SHA256
tls-version-min 1.2
tls-auth ta.key 1

# Client logging
persist-key
persist-tun
verb 3

# CA certificate (inline)
<ca>
-----BEGIN CERTIFICATE-----
(Paste the contents of /etc/openvpn/ca.crt here)
-----END CERTIFICATE-----
</ca>

# Client certificate (inline)
<cert>
-----BEGIN CERTIFICATE-----
(Paste the contents of /etc/easy-rsa/pki/issued/client.crt here)
-----END CERTIFICATE-----
</cert>

# Client private key (inline)
<key>
-----BEGIN PRIVATE KEY-----
(Paste the contents of /etc/easy-rsa/pki/private/client.key here)
-----END PRIVATE KEY-----
</key>

# TLS-Auth key
<tls-auth>
(Paste the contents of /etc/openvpn/ta.key here)
</tls-auth>
```

Display and copy each file's contents on the server with the following commands.

```bash
root@router:~# cat /etc/openvpn/ca.crt
root@router:~# cat /etc/easy-rsa/pki/issued/client.crt
root@router:~# cat /etc/easy-rsa/pki/private/client.key
root@router:~# cat /etc/openvpn/ta.key
```

Paste each output into the corresponding section of the `.ovpn` file.

For a fixed global IP, use `remote 203.0.113.1 1194`; for a dynamic IP, use a DDNS hostname such as `remote example.ddns.jp 1194`.

## Test Connections from Clients

Transfer `client.ovpn` to the client and test the connection.

### Linux and macOS

```bash
# Ubuntu/Debian
sudo apt install openvpn

# macOS (Homebrew)
brew install openvpn

sudo openvpn --config client.ovpn
```

A successful connection displays `Initialization Sequence Completed`. In another terminal, run `ip a` and confirm `tun0`, then use `ping 192.168.1.1` to test routing to the home network. Press `Ctrl+C` to disconnect.

### Windows

1. Download OpenVPN GUI from the [official OpenVPN download page](https://openvpn.net/download-open-vpn/) and install it with the default settings.
2. Copy `client.ovpn` to `C:\Users\<username>\OpenVPN\config\`.
3. Launch OpenVPN GUI, right-click its taskbar icon, select `client.ovpn`, and select Connect.
4. In PowerShell, run `ipconfig` and confirm that a `10.8.0.x` address was assigned to the TAP-Win32 Adapter for OpenVPN. Test with `ping 192.168.1.1`.

### iOS and Android

Install OpenVPN Connect from the App Store or Google Play, transfer `client.ovpn` to the device, import it in the app, and tap the imported connection profile to connect.

## Troubleshooting

| Problem | Cause | Solution |
| --- | --- | --- |
| **Timeout while connecting** | Insufficient firewall or router configuration | Check the [firewall configuration](#configure-the-firewall) and port forwarding |
| **Authentication error (TLS Handshake failed)** | Certificate or key mismatch | Recheck the `<ca>`, `<cert>`, and `<key>` sections |
| **Cannot reach the home network** | Invalid `push "route ..."` setting | Confirm that the server's `push "route"` matches the home LAN address |
| **DNS does not work** | DNS settings are not being sent | Check `push "dhcp-option DNS"` or configure DNS manually on the client |
| **No internet access after VPN connection** | Conflicting default route | Add `redirect-gateway def1` to `client.ovpn` |

Check server logs with `tail -f /var/log/openvpn.log` and `cat /var/log/openvpn-status.log`. For verbose client logs, use `--verb 4` with OpenVPN.

## Dynamic IP Support (DDNS)

If the OpenWrt external IP address changes, use DDNS so clients can connect by hostname.

[Automatically Update DNS Records on OpenWrt with DDNS](/blog/automatically-update-dns-records-for-onamae-com-from-openwrt-with-ddns-using-ddns-scripts-onamae)

Change the `remote` parameter to the DDNS hostname.

```
# Before (global IP address)
remote 203.0.113.1 1194

# After (DDNS hostname)
remote myhome.ddns.jp 1194
```

## Security Recommendations

### Renew Certificates Regularly

Generated certificates are valid for 825 days. Generate and deploy new certificates regularly.

```bash
openssl x509 -in /etc/openvpn/server.crt -noout -text | grep -A2 "Validity"
```

### Check Firewall Settings

```bash
# UFW
sudo ufw allow 1194/udp

# iptables
sudo iptables -A INPUT -p udp --dport 1194 -j ACCEPT
```

### Add PAM Authentication (Optional)

To add password authentication, add the following to `server.conf`.

```
auth-user-pass-verify /etc/openvpn/checkpsw.sh via-env
script-security 3
username-as-common-name
```

## Related Articles and External Links

- [OpenVPN installation on OpenWrt (official documentation)](https://openwrt.org/docs/guide_user/services/vpn/openvpn/server)
- [OpenWrt Wiki - OpenVPN](https://openwrt.org/docs/guide_user/services/vpn/openvpn/start)
- [OpenWrt installation](/blog/install-friendlywrt-on-nanopi-r2s)
- [Build a VPN server with WireGuard](/blog/set-up-a-vpn-server-on-openwrt-using-wireguard-to-access-the-home-network-from-outside)
- [Configure DDNS on OpenWrt](/blog/automatically-update-dns-records-for-onamae-com-from-openwrt-with-ddns-using-ddns-scripts-onamae)
- [How to generate an SSH key](/blog/generate-ssh-key)
- [OpenSSL documentation](https://www.openssl.org/docs/)
- [NIST cryptographic recommendations](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-38A.pdf)
