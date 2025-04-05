---
title: WindowsでTftpd64を使用してTFTPサーバーを立てる
date: 2025-03-16T16:44:58+09:00
draft: false
tags:
  - Tftpd64
params:
  toc: true
---

Tftpd64は、Windows向けのTFTP、SNTP、SYSLOG、DHCP、DNSサーバーのソフトウェアです。

ここでは、Tftpd64を使用してWindows上でTFTPサーバーを立てる方法について説明します。

## Tftpd64のインストール

[Tftpd64の公式サイト](https://pjo2.github.io/tftpd64/)のダウンロードページにて、`Tftpd64-<バージョン>-setup.exe`というファイル名でインストーラーが配布されています。インストーラーをダウンロードして実行しましょう。

![Tftpd64インストーラー](images/tftpd64-install1.webp)

ライセンスが表示されます。内容を確認し、「I Agree」を押して次へ進めましょう。

![Tftpd64インストーラー](images/tftpd64-install2.webp)

インストール条件を設定できます。設定後、「Next」を押して次へ進めましょう。

![Tftpd64インストーラー](images/tftpd64-install3.webp)

Tftpd64をインストールする場所を設定します。設定後、「Install」を押すことでインストールが開始されます。

![Tftpd64インストーラー](images/tftpd64-install4.webp)

画面上に「Completed!」と表示されればインストール完了です。「Close」を押してインストーラーを終了します。

## Tftpd64の使い方

インストールされた「tftpd64.exe」を実行してTftpd64を起動します。

![Tftpd64](images/tftpd64-usage1.webp)

Tftpd64を起動したら、最初に「Settings」を押して設定画面を開きましょう。

![Tftpd64](images/tftpd64-usage2.webp)

設定画面の「GLOBAL」タブでは、Tftpd64全体に関わる設定を変更できます。今回はTFTPサーバーしか利用しないため、「TFTP Server」だけにチェックを付けましょう。

![Tftpd64](images/tftpd64-usage3.webp)

設定画面の「TFTP」タブでは、TFTPに関わる設定を変更出来ます。TFTPサーバーで公開するベースディレクトリを「Base Directory」で設定しましょう。

Tftpd64はデフォルトの状態では、全てのネットワークインターフェースでTFTPクライアントからの通信を受け付けます。「Bind TFTP to this address」にチェックを入れ、IPアドレスを指定することで、サーバーを公開するIPアドレスを指定することができます。

設定したら「OK」を押して設定を反映させてください。

![Tftpd64](images/tftpd64-usage4.webp)

確認のダイアログが表示されます。「OK」を押すことでTftpd64が再起動されます。以上でTFTPのセットアップは完了です。

フォルダに適当なファイルを置いて、実際にTFTPクライアントから取得してみましょう。

![Tftpd64](images/tftpd64-usage5.webp)

TFTPクライアントからアクセス出来ていることを確認できました。

アクセスできない場合はIPアドレスやポートの設定、セキュリティソフトでブロックされていないかを見直しましょう。
