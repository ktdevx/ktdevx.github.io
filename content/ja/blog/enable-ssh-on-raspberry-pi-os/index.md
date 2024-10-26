---
title: Raspberry Pi OSでSSH接続を有効化する
date: 2024-09-30T00:16:27+09:00
draft: false
params:
  toc: true
---

Raspberry Pi OSは、Raspberry Pi財団が提供している、Raspberry Pi用のOSです。SSH接続を有効にすることで、リモートでRaspberry Piにアクセスすることができます。

ここでは、Raspberry Pi OSでSSH接続を有効化する方法について説明します。

## 設定ツールの起動

以下のコマンドを実行し、Raspberry Piの設定ツールを起動します。

```
sudo raspi-config
```

## SSHサーバーの有効化

![raspi-config](images/raspi-config-1.webp)

コマンドを実行すると、設定画面が表示されます。Interface Optionsにカーソルを合わせ、Enterキーを押します。

![raspi-config](images/raspi-config-2.webp)

有効/無効の設定を行うインターフェースが表示されます。SSHにカーソルを合わせ、Enterキーを押します。

![raspi-config](images/raspi-config-3.webp)

SSHサーバーを有効化するか聞かれるため、Yesを選択します。

![raspi-config](images/raspi-config-4.webp)

SSHサーバーが有効化されました。Enterキーを押し、設定画面のトップへ戻ります。

![raspi-config](images/raspi-config-5.webp)

Finishを選択し、設定ツールを閉じます。

## SSHサーバーの再起動

以下のコマンドを実行し、SSHサーバーを再起動します。

```
sudo systemctl restart ssh
```

以上で、Raspberry Pi OSでSSH接続が有効になりました。これで、リモートコンピューターからSSHを使用してRaspberry Piにアクセスすることができます。