# エージェント向けコンテキスト

## プロジェクト

- このリポジトリは KTDEVX の多言語 Hugo サイトです。
- Anubis2 テーマを Git サブモジュールとして使用しています。Hugo Extended が必要です。
- サイト全体の設定と言語ごとの URL は [hugo.yml](hugo.yml) で管理しています。日本語がデフォルト言語で、URL には `/ja/` または `/en/` が含まれます。

## 検証

- 変更を検証するときは CI と同じ `hugo --minify` を実行してください。
- CI では Hugo Extended `0.133.1` を固定しています。可能な限り同じバージョンを使用してください。新しく clone したリポジトリをビルドする前に、テーマサブモジュールを初期化します（`git submodule update --init --recursive`）。
- ローカルでプレビューするには `hugo server` を使用します。ドラフトも確認する場合は `hugo server -D` を使用してください。
- 個別のテストや lint はありません。Hugo のビルド成功が主な検証方法です。
- `aaa.sh` は `po4a` を使って README を翻訳するためのスクリプトであり、サイトのビルドスクリプトではありません。

## コンテンツの規約

- 翻訳済みコンテンツは `content/ja/` と `content/en/` 配下に配置します。
- ブログ記事は `content/<lang>/blog/<slug>/index.md` の page bundle として管理します。基本的な front matter は [archetypes/blog.md](archetypes/blog.md) を使用してください。
- 既存の YAML front matter の形式を維持します。主な項目は `title`、タイムゾーン付きの `date`、`draft`、任意の `tags`、`params.toc` です。
- 記事を追加・変更するときは、同じ slug の別言語版も確認します。意図的な省略でない限り、日本語版と英語版のナビゲーションやコンテンツを揃えてください。
- 記事固有の画像は、その記事の bundle ディレクトリに配置し、bundle からの相対パスで参照します。
- サイトの数式表示が必要なページに限り、`params.math: true` を設定してください。
- 近くにある日本語版・英語版の記事の文体と Markdown 形式に従い、依頼と無関係な大規模な本文変更は避けてください。
- セットアップ記事やチュートリアル記事では、前提条件から最後の確認手順まで一連の流れを確認します。対象読者が利用できるように、重要なパッケージ、コマンド、設定値、セキュリティ手順の目的を説明してください。
- 記事を完成扱いにする前に、未完了のセクション、プレースホルダー、足りないコマンド、不適切な `draft` 値がないか確認します。`draft: false` だけでは完成とは判断しません。

## テーマとアセット

- テーマを編集するよりもプロジェクト側のファイルを優先し、サイトを変更するときは `content/`、`layouts/`、`static/`、`hugo.yml` を使用します。
- プロジェクト側のテーマ上書きには現在 [layouts/partials/head-extra.html](layouts/partials/head-extra.html) が含まれます。メタデータ、アナリティクス、広告の動作を変更する前に確認してください。
- [layouts/shortcodes/ads/nucbox-m5-plus.html](layouts/shortcodes/ads/nucbox-m5-plus.html) は意図的な外部広告コードとして扱い、無関係なコンテンツには追加しないでください。
- タスクでドメインや広告設定を明示的に変更する場合を除き、`static/CNAME` と `static/ads.txt` を維持してください。

## 生成ファイルと変更範囲

- `public/` や `resources/_gen/` の生成物を直接編集せず、必要に応じて Hugo で再生成してください。
- 通常のサイト作業では `.hugo_build.lock` や `hugo.exe` を編集しないでください。
- 変更は依頼されたページ、別言語版、レイアウト、アセット、設定に限定します。明示的に必要な場合を除き、テーマサブモジュールは変更しないでください。
- 完了前に `hugo --minify` を実行し、既存の問題や環境固有のビルド問題があれば明確に報告してください。

## 参照先

- [CI workflow](.github/workflows/gh-pages.yml)
- [Japanese article example](content/ja/blog/what-is-github-copilot/index.md)
- [English article example](content/en/blog/what-is-github-copilot/index.md)
- [Image-based article example](content/ja/blog/install-git-on-windows/index.md)
- [Theme documentation](themes/anubis2/README.md)
