---
title: HugoとGitHub Pagesで静的なWebサイトを公開する
date: 2024-09-27T21:11:39+09:00
draft: false
---

HugoとGitHub Pagesを利用することで、非常に簡単に静的なWebサイトを公開することができます。ここでは、その手順について解説します。

## GitHubにWebサイト用のリポジトリを作成する

GitHubで任意の名前のリポジトリを作成します。詳細は[こちら](/blog/create-github-repository)を参照してください。

リポジトリ名を`<アカウント名>.github.io`とすると、`https://<アカウント名>.github.io/`にWebサイトが公開されます。アカウント名に大文字が含まれている場合は、小文字にする必要があります。

別の名前のリポジトリを作成する場合、公開URLは`https://<アカウント名>.github.io/<リポジトリ名>`になります。

GitHub Freeを使用している場合、リポジトリをパブリックに設定する必要があります。

リポジトリ作成後は、ローカルにクローンしてください。

## Hugoのセットアップ

クローンしたリポジトリに移動し、`hugo new site . --force`を実行します。これにより、ディレクトリ内にHugoのディレクトリ構造が作成されます。すでに空でないディレクトリで実行するため、`--force`オプションを使用します。

## Hugo設定ファイルの編集

Hugoのセットアップが完了すると、`hugo.toml`という設定ファイルが生成されます。

```toml
baseURL = 'https://example.org/'
languageCode = 'en-us'
title = 'My New Hugo Site'
```

基本設定について変更します。

- baseURL  
  公開するWebサイトのURLを指定します。この設定はリポジトリ名によって決まります。
- languageCode  
  Webサイトの言語を指定します。
- title  
  Webサイトのタイトルを指定します。

今回は以下のように設定を変更しました。

```toml
baseURL = 'https://ktdevx.github.io/'
languageCode = 'ja'
title = 'KTDEVX'
```

設定の詳細は[公式サイト](https://gohugo.io/getting-started/configuration/)を参照してください。

## テーマをプロジェクトに追加

Hugoのテーマをプロジェクトに追加します。テーマは[公式サイト](https://themes.gohugo.io/)から選べます。

今回は[Ananke](https://github.com/theNewDynamic/gohugo-theme-ananke)を使用します。以下のコマンドでGit Submodulesを使ってAnankeをプロジェクトに追加します。

```
git submodule add https://github.com/theNewDynamic/gohugo-theme-ananke.git themes/ananke
```

テーマを適用するために、`hugo.toml`に`theme = 'ananke'`を追加します。

## ページを追加する

次に、実際のコンテンツを作成します。以下のコマンドで新しい記事を作成します。

```
hugo new content posts/hello-world.md
```

生成された`hello-world.md`を編集し、記事を書きます。

```markdown
+++
title = 'Hello, World!'
date = 2024-09-19T00:00:00+09:00
draft = true
+++

これはHugoで作成した初めてのブログ記事です。
```

ここで注意する点は`draft = true`という設定です。これは記事が下書き状態であることを示します。

記事を公開するには、`draft = false`とするか、`draft`の設定を削除します。

## ローカルでサイトをプレビュー

以下のコマンドでローカルサーバーを起動して、サイトを確認します。

```
hugo server -D
```

`-D`オプションは、下書きの記事を表示するためのものです。ブラウザを開き、`http://localhost:1313/`にアクセスすると、サイトをプレビューできます。

プレビューが問題なければ、先ほど作成した記事の下書き設定を無効化し、リモートリポジトリにプッシュしましょう。

## GitHub Pagesのデプロイ設定

GitHubリポジトリの「Settings」から「Pages」をクリックし、GitHub Pagesを有効化します。今回はGitHub Actionsでデプロイを行います。「Source」を「GitHub Actions」に設定します。

## ビルドとデプロイを行うワークフローを作成

Webサイトのビルドとデプロイを行うワークフローをプロジェクトに追加します。`.github/workflows/`ディレクトリに`gh-pages.yml`を作成し、以下のように記述します。

```yaml
name: GitHub Pages

on:
  push:
    branches:
      - main

jobs:
  build:
    runs-on: ubuntu-22.04
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          submodules: recursive
      - name: Install Hugo
        env:
          HUGO_VERSION: "0.134.3"
        run: |
          wget -q -O ${{ runner.temp }}/hugo.tar.gz https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-amd64.tar.gz
          tar -xzf ${{ runner.temp }}/hugo.tar.gz -C ${{ runner.temp }}
          sudo mv ${{ runner.temp }}/hugo /usr/local/bin/
          hugo version
      - name: Build with Hugo
        run: hugo --minify
      - name: Upload artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: public/

  deploy:
    needs: build
    runs-on: ubuntu-22.04
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    permissions:
      pages: write
      id-token: write
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
```

これにより、mainブランチにプッシュされるたびにWebサイトが自動的にビルド・デプロイされます。

## 公開されたWebサイトを確認

ブラウザで`https://<アカウント名>.github.io/`、または`https://<アカウント名>.github.io/<リポジトリ名>`にアクセスし、Webサイトが公開されていることを確認します。
