---
title: NanoPi R2SにFriendlyWrtをインストールする
date: 2024-09-29T21:35:25+09:00
draft: false
tags:
  - NanoPi
  - FriendlyWrt
params:
  toc: true
---

NanoPi R2SにFriendlyWrtをインストールすると、誰でも簡単にルーターを構築することができます。

ここでは、NanoPi R2SにFriendlyWrtをインストールする方法について解説します。

## はじめに

NanoPi R2Sとは、FriendlyElecが製造するシングルボードコンピューターです。イーサネットが2ポート搭載されており、ルーターのハードウェアとして活用することができます。

FriendlyWrtは、FriendlyElecが提供するOpenWrtベースのOSです。オープンソースであり、ルーター・NAS・IoT アプリケーションなどの開発に適しています。

## FriendlyWrtのダウンロード

[公式ダウンロードリンク](https://drive.google.com/drive/folders/1H56Yl3G5kBAE_JGaYT2O_D8xKsBP7kZv)にアクセスし、`01_Official images/01_SD card images`から、FriendlyWrtのイメージファイルをダウンロードします。

提供されているFriendlyWrtのイメージファイルは、以下の通りです。

|イメージファイル                                  |詳細                                         |
|--------------------------------------------------|---------------------------------------------|
|rk3328-sd-friendlywrt-21.02-YYYYMMDD.img.gz       |OpenWrt 21.02ベース                          |
|rk3328-sd-friendlywrt-21.02-docker-YYYYMMDD.img.gz|OpenWrt 21.02ベース(Dockerコンテナをサポート)|
|rk3328-sd-friendlywrt-23.05-YYYYMMDD.img.gz       |OpenWrt 22.03ベース                          |
|rk3328-sd-friendlywrt-23.05-docker-YYYYMMDD.img.gz|OpenWrt 22.03ベース(Dockerコンテナをサポート)|

gzip形式で圧縮されているため、7-Zipなどを利用して解凍します。

## FriendlyWrtの書き込み

microSDに先ほどダウンロードしたFriendlyWrtを書き込みます。

microSDをPCにセットし、Win32 Disk Imagerなどの書き込みツールを使用してOSを書き込みましょう。microSDの容量は8GB以上が推奨されています。

## FriendlyWrtの起動

FriendlyWrtを書き込んだmicroSDをNanoPiにセットし、電源を入れて起動します。

電源を入れてしばらく待つと、HTTPおよびSSH経由で接続が可能になります。ホスト情報は以下の通りです。

ホスト名：FriendlyWrt  
IPv4アドレス：192.168.2.1  
IPv6アドレス：[fd00:ab:cd::1]

ユーザー名は`root`、パスワードは`password`でログインできます。

## 推奨されるセキュリティ設定

NanoPiを利用する前に、SSHで接続して以下のセキュリティ設定を行うことを推奨します。

### ログインパスワードの変更

`passwd`コマンドを使用し、`root`ユーザーのパスワードを変更します。

```
passwd
Changing password for root
New password: <パスワード>
Retype password: <パスワード再入力>
passwd: password for root changed by root
```

以降は変更したパスワードでログインできます。

### SSH接続の設定変更

以下のコマンドで、LAN側からのみSSHで接続できるように制限し、ポート番号を任意の値に変更します。

```
uci set dropbear.@dropbear[0].Interface=lan
uci set dropbear.@dropbear[0].Port=<ポート番号>
```

設定に問題がなければ、以下のコマンドで設定を反映します。

```
uci commit dropbear
service dropbear restart
```

これにより設定が反映されます。以降は新しいポート番号を使用してSSH接続する必要があります。

### LuCIのアクセス制限設定

以下のコマンドで、ローカルデバイスのみがLuCIにアクセスできるように変更します。

```
uci set uhttpd.main.listen_http=192.168.2.1:80
uci add_list uhttpd.main.listen_http=[fd00:ab:cd::1]:80
uci set uhttpd.main.listen_https=192.168.2.1:443
uci add_list uhttpd.main.listen_https=[fd00:ab:cd::1]:443
```

設定に問題がなければ、以下のコマンドで設定を反映します。

```
uci commit uhttpd
uci uhttpd restart
```

これにより設定が反映されます。
