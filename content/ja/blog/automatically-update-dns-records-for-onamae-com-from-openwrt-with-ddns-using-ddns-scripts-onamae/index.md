---
title: ddns-scripts-onamaeを使用してOpenWrtからお名前.comのDNSレコードをダイナミックDNS（DDNS）で自動更新する
date: 2025-05-11T22:33:36+09:00
draft: false
tags:
  - OpenWrt
params:
  toc: true
---

## はじめに

お名前.comのダイナミックDNS（DDNS）クライアントはWindowsしか対応していません。しかし、ddns-scripts-onamaeを使用することで、OpenWrtがインストールされたルーターからお名前.comのDNSレコードを更新することができます。

ddns-scripts-onamaeは、OpenWrtのDDNS管理を支援するddns-scriptsパッケージのサブモジュールの一つであり、日本国内で広く使われているドメイン登録サービス「お名前.com」のDNSレコードを自動で更新する機能を提供します。

これにより、固定IPアドレスを持たないインターネット回線でも、自宅のOpenWrtルーターを用いてお名前.comに登録されたホスト名と最新のIPアドレスを常に同期させることが可能になります。

ここでは、ddns-scripts-onamaeを使用してOpenWrtからお名前.comのDNSレコードをDDNSで自動更新する方法について説明します。

## ddns-scripts-onamaeのインストール

[ddns-scripts-onamaeのダウンロードサイト](https://github.com/ktdevx/ddns-scripts-onamae/releases)にアクセスして最新バージョンのパッケージを確認します。今回はv1.0.2を選択しました。

OpenWrtにSSHでアクセスして`wget`コマンドでパッケージをダウンロードしましょう。

```
wget -O /tmp/ddns-scripts-onamae.ipk https://github.com/ktdevx/ddns-scripts-onamae/releases/download/v1.0.2/ddns-scripts-onamae_1.0.2-r1_all.ipk
```

これにより、`/tmp`ディレクトリに`ddns-scripts-onamae.ipk`という名前で、ddns-scripts-onamaeのパッケージファイルが保存されます。`opkg install`コマンドでパッケージをインストールしましょう。

```
opkg update
opkg install /tmp/ddns-scripts-onamae.ipk
```

ddns-scripts-onamaeのインストールは以上で完了です。

## DDNSの設定

テキストエディタで`/etc/config/ddns`を開いて設定を追記します。

```
config service "example_com"
    option service_name "onamae.com"
    option lookup_host  "example.com"
    option domain       "@example.com"
    option username     "<お名前.com Naviのお名前ID>"
    option password     "<お名前.com Naviのパスワード>"
    option interface    "wan"
    option ip_source    "network"
    option ip_network   "wan"
    option use_ipv6     "0"
    option enabled      "1"
```

この例では、`example.com`という名前のドメインを`wan`のIPアドレスで更新する設定を、`example_com`という名前で追加しています。環境に応じて下記設定を変更しましょう。

| 設定                   | 詳細                                                         |
| ---------------------- | ------------------------------------------------------------ |
| lookup_host            | IPアドレスを更新するドメイン名 (FQDN)                        |
| domain                 | IPアドレスを更新するドメイン名 (`サブドメイン名@ドメイン名`) |
| username               | お名前.com Naviのお名前ID                                    |
| password               | お名前.com Naviのパスワード                                  |
| interface / ip_network | 設定するIPアドレスを読み取るネットワーク                     |

更新対象がサブドメインの場合は`lookup_host`と`domain`の設定は以下のようにします。

```
    option lookup_host  "sub.example.com"
    option domain       "sub@example.com"
```

設定後は以下のコマンドを実行してサービスを再起動しましょう。

```
service ddns restart
```

以上でDDNSの設定は完了です。これにより、DNSレコードが自動で設定されるようになります。
