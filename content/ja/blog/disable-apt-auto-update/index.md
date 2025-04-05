---
title: APTパッケージの自動更新を無効化する
date: 2024-09-29T19:22:50+09:00
draft: false
tags:
  - APT
params:
  toc: true
---

パッケージが自動更新されると、これまで動いていたソフトウェアが突然動かなくなってしまう可能性があります。

ここでは、APTパッケージの自動更新を無効化する方法について解説します。

## 自動更新設定の確認

自動更新の設定は、`/etc/apt/apt.conf.d`ディレクトリに格納されている`20auto-upgrades`に記載されています。以下は、設定の表示例です。

```
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
```

`Update-Package-Lists`はパッケージの自動アップデート、`Unattended-Upgrade`はパッケージの自動アップグレードの設定を示しています。1が有効、0が無効を意味します。

## 自動更新の無効化

パッケージの自動アップデートおよびアップグレードを無効化するには、`20auto-upgrades`を以下のように編集します。

```
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Unattended-Upgrade "0";
```

これにより、パッケージの自動更新が無効化されます。
