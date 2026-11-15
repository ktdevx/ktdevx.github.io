# エージェント向けコンテキスト

## プロジェクト

- このリポジトリは KTDEVX の多言語 Hugo サイトです。
- Anubis2 テーマを Git サブモジュールとして使用しています。Hugo Extended が必要です。
- サイト全体の設定と言語ごとの URL は [hugo.yml](hugo.yml) で管理しています。日本語がデフォルト言語で、URL には `/ja/` または `/en/` が含まれます。
- 原本は日本語（`content/ja/`）だけです。ほかの言語のページは、[monde](https://github.com/ktdevx/monde-private) で翻訳ファイル `po/<lang>/` から生成します（`tools/l10n.sh`）。`content/en/` は生成物で、Git では管理しません。

## 検証

- 変更を検証するときは CI と同じく `tools/l10n.sh build` の後に `hugo --minify` を実行してください。`tools/l10n.sh` には monde の実行ファイルが必要です（PATH に置くか、環境変数 `MONDE` で指定します）。
- CI では Hugo Extended `0.133.1` を固定しています。可能な限り同じバージョンを使用してください。新しく clone したリポジトリをビルドする前に、テーマサブモジュールを初期化します（`git submodule update --init --recursive`）。
- ローカルでプレビューするには `tools/l10n.sh build` の後に `hugo server` を使用します。ドラフトも確認する場合は `hugo server -D` を使用してください。
- 個別のテストや lint はありません。Hugo のビルド成功が主な検証方法です。

## コンテンツの規約

- コンテンツは `content/ja/` 配下に日本語で書きます。`content/en/` を直接編集しないでください。
- ブログ記事は `content/<lang>/blog/<slug>/index.md` の page bundle として管理します。基本的な front matter は [archetypes/blog.md](archetypes/blog.md) を使用してください。
- 既存の YAML front matter の形式を維持します。主な項目は `title`、タイムゾーン付きの `date`、`draft`、任意の `tags`、`params.toc` です。
- 記事を追加・変更したら `tools/l10n.sh update` を実行し、`po/` の変更も同じ変更に含めます（PR の CI が検査します）。
- 翻訳は `po/<lang>/<ページ>.po` の msgstr に書きます。訳し終えた（fuzzy・未翻訳がない）ページだけがその言語で公開されます。状況は `tools/l10n.sh status` で確認できます。
- msgstr では、コードスパン、リンク先、HTML タグを原文と同じに保ちます。空行を入れたり、行頭を Markdown のブロック記号（`#`、`-`、`>` など）にしたりしないでください（`tools/l10n.sh build` が失敗します）。ページ内リンク（`#見出し`）は、訳した見出しのアンカーに書き換えます。
- monde はコードブロックを翻訳しないため、コードブロックの中の日本語は他言語版にもそのまま出ます（許容している仕様です）。
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
