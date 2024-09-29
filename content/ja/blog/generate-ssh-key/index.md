---
title: SSH鍵の生成方法
date: 2024-09-29T19:51:46+09:00
draft: false
params:
  pager: true
  toc: true
---

SSHは、ネットワーク経由で安全にリモートコンピューターにログインしたり、ファイルの転送やコマンドの実行を行うためのプロトコルです。通信内容を暗号化して送信するため、通信内容が盗聴されることを防ぎ、安全性を確保することができます。

ここでは、SSHで使用する鍵を生成する手順について解説します。

## 暗号アルゴリズムと鍵長の設定

鍵は`ssh-keygen`コマンドを用いて生成することができます。以下の例では、RSAという暗号アルゴリズムで、鍵長が4096の鍵を生成しています。

```
ssh-keygen -t rsa -b 4096
```

暗号アルゴリズムは`-t`オプションで指定できます。指定できる暗号アルゴリズムは以下の通りです。

- RSA
- DSA
- ECDSA
- Ed25519

鍵長は`-b`オプションで指定できます。

## 保存場所とファイル名の設定

```
Enter file in which to save the key (<ホームディレクトリ>/.ssh/id_rsa): [<保存場所とファイル名>]
```

鍵の保存場所とファイル名の入力が求められます。特に指定がなければデフォルトのままEnterキーを押します。

## パスフレーズの設定

```
Enter passphrase (empty for no passphrase): [<パスフレーズ>]
Enter same passphrase again: [<パスフレーズ>]
```

パスフレーズを設定するように求められます。パスフレーズを設定することで秘密鍵を保護することができます。パスフレーズが不要の場合はそのままEnterキーを押します。

## 鍵の生成

```
Your identification has been saved in <秘密鍵へのパス>.
Your public key has been saved in <公開鍵へのパス>.
The key fingerprint is:
<fingerprintの表示>
The key's randomart image is:
<randomart imageの表示>
```

このように表示されれば鍵の生成は完了です。デフォルト設定の場合、`.ssh`ディレクトリに`id_rsa`という名前の秘密鍵と、`id_rsa.pub`という名前の公開鍵が生成されます。公開鍵をリモートホストに登録することで、SSH接続を安全に行うことができます。
