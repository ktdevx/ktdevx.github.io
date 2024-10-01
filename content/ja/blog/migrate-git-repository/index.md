---
title: Gitリポジトリを別のサーバーに移行する
date: 2024-09-29T22:57:58+09:00
draft: false
params:
  pager: true
  toc: true
---

ここでは、Gitリポジトリを別のサーバーに移行する方法について解説します。

## 移行先となる空のベアリポジトリを作成

事前に、移行先のサーバーで空のベアリポジトリを作成しておきましょう。以下のコマンドを移行先のサーバで実行します。

```
git init --bare
```

ここで作成したベアリポジトリに、Gitリポジトリを移行することが本記事の目標です。

## 移行元リポジトリからベアリポジトリをクローン

以下のコマンドをPCで実行し、移行元のリポジトリから、ベアリポジトリをクローンします。

```
git clone --bare <移行元リポジトリへのパス>
```

`clone`コマンドに`--bare`オプションを付けることにより、ベアリポジトリとしてクローンすることができます。

## ベアリポジトリを移行先リポジトリにプッシュ

以下のコマンドをPCで実行し、先ほどクローンしたベアリポジトリを、移行先のリポジトリにプッシュします。

```
cd <クローンしたベアリポジトリへのパス>
git push --mirror <移行先リポジトリへのパス>
```

pushコマンドに`--mirror`オプションを付けることにより、指定したリポジトリの全てのブランチ、タグ、リファレンスを同期することができます。

## クローンしたベアリポジトリの削除

以下のコマンドをPCで実行し、不要となったベアリポジトリを削除します。

```
cd ..
rm -rf <クローンしたベアリポジトリ>
```

移行元のリポジトリも忘れずに削除しましょう。これにより、Gitリポジトリの移行作業は完了です。