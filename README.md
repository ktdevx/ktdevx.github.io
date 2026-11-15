# KTDEVX Webサイト

## 翻訳

記事の原本は日本語（`content/ja/`）です。英語版（`content/en/`）は、翻訳ファイル `po/en/` から [monde](https://github.com/ktdevx/monde-private) で生成します。`content/en/` は生成物なので Git では管理しません。

monde の実行ファイルを PATH に置くか、環境変数 `MONDE` でパスを指定してから、次のコマンドを使います。

| コマンド | 内容 |
| --- | --- |
| `tools/l10n.sh update` | `content/ja/` の変更を `po/` に反映する（新しいページの `.po` も作る） |
| `tools/l10n.sh status` | ページごとの翻訳の状況を表示する |
| `tools/l10n.sh build` | `po/` から `content/en/` を作り直す |

記事を追加・変更したときの流れは次のとおりです。

1. `content/ja/` の記事を書く。
2. `tools/l10n.sh update` を実行する。
3. `po/en/` の未翻訳と fuzzy のエントリを Poedit などで訳す。
4. `tools/l10n.sh build` の後に `hugo server` で確認する。
5. `content/ja/` と `po/` の変更をコミットする。

訳し終えていないページは、その言語では公開されません。訳し終えていないページも原文混じりで確認したいときは、`L10N_ALLOW_PARTIAL=1 tools/l10n.sh build` を使います。

CI では、PR で `po/` が `content/ja/` に追従しているかを検査し、`po/` から英語版を作ってからサイトをビルドします。CI が monde を Release から取得するため、リポジトリの Secret `MONDE_TOKEN` に `ktdevx/monde-private` の Contents を読める fine-grained personal access token を登録してください。
