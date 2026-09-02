---
title: OpenWrtでOpenVPNサーバーを構築し、外部から自宅ネットワークにアクセスする
date: 2025-04-30T23:28:18+09:00
draft: false
tags:
  - OpenVPN
  - OpenWrt
  - VPN
params:
  toc: true
---

## はじめに

OpenVPNは暗号化されたVPNトンネルを提供し、外出先から自宅ネットワークに安全にアクセスできるオープンソースのVPN技術です。本記事では、OpenWrtルーター上にOpenVPNサーバーを構築し、複数のクライアントから接続する手順を詳しく解説します。

**対象者：** OpenWrtがインストール済みで、SSH接続が可能なユーザー  
**前提条件：** [OpenWrtのインストール](/blog/install-friendlywrt-on-nanopi-r2s)、管理者権限での操作、ターミナル/SSH接続の基本知識

## 環境情報

| 項目 | 値 |
|------|-----|
| OS | OpenWrt 24.10.0 以降 |
| VPN プロトコル | OpenVPN UDP 1194 |
| VPN ネットワーク | 10.8.0.0/24 |
| 暗号化方式 | AES-128-CBC |
| 認証方式 | SHA256 |
| 認証局有効期限 | 3650 日（10 年） |
| 証明書有効期限 | 825 日 |


## パッケージのインストール

まず、OpenWrtのパッケージリストを更新し、OpenVPN関連パッケージをインストールします。

```bash
opkg update
opkg install openvpn-openssl openvpn-easy-rsa
```

**インストール内容：**

| パッケージ | 説明 |
|-----------|------|
| **openvpn-openssl** | OpenVPNメインパッケージ（SSL/TLS対応） |
| **openvpn-easy-rsa** | CA（認証局）と証明書を生成・管理するツール |
| **luci-app-openvpn**（オプション） | LuCI WebUIでOpenVPNを管理するインターフェース |
| **luci-i18n-openvpn-ja**（オプション） | LuCIのOpenVPN日本語ローカライズ |


## 環境変数の設定

テキストエディタで`/etc/profile.d/50-openvpn-easy-rsa.sh`を編集します。

```bash
# default PKI dir
export EASYRSA=${EASYRSA:-/etc/easy-rsa}
export EASYRSA_PKI=${EASYRSA_PKI:-$EASYRSA/pki}
export EASYRSA_VARS_FILE=${EASYRSA_VARS_FILE:-$EASYRSA/vars}
export EASYRSA_TEMP_DIR=${EASYRSA_TEMP_DIR:-${TMPDIR:-/tmp/}}
```

編集して保存しましょう。profile.dの内容はログイン時に適用されるため、再度ログインしなおすか、`. /etc/profile.d/50-openvpn-easy-rsa.sh`と打って設定を適用させましょう。これにより、easy-rsaのベースディレクトリやpkiフォルダのパスが環境変数に設定されます。

## 証明書認証局(CA)の構築

Easy-RSAの`build-ca`コマンドで証明書認証局(CA)を構築します。

```
root@router:~# easyrsa build-ca

* Using Easy-RSA configuration:
  /etc/easy-rsa/vars

* Using SSL: openssl OpenSSL 3.0.16 11 Feb 2025 (Library: OpenSSL 3.0.16 11 Feb 2025)


Enter New CA Key Passphrase:<パスフレーズ>

Confirm New CA Key Passphrase:<パスフレーズ(確認用)>
Using configuration from /tmp//2f994ff4/temp.5.1
...省略...
Enter PEM pass phrase:<パスフレーズ>
Verifying - Enter PEM pass phrase:<パスフレーズ(確認用)>
-----
You are about to be asked to enter information that will be incorporated
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN.
There are quite a few fields but you can leave some blank
For some fields there will be a default value,
If you enter '.', the field will be left blank.
-----
Common Name (eg: your user, host, or server name) [Easy-RSA CA]:<コモンネーム>

Notice
------
CA creation complete. Your new CA certificate is at:
* /etc/easy-rsa/pki/ca.crt
```

これにより、`/etc/easy-rsa/pki`ディレクトリにCA証明書`ca.crt`と、`/etc/easy-rsa/pki/private/`ディレクトリにCA秘密鍵`ca.key`が生成されます。CA証明書を`/etc/openvpn`ディレクトリにコピーしましょう。

```
root@router:~# cp /etc/easy-rsa/pki/ca.crt /etc/openvpn
```

CAの構築は以上で完了です。

## サーバー証明書と秘密鍵の作成

Easy-RSAの`build-server-full`コマンドでサーバー証明書と鍵を生成します。

任意のサーバー名を指定して証明書と鍵を生成します。ここではサーバー名は`server`としました。パスフレーズは設定しないため`nopass`オプションを設定します。

```
root@router:~# easyrsa build-server-full <サーバー名> nopass

* Using Easy-RSA configuration:
  /etc/easy-rsa/vars

* Using SSL: openssl OpenSSL 3.0.16 11 Feb 2025 (Library: OpenSSL 3.0.16 11 Feb 2025)

...省略...
-----

Notice
------
Keypair and certificate request completed. Your files are:
* req: /etc/easy-rsa/pki/reqs/<サーバー名>.req
* key: /etc/easy-rsa/pki/private/<サーバー名>.key

You are about to sign the following certificate.
Please check over the details shown below for accuracy. Note that this request
has not been cryptographically verified. Please be sure it came from a trusted
source or that you have verified the request checksum with the sender.

Request subject, to be signed as a server certificate
for '825' days:

subject=
    commonName                = <サーバー名>


Type the word 'yes' to continue, or any other input to abort.
  Confirm request details: yes

Using configuration from /tmp//d5a3377e/temp.4.1
Enter pass phrase for /etc/easy-rsa/pki/private/ca.key:<パスフレーズ>
Check that the request matches the signature
Signature ok
The Subject's Distinguished Name is as follows
commonName            :ASN.1 12:'<サーバー名>'
Certificate is to be certified until Aug  4 09:43:06 2027 GMT (825 days)

Write out database with 1 new entries
Database updated

Notice
------
Certificate created at:
* /etc/easy-rsa/pki/issued/<サーバー名>.crt

Notice
------
Inline file created:
* /etc/easy-rsa/pki/inline/<サーバー名>.inline
```

これにより、`/etc/easy-rsa/pki/issued`ディレクトリにサーバー証明書`server.crt`と、`/etc/easy-rsa/pki/private/`ディレクトリにサーバー秘密鍵`server.key`が生成されます。サーバー証明書と秘密鍵を`/etc/openvpn`ディレクトリに移動しましょう。

```
root@router:~# mv /etc/easy-rsa/pki/issued/server.crt /etc/easy-rsa/pki/private/server.key /etc/openvpn
```

以上でサーバー証明書と秘密鍵の作成は完了です。

## DHパラメータの生成

Easy-Rsaの`gen-dh`コマンドを使って、暗号化に必要な乱数パラメータを生成します。

```
root@router:~# easyrsa gen-dh

* Using Easy-RSA configuration:
  /etc/easy-rsa/vars

* Using SSL: openssl OpenSSL 3.0.16 11 Feb 2025 (Library: OpenSSL 3.0.16 11 Feb 2025)

Generating DH parameters, 2048 bit long safe prime
...省略...
DH parameters appear to be ok.

Notice
------

DH parameters of size 2048 created at:
* /etc/easy-rsa/pki/dh.pem
```

しばらく待つと、`/etc/easy-rsa/pki`ディレクトリにDHパラメータ`dh.pem`が生成されます。DHパラメータを`/etc/openvpn`ディレクトリに移動しましょう。

```
root@router:~# mv /etc/easy-rsa/pki/dh.pem /etc/openvpn
```

以上でDHパラメータの生成は完了です。

## TLS-Authキーの生成

TLS-Auth機能を使用するためTLS-Authキーを生成します。

TLS-Auth機能を有効化すると、VPNセッション開始時のパケットをHMACで認証し、認可されないパケットを破棄することができます。

```
openvpn --genkey secret /etc/openvpn/ta.key
```

これにより、`/etc/openvpn`ディレクトリにTLS-Authキー`ta.key`が生成されます。

## サーバー設定ファイルの作成

OpenVPNのサーバー設定ファイルを作成し、クライアント接続時のルート設定を行います。

テキストエディタで`/etc/openvpn/server.conf`を新規作成し、以下の内容を記載します：

```
port 1194
proto udp
dev tun

# SSL/TLS証明書と鍵
ca /etc/openvpn/ca.crt
cert /etc/openvpn/server.crt
key /etc/openvpn/server.key
dh /etc/openvpn/dh.pem
tls-auth /etc/openvpn/ta.key 0

# VPNクライアント用ネットワーク設定
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist /var/lib/openvpn/ipp.txt

# VPNクライアントに自宅ネットワークへのルートをpush
push "route 192.168.1.0 255.255.255.0"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"

# 暗号化と認証
cipher AES-128-CBC
auth SHA256
tls-version-min 1.2

# 接続継続とログ設定
keepalive 10 120
user nobody
persist-key
persist-tun
status /var/log/openvpn-status.log
log /var/log/openvpn.log
verb 3
explicit-exit-notify 1
```

### 設定パラメータの説明

| パラメータ | 値 | 説明 |
|-----------|-----|------|
| `port` | 1194 | OpenVPNが待機するUDPポート |
| `proto` | udp | プロトコル（UDPまたはTCP） |
| `dev` | tun | VPN用のトンネルデバイス |
| `server` | 10.8.0.0/24 | VPNクライアント用のIPアドレス範囲 |
| `push "route ..."` | 192.168.1.0/24 | クライアントに自宅LANへのルートを通知 |
| `push "dhcp-option DNS"` | 8.8.8.8 | クライアント側で使用するDNSサーバー |
| `cipher` | AES-128-CBC | 通信を暗号化する方式 |
| `auth` | SHA256 | HMAC認証アルゴリズム |
| `tls-version-min` | 1.2 | TLS最低バージョン（セキュリティ向上） |
| `keepalive` | 10 120 | 10秒ごとにキープアライブを送信、120秒以上受信なければ切断判定 |
| `user nobody` | - | OpenVPNプロセスを非特権ユーザーで実行（セキュリティ向上） |
| `persist-key` | - | プロセス再起動時にキーファイルを保持 |
| `persist-tun` | - | プロセス再起動時に仮想インターフェースを保持 |
| `status` | `/var/log/openvpn-status.log` | 接続中のクライアント一覧ログ |
| `verb` | 3 | ログ詳細度（3=詳細、4以上=さらに詳細） |

### 自宅LANアドレスの確認

`push "route 192.168.1.0 255.255.255.0"`の部分は、ご自身の自宅ネットワークのアドレス範囲に変更してください。自宅LANアドレスを確認するには：

```bash
root@router:~# ip a

# 出力例
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP qlen 1000
    link/ether xx:xx:xx:xx:xx:xx brd ff:ff:ff:ff:ff:ff
    inet 192.168.1.1/24 bcast 192.168.1.255 scope global eth0
       valid_lft forever preferred_lft forever
```

このように表示される場合、自宅LANは`192.168.1.0/24`です。異なる場合はそのアドレスに置き換えてください。

## OpenVPNサーバーの起動と確認

サーバー設定ファイルを保存後、OpenVPNサーバーを起動します。

```bash
root@router:~# /etc/init.d/openvpn start
```

OpenVPNサーバーが起動したことを確認します：

```bash
root@router:~# /etc/init.d/openvpn status
running
```

次回のルーター起動時にOpenVPNが自動起動されるよう設定します：

```bash
root@router:~# /etc/init.d/openvpn enable
```

ポート1194が正しくリッスンしているか確認します：

```bash
root@router:~# netstat -tlnup | grep 1194

# 出力例
udp        0      0 0.0.0.0:1194            0.0.0.0:*                           1234/openvpn
```

`openvpn`プロセスがポート1194でリッスン中であることが確認できれば成功です。

## ネットワークインターフェースの追加

`ip`コマンドで先ほど追加されたtunデバイスの確認をします。

```
root@router:~# ip a
...省略...
12: tun0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UNKNOWN qlen 500
    link/[65534]
    inet 10.8.0.1 peer 10.8.0.2/32 scope global tun0
       valid_lft forever preferred_lft forever
    inet6 fe80::7ef9:4674:b626:2a37/64 scope link flags 800
       valid_lft forever preferred_lft forever
...省略...
```

`tun0`という名前のデバイスが追加されていることが確認できました。これを`vpn`という名前でネットワークインターフェースに追加します。

テキストエディタで`/etc/config/network`を開き、以下の内容を追記しましょう。

```
config interface 'vpn'
    option proto 'none'
    option ifname 'tun0'
```

保存してネットワークを再起動しましょう。

```
root@router:~# service network restart
```

## ファイアウォールの設定

テキストエディタで`/etc/config/firewall`を開き、ファイアウォールの設定を変更します。

まずは、先ほど追加したネットワークインターフェース`vpn`を`lan`と同じゾーンに配置します。以下は設定例です。`lan`ゾーンに`list network 'vpn'`の行を追加しました。

```bash
config zone
    option name 'lan'
    option input 'ACCEPT'
    option output 'ACCEPT'
    option forward 'ACCEPT'
    list network 'lan'
    list network 'vpn'
```

次に、`wan`側からOpenVPNの接続を許可するようルールを追加します。

```bash
config rule
        option name 'Allow-OpenVPN'
        option src 'wan'
        option dest_port '1194'
        option proto 'udp'
        option target 'ACCEPT'
```

保存してファイアウォールを再起動しましょう。

```
root@router:~# service firewall restart
```

## クライアント証明書と秘密鍵の作成

Easy-RSAの`build-client-full`コマンドでサーバー証明書と鍵を生成します。

任意のクライアント名を指定して証明書と秘密鍵を生成します。ここではクライアント名は`client`としました。パスフレーズは設定しないため`nopass`オプションを設定します。

```
root@router:~# easyrsa build-client-full <クライアント名> nopass

* Using Easy-RSA configuration:
  /etc/easy-rsa/vars

* Using SSL: openssl OpenSSL 3.0.16 11 Feb 2025 (Library: OpenSSL 3.0.16 11 Feb 2025)

...省略...
-----

Notice
------
Keypair and certificate request completed. Your files are:
* req: /etc/easy-rsa/pki/reqs/<クライアント名>.req
* key: /etc/easy-rsa/pki/private/<クライアント名>.key

You are about to sign the following certificate.
Please check over the details shown below for accuracy. Note that this request
has not been cryptographically verified. Please be sure it came from a trusted
source or that you have verified the request checksum with the sender.

Request subject, to be signed as a client certificate
for '825' days:

subject=
    commonName                = <クライアント名>


Type the word 'yes' to continue, or any other input to abort.
  Confirm request details: yes

Using configuration from /tmp//23e0cc20/temp.4.1
Enter pass phrase for /etc/easy-rsa/pki/private/ca.key:
Check that the request matches the signature
Signature ok
The Subject's Distinguished Name is as follows
commonName            :ASN.1 12:'<クライアント名>'
Certificate is to be certified until Aug  5 10:10:15 2027 GMT (825 days)

Write out database with 1 new entries
Database updated

Notice
------
Certificate created at:
* /etc/easy-rsa/pki/issued/<クライアント名>.crt

Notice
------
Inline file created:
* /etc/easy-rsa/pki/inline/<クライアント名>.inline
```

これにより、`/etc/easy-rsa/pki/issued`ディレクトリにクライアント証明書`client.crt`と、`/etc/easy-rsa/pki/private/`ディレクトリにクライアント秘密鍵`client.key`が生成されます。

## クライアント設定ファイルの生成と配置

Easy-RSAで生成したクライアント証明書・鍵を使用して、クライアント設定ファイル（.ovpn）を作成します。

サーバー側で生成したクライアント用ファイルを`/tmp`にコピーします：

```bash
root@router:~# cp /etc/easy-rsa/pki/issued/client.crt /tmp/
root@router:~# cp /etc/easy-rsa/pki/private/client.key /tmp/
root@router:~# cp /etc/openvpn/ca.crt /tmp/
root@router:~# cp /etc/openvpn/ta.key /tmp/
```

クライアント設定ファイル`client.ovpn`を作成します。以下のテンプレートをテキストエディタで新規作成してください：

```
client
dev tun
proto udp
remote <OpenWrtのグローバルIPアドレス> 1194
resolv-retry infinite
nobind

# セキュリティ設定
remote-cert-tls server
cipher AES-128-CBC
auth SHA256
tls-version-min 1.2
tls-auth ta.key 1

# クライアント側ログ設定
persist-key
persist-tun
verb 3

# CA証明書（インライン方式）
<ca>
-----BEGIN CERTIFICATE-----
（/etc/openvpn/ca.crtの内容をここに貼り付け）
-----END CERTIFICATE-----
</ca>

# クライアント証明書（インライン方式）
<cert>
-----BEGIN CERTIFICATE-----
（/etc/easy-rsa/pki/issued/client.crtの内容をここに貼り付け）
-----END CERTIFICATE-----
</cert>

# クライアント秘密鍵（インライン方式）
<key>
-----BEGIN PRIVATE KEY-----
（/etc/easy-rsa/pki/private/client.keyの内容をここに貼り付け）
-----END PRIVATE KEY-----
</key>

# TLS-Authキー
<tls-auth>
（/etc/openvpn/ta.keyの内容をここに貼り付け）
</tls-auth>
```

### 証明書・鍵の内容をコピーする手順

サーバー上で、各ファイルをテキストエディタで開いて内容をコピーします：

```bash
# CA証明書の表示
root@router:~# cat /etc/openvpn/ca.crt

# クライアント証明書の表示
root@router:~# cat /etc/easy-rsa/pki/issued/client.crt

# クライアント秘密鍵の表示
root@router:~# cat /etc/easy-rsa/pki/private/client.key

# TLS-Authキーの表示
root@router:~# cat /etc/openvpn/ta.key
```

各出力内容を、.ovpnファイルの対応するセクション（`<ca>...</ca>`など）に貼り付けてください。

### クライアント接続情報の設定

`client.ovpn`の`remote`パラメータを以下のように設定してください：

| 状況 | 設定値 |
|------|-------|
| **グローバルIPアドレスが固定** | `remote 203.0.113.1 1194`（実際のIPに置換） |
| **動的IP（DDNS使用）** | `remote example.ddns.jp 1194`（DDNSホスト名に置換） |

## クライアント側での接続テスト

作成した`client.ovpn`ファイルをクライアント側に転送して、接続テストを行います。

### Linux/Macでの接続

OpenVPNクライアントをインストール（未インストールの場合）：

```bash
# Ubuntu/Debian
sudo apt install openvpn

# macOS (Homebrew)
brew install openvpn
```

接続テスト実行：

```bash
sudo openvpn --config client.ovpn

# 接続成功時の出力例
Sat Sep  2 10:15:00 2024 TUN/TAP device tun0 opened
Sat Sep  2 10:15:00 2024 do_ifconfig, tt->ipv6=0, tt->link_mtu=1500
Sat Sep  2 10:15:00 2024 /sbin/ip addr add dev tun0 10.8.0.6/255.255.255.0
Sat Sep  2 10:15:01 2024 Initialization Sequence Completed
```

接続確認：

```bash
# 別のターミナルで実行
ip a
# tun0が表示される

# 自宅ネットワークへのルーティング確認
ping 192.168.1.1  # ルーターのLANアドレスに疎通確認
```

接続を終了：

```bash
# Ctrl+C キーを押す
```

### Windowsでの接続

1. **OpenVPN GUIをインストール**
   - [OpenVPN公式ダウンロードページ](https://openvpn.net/download-open-vpn/)からOpenVPN GUIをダウンロード
   - インストーラーを実行し、デフォルト設定でインストール

2. **クライアント設定ファイルの配置**
   - `client.ovpn`ファイルを`C:\Users\<ユーザー名>\OpenVPN\config\`にコピー

3. **OpenVPN GUIの起動と接続**
   - スタートメニューから「OpenVPN GUI」を起動
   - タスクバーのOpenVPNアイコンを右クリック
   - `client.ovpn`を選択して「接続」をクリック

4. **接続確認**
   - Windows PowerShellで実行：
   ```powershell
   ipconfig
   # TAP-Win32 Adapter for OpenVPN から 10.8.0.x のアドレスが付与されているか確認
   
   ping 192.168.1.1  # 自宅ルーターに疎通確認
   ```

### iOS/Androidでの接続（OpenVPN Connectアプリ）

1. **アプリインストール**
   - App Store/Google Playで「OpenVPN Connect」をインストール

2. **クライアント設定ファイルの転送**
   - `client.ovpn`をメール添付またはクラウドストレージ経由でデバイスに転送

3. **アプリで設定ファイルをインポート**
   - OpenVPN Connectを起動
   - ファイルブラウザから`client.ovpn`を選択
   - 「インポート」をタップ

4. **接続**
   - インポートされた接続プロフィールをタップして接続

## トラブルシューティング

接続がうまくいかない場合の対処方法：

| 問題 | 原因 | 対処方法 |
|------|------|--------|
| **接続時にタイムアウト** | ファイアウォール設定不足またはルーターの設定不足 | [ファイアウォール設定](#ファイアウォールの設定)を確認、ポート転送設定を確認 |
| **認証エラー（TLS Handshake failed）** | 証明書・鍵のミスマッチ | クライアント設定ファイルの`<ca>`、`<cert>`、`<key>`セクションの内容を再確認 |
| **自宅ネットワークに到達できない** | `push "route ..."`設定が不正 | サーバー側`server.conf`の`push "route"`パラメータが自宅LANアドレスと一致しているか確認 |
| **DNSが機能しない** | DNS設定が通知されていない | `push "dhcp-option DNS"`の設定を確認、クライアント側でDNS設定を手動で行う |
| **VPN接続後、インターネット通信ができない** | デフォルトルートの競合 | `client.ovpn`に`redirect-gateway def1`を追加（全トラフィックをVPN経由に統一） |

### ログでのデバッグ

サーバー側でのログ確認：

```bash
root@router:~# tail -f /var/log/openvpn.log

# 接続中のクライアント一覧
root@router:~# cat /var/log/openvpn-status.log
```

接続失敗時のクライアント側ログ確認（詳細度を上げる）：

```bash
# Linux/Mac
sudo openvpn --config client.ovpn --verb 4 2>&1 | tee openvpn-debug.log

# Windows（PowerShellで管理者権限実行）
& "C:\Program Files\OpenVPN\bin\openvpn.exe" --config "C:\Users\<ユーザー名>\OpenVPN\config\client.ovpn" --verb 4
```

## 動的IP対応（DDNS設定）

OpenWrtの外部IPが変動する場合、DDNS（ダイナミックDNS）機能を利用して、クライアント側でホスト名での接続を可能にします。

[関連記事：OpenWrtでDDNSを設定し、定期的にDNSレコードを更新する](/blog/automatically-update-dns-records-for-onamae-com-from-openwrt-with-ddns-using-ddns-scripts-onamae)

DDNS設定後、クライアント設定ファイルの`remote`パラメータをDDNSホスト名に変更します：

```
# 変更前（グローバルIP指定）
remote 203.0.113.1 1194

# 変更後（DDNSホスト名指定）
remote myhome.ddns.jp 1194
```

## セキュリティ推奨事項

### 定期的な証明書更新

生成した証明書は825日間有効です。定期的に新しい証明書を生成・配置してください。

```bash
# 現在の証明書の有効期限確認
openssl x509 -in /etc/openvpn/server.crt -noout -text | grep -A2 "Validity"
```

### ファイアウォール設定の確認

```bash
# UFWの場合
sudo ufw allow 1194/udp

# iptablesの場合
sudo iptables -A INPUT -p udp --dport 1194 -j ACCEPT
```

### PAM認証の追加（オプション）

パスワード認証を追加する場合、`server.conf`に以下を追加：

```
auth-user-pass-verify /etc/openvpn/checkpsw.sh via-env
script-security 3
username-as-common-name
```

## 関連記事・外部リンク

### OpenWrt関連

- [OpenWrtへのOpenVPN インストール（公式ドキュメント）](https://openwrt.org/docs/guide_user/services/vpn/openvpn/server)
- [OpenWrt Wiki - OpenVPN](https://openwrt.org/docs/guide_user/services/vpn/openvpn/start)
- [本サイト：OpenWrtのインストール](/blog/install-friendlywrt-on-nanopi-r2s)

### VPN代替技術

- [WireGuardでVPNサーバーを構築する（本サイト）](/blog/set-up-a-vpn-server-on-openwrt-using-wireguard-to-access-the-home-network-from-outside)

### 動的IP対応

- [OpenWrtでDDNSを設定する（本サイト）](/blog/automatically-update-dns-records-for-onamae-com-from-openwrt-with-ddns-using-ddns-scripts-onamae)

### SSH・セキュリティ関連

- [SSH鍵の生成方法（本サイト）](/blog/generate-ssh-key)
- [OpenSSL公式ドキュメント](https://www.openssl.org/docs/)
- [NIST暗号化推奨設定](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-38A.pdf)

