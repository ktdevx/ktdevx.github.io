---
title: プロジェクト
date: 2026-11-16T12:00:00+09:00
draft: false
---

私が開発・公開しているオープンソースソフトウェア（OSS）を紹介します。いずれも GitHub で公開しており、Issue や Pull Request を歓迎しています。

## Naos

C と C++ 向けのテストハーネスです。必要なのは C99 のコンパイラだけで、インストールするライブラリもコンパイラ拡張も要りません。CMake でビルドし、どのビルドシステムからも使えます。

- **リポジトリ**：[vabelorg/naos](https://github.com/vabelorg/naos)
- **言語**：C99（C++11 からも利用可能）
- **ライセンス**：MIT
- **対応環境**：Linux（GCC、Clang）、macOS（Clang）、Windows（MSVC、MinGW-w64）

主な特徴は次のとおりです。

- 1 つの実行ファイルですべてのテストを実行し、結果を終了コードで返します。
- `naos_add_executable()` で各テストを CTest に登録すると、テストごとにプロセスを分けて並列に実行できます。
- アサーションを 1 つも実行しなかったテストは失敗として扱うため、書きかけのテストが成功に見えることがありません。
- 失敗は `file:line: error: ...` の形式で出力され、エディターから該当行へ移動できます。

## ArgX

{{< themed-image light="images/argx-logo-light.svg" dark="images/argx-logo-dark.svg" alt="ArgX" width=240 >}}

C99 向けのコマンドライン引数パーサーです。コマンドラインの仕様をスキーマとして一度定義するだけで、`argv` の解析、検証、値の型変換、ヘルプの生成までを行います。

- **リポジトリ**：[vabelorg/argx](https://github.com/vabelorg/argx)
- **言語**：C99
- **ライセンス**：MIT
- **対応環境**：Linux（GCC、Clang）、macOS（Clang）、Windows（MSVC、MinGW）

主な特徴は次のとおりです。

- C 標準ライブラリ以外に依存せず、コンパイラ拡張も使いません。
- フラグ、値を取るオプション、位置引数、入れ子のサブコマンドに対応しています。
- 文字列、整数、浮動小数点数、選択肢に加え、独自の値の型を定義できます。
- ライブラリは何も出力せず、プロセスを終了させないため、アプリケーション側でエラー処理を制御できます。

関連記事：

- [【C言語】ArgXでコマンドライン引数を解析する](/blog/argx-usage)
- [【C言語】ArgXでサブコマンドを持つCLIを作る](/blog/argx-subcommands)
