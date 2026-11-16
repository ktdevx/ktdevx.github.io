---
title: 【C言語】ArgXでコマンドライン引数を解析する
date: 2026-11-15T00:00:00+09:00
lastmod: 2026-11-17T08:00:00+09:00
draft: false
tags:
  - C
  - CMake
  - ArgX
params:
  toc: true
---

C言語でコマンドラインツールを作るとき、`argv`の解析は意外と手間がかかります。`getopt`を使ってもロングオプションは環境に依存し、値の型変換や必須チェック、`--help`で表示するヘルプ文は自分で書く必要があります。

ここでは、C99向けのコマンドライン引数パーサー「[ArgX](https://github.com/vabelorg/argx)」の使い方を、小さなサンプルプログラムを作りながら解説します。

## ArgXとは

ArgXは、コマンドラインの仕様を**スキーマ**として一度定義するだけで、`argv`の解析、検証、値の型変換、ヘルプの生成までを行うライブラリです。主な特徴は次のとおりです。

- 標準Cライブラリ以外に依存しない、C99のみで書かれたライブラリです。
- Linux（GCC、Clang）、macOS（Clang）、Windows（MSVC、MinGW）でビルドでき、静的ライブラリと共有ライブラリのどちらにもできます。
- フラグ、回数を数えるオプション（`-vv`など）、`--no-`で否定できるフラグ、値を取るオプション、指定されたすべての値を集めるリストオプション、位置引数、ネストしたサブコマンドを扱えます。すべてのサブコマンドで使えるグローバルオプションも定義できます。
- 値は文字列、整数、浮動小数点数、選択肢、独自に定義した型に変換できます。
- ヘルプと使い方の行（Usage）はスキーマから自動で生成されます。
- ライブラリ自身は何も出力せず、プロセスを終了させず、環境変数も読みません。エラーはエラーコードと1行のメッセージで返されます。

最後の点が特徴的で、ヘルプやエラーをどこにどう出力するか、どの終了コードで終わるかは、すべて呼び出し側で決められます。

## 前提条件

この記事では次の環境を前提とします。

- CMake 3.21以上
- C99に対応したCコンパイラ（GCC、Clang、MSVCなど）
- Git（CMakeがArgXのソースを取得するために使います）

記事の手順はUbuntu 24.04、CMake 3.28、GCC 13で動作を確認しています。ArgXのバージョンは`v0.2.0`です。

`v0.2.0`で`--help`の書き方が変わったため、記事の内容を更新しました。`v0.1.x`では、解析エラーのときにも`--help`が指定されたかを確認する必要がありましたが、`v0.2.0`では`--help`を**終端フラグ**にすることで不要になりました（「[argvを解析する](#argvを解析する)」を参照）。

## プロジェクトを準備する

次の構成のプロジェクトを作ります。

```
greet/
├── CMakeLists.txt
└── main.c
```

`CMakeLists.txt`には次の内容を記述します。

```cmake
cmake_minimum_required(VERSION 3.21)
project(greet LANGUAGES C)

include(FetchContent)
FetchContent_Declare(ArgX
    GIT_REPOSITORY https://github.com/vabelorg/argx.git
    GIT_TAG v0.2.0
)
FetchContent_MakeAvailable(ArgX)

add_executable(greet main.c)
target_link_libraries(greet PRIVATE ArgX::argx)
```

`FetchContent`は、CMakeの構成時に外部のソースを取得してプロジェクトに組み込む機能です。`GIT_TAG`で使うバージョンを固定し、`target_link_libraries`で`ArgX::argx`をリンクすると、ArgXのヘッダーのインクルードパスも自動で設定されます。`GIT_TAG`は、[リリース一覧](https://github.com/vabelorg/argx/releases)で最新のバージョンを確認して指定してください。

FetchContent以外に、`add_subdirectory`、インストール済みのArgXを`find_package`で使う方法、pkg-configを使う方法もあります。詳しくは公式ドキュメントの[Installation](https://github.com/vabelorg/argx/blob/main/docs/getting-started/installation.md)を参照してください。

## ArgXを使う流れ

ArgXを使うプログラムは、次の順序で処理を行います。

1. **スキーマを定義する**：コマンドを作り、オプションと位置引数を追加します。
2. **スキーマを検証する**：定義に矛盾がないかを確認します。解析とヘルプ生成は、検証済みのスキーマでしか行えません。
3. **`argv`を解析する**：解析結果（result）が作られます。
4. **値を読み取る**：解析結果から、型変換済みの値を取り出します。
5. **破棄する**：解析結果、スキーマの順に破棄します。

この記事では、名前を受け取ってあいさつを表示する`greet`というプログラムを作ります。受け付けるコマンドラインは次のとおりです。

```
greet [-h] [-l] [-n COUNT] name
```

| 引数 | 種類 | 意味 |
| --- | --- | --- |
| `-h`, `--help` | フラグ | ヘルプを表示する |
| `-l`, `--loud` | フラグ | あいさつの末尾に`!`を付ける |
| `-n`, `--count` | 値を取るオプション（整数） | あいさつの回数。省略時は1 |
| `name` | 位置引数（必須） | あいさつする相手の名前 |

以降では`main.c`の内容を順に説明します。コード全体は「[コード全体](#コード全体)」に掲載しています。

## スキーマを定義する

まず、ルートとなるコマンドを作り、オプションと位置引数を追加します。

```c
TRY(argx_command_create("greet", &root));
TRY(argx_command_set_description(root, "Greet somebody."));
TRY(argx_command_add_flag(root, 'h', "help", &help));
TRY(argx_option_set_description(help, "Print this help."));
TRY(argx_option_set_terminal(help, true));
TRY(argx_command_add_flag(root, 'l', "loud", &loud));
TRY(argx_option_set_description(loud, "Add an exclamation mark."));
TRY(argx_command_add_value(root, 'n', "count", argx_type_int(), &count));
TRY(argx_option_set_description(count, "How often to greet."));
TRY(argx_option_set_value_name(count, "COUNT"));
TRY(argx_option_set_default(count, "1"));
TRY(argx_command_add_positional(root, "name", argx_type_string(), ARGX_ARITY_REQUIRED, &name));
TRY(argx_positional_set_description(name, "Whom to greet."));
```

それぞれの関数の役割は次のとおりです。

- `argx_command_create`：コマンドを作ります。ここで指定した名前がヘルプに表示されます。
- `argx_command_add_flag`：値を取らないフラグを追加します。短い名前（`'h'`）と長い名前（`"help"`）を指定し、最後の引数に**ハンドル**（`argx_option_t *`）が書き込まれます。ハンドルは、属性の設定や値の読み取りに使います。
- `argx_option_set_terminal`：フラグを**終端フラグ**にします。終端フラグが指定されると、解析はそこで終わり、成功します（後述）。
- `argx_command_add_value`：値を取るオプションを追加します。値の型には`argx_type_int()`（整数）を指定しています。
- `argx_option_set_value_name`：ヘルプで値を表す名前（`<COUNT>`）を設定します。
- `argx_option_set_default`：省略時の値を文字列で設定します。この値がオプションの型に変換できるかどうかは、後述の検証で確認されます。
- `argx_command_add_positional`：位置引数を追加します。`ARGX_ARITY_REQUIRED`は「ちょうど1つ必要」という意味です。ほかに`ARGX_ARITY_OPTIONAL`（0個か1個）、`ARGX_ARITY_ZERO_OR_MORE`（0個以上）、`ARGX_ARITY_ONE_OR_MORE`（1個以上）を指定できます。
- `*_set_description`：ヘルプに表示される説明文を設定します。

ArgXは`--help`を自動では追加しないため、普通のフラグとして定義し、`argx_option_set_terminal`で終端フラグにします。`--version`のように、指定されたらほかの引数に関係なく1つの処理だけをして終わるフラグにも使えます。

### エラー処理をまとめるTRYマクロ

失敗する可能性のある関数は`argx_error_t`を返し、成功時は`ARGX_ERROR_NONE`になります。呼び出しのたびに`if`文を書くと長くなるため、サンプルでは次の`TRY`マクロで、失敗したら`define_failed`ラベルに移動するようにしています。

```c
#define TRY(call)                     \
    do                                \
    {                                 \
        error = (call);               \
        if (error != ARGX_ERROR_NONE) \
        {                             \
            goto define_failed;       \
        }                             \
    } while (0)
```

`goto`を使ったエラー処理の考え方は、「[【C言語】goto文でメモリ解放の管理を容易にする](/blog/c-goto-memory-free)」で詳しく解説しています。

## スキーマを検証する

定義が終わったら、`argx_command_validate`でスキーマを検証します。

```c
TRY(argx_command_validate(root, NULL, NULL, NULL));
```

検証では、型に合わないデフォルト値や、必須の位置引数の前に省略可能な位置引数があるといった、複数の定義にまたがる矛盾を確認します。なお、名前の重複のように1つの定義で判断できる誤りは、`argx_command_add_flag`などの追加時にエラーになります。後ろの3つの引数にポインターを渡すと、問題のあるコマンド、オプション、位置引数を受け取れます。ここでは使わないため`NULL`を渡しています。

## argvを解析する

`argx_parse`に`argc`と`argv`を渡して解析します。戻り値は次の3種類のいずれかです。

| 戻り値 | 意味 | 解析結果 |
| --- | --- | --- |
| `ARGX_ERROR_NONE` | 解析に成功した | 作られる |
| `ARGX_ERROR_INVALID_COMMAND_LINE` | コマンドラインに誤りがある | 作られる |
| `ARGX_ERROR_OUT_OF_MEMORY` | メモリ確保に失敗した | 作られない |

```c
error = argx_parse(root, argc, argv, &result);
switch (error)
{
case ARGX_ERROR_NONE:
    if (argx_result_flag(result, help))
    {
        status = print_help(root);
    }
    else
    {
        /* 値を読み取って処理する（後述） */
    }
    break;

case ARGX_ERROR_INVALID_COMMAND_LINE:
    print_parse_error(result);
    break;

default:
    fprintf(stderr, "greet: %s\n", argx_error_message(error));
    break;
}
```

`argx_result_flag`は、フラグが指定されたかどうかを`bool`で返します。

### 終端フラグで解析を終わらせる

`--help`を終端フラグにしているため、`--help`を読んだ時点で解析が終わり、`argx_parse`は`ARGX_ERROR_NONE`を返します。このとき、次のように動作します。

- `--help`より後ろの引数は読まれず、確認もされません。
- 必須の引数があるかは確認されません。そのため、`greet --help`は必須の位置引数`name`がなくても成功します。
- デフォルト値も適用されません。

| コマンドライン | 結果 |
| --- | --- |
| `greet --help` | 成功（`name`がなくてもよい） |
| `greet -h --bogus` | 成功（`--bogus`は読まれない） |
| `greet --bogus -h` | 解析エラー（`-h`より前の`--bogus`でエラーになる） |

つまり、**解析に成功しても、必須の値やデフォルト値が入っているとは限りません**。そのため、`ARGX_ERROR_NONE`のときは、ほかの値を読む前に`--help`を確認します。終端フラグで解析が終わったかどうかは、そのフラグを返す`argx_result_terminal_option`でも調べられます。`--help`と`--version`のように終端フラグが複数あるときに便利です。

`--help`を終端フラグにしない場合は、`greet --help`が`name`のない解析エラーになります。その場合は、解析エラーのときにも`argx_result_flag`で`--help`を確認する必要があります。

## ヘルプとエラーを出力する

ArgXは自分では何も出力しません。代わりに、テキストを書き込む関数を受け取り、ヘルプを分割して渡します。ここでは`fwrite`でストリームに書き込む関数を用意しています。

```c
static bool write_to_stream(void *user_data, const char *text, size_t length)
{
    return fwrite(text, 1, length, (FILE *)user_data) == length;
}

static int print_help(const argx_command_t *command)
{
    if (argx_help_write(command, NULL, write_to_stream, stdout) != ARGX_ERROR_NONE)
    {
        return EXIT_FAILURE;
    }
    return EXIT_SUCCESS;
}
```

`argx_help_write`の第4引数（`stdout`）は、そのまま書き込み関数の`user_data`として渡されます。第2引数には表示幅などを指定するヘルプオプションを渡せますが、`NULL`にすると既定の設定が使われます。

解析エラーのときは、エラーメッセージと使い方の行を標準エラー出力に書き込みます。

```c
static void print_parse_error(const argx_result_t *result)
{
    fprintf(stderr, "greet: %s\n", argx_result_error_message(result));
    argx_help_write_usage(argx_result_error_command(result), NULL, write_to_stream, stderr);
    fprintf(stderr, "For more information, try '--help'.\n");
}
```

`argx_result_error_message`は`missing required argument 'name'`のような1行のメッセージを返します。`argx_help_write_usage`は`Usage: greet [OPTIONS] <name>`の行だけを書き込みます。

## 値を読み取る

解析に成功したら、ハンドルを使って解析結果から値を取り出します。

```c
const char *text = NULL;
int64_t times = 0;
int64_t i;

if (argx_result_positional_string(result, name, 0, &text) &&
    argx_result_option_int(result, count, &times))
{
    for (i = 0; i < times; ++i)
    {
        printf("hello, %s%s\n", text, argx_result_flag(result, loud) ? "!" : "");
    }
    printf("greeted %" PRId64 " time(s)\n", times);
    status = EXIT_SUCCESS;
}
```

- `argx_result_positional_string`：位置引数の値を文字列で取り出します。第3引数は値の番号で、複数の値を取る位置引数のときに使います。
- `argx_result_option_int`：オプションの値を`int64_t`で取り出します。`-n`が省略された場合は、デフォルト値の`1`が入ります。

どちらも、値があれば`true`を返します。整数への変換は解析時に済んでいるため、ここで`strtol`などを呼ぶ必要はありません。

## 破棄する

最後に、解析結果、スキーマの順に破棄します。

```c
cleanup:
    argx_result_destroy(result);
    argx_command_destroy(root);
```

`NULL`を渡しても何もしないため、途中で失敗した場合も含めて、1か所の後始末で済ませられます。スキーマに追加したオプションや位置引数はコマンドと一緒に破棄されるため、ハンドルを個別に破棄する必要はありません。

## コード全体

`main.c`の全体は次のとおりです。

```c
#include <argx/argx.h>

#include <inttypes.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

/* 失敗する可能性のある呼び出しを確認し、失敗したら define_failed へ移動する */
#define TRY(call)                     \
    do                                \
    {                                 \
        error = (call);               \
        if (error != ARGX_ERROR_NONE) \
        {                             \
            goto define_failed;       \
        }                             \
    } while (0)

/* ライブラリはヘルプのテキストを分割してこの関数に渡す */
static bool write_to_stream(void *user_data, const char *text, size_t length)
{
    return fwrite(text, 1, length, (FILE *)user_data) == length;
}

/* command のヘルプを標準出力に書き込む */
static int print_help(const argx_command_t *command)
{
    if (argx_help_write(command, NULL, write_to_stream, stdout) != ARGX_ERROR_NONE)
    {
        return EXIT_FAILURE;
    }
    return EXIT_SUCCESS;
}

/* 解析エラーのメッセージと使い方の行を標準エラー出力に書き込む */
static void print_parse_error(const argx_result_t *result)
{
    fprintf(stderr, "greet: %s\n", argx_result_error_message(result));
    argx_help_write_usage(argx_result_error_command(result), NULL, write_to_stream, stderr);
    fprintf(stderr, "For more information, try '--help'.\n");
}

int main(int argc, char **argv)
{
    argx_command_t *root = NULL;
    argx_option_t *help = NULL;
    argx_option_t *loud = NULL;
    argx_option_t *count = NULL;
    argx_positional_t *name = NULL;
    argx_result_t *result = NULL;
    argx_error_t error;
    int status = EXIT_FAILURE;

    /* スキーマを定義する。説明文はヘルプに使われる */
    TRY(argx_command_create("greet", &root));
    TRY(argx_command_set_description(root, "Greet somebody."));
    TRY(argx_command_add_flag(root, 'h', "help", &help));
    TRY(argx_option_set_description(help, "Print this help."));
    TRY(argx_option_set_terminal(help, true)); /* "greet --help" は name がなくても成功する */
    TRY(argx_command_add_flag(root, 'l', "loud", &loud));
    TRY(argx_option_set_description(loud, "Add an exclamation mark."));
    TRY(argx_command_add_value(root, 'n', "count", argx_type_int(), &count));
    TRY(argx_option_set_description(count, "How often to greet."));
    TRY(argx_option_set_value_name(count, "COUNT"));
    TRY(argx_option_set_default(count, "1"));
    TRY(argx_command_add_positional(root, "name", argx_type_string(), ARGX_ARITY_REQUIRED, &name));
    TRY(argx_positional_set_description(name, "Whom to greet."));
    TRY(argx_command_validate(root, NULL, NULL, NULL));

    /* コマンドラインを解析し、戻り値で分岐する */
    error = argx_parse(root, argc, argv, &result);
    switch (error)
    {
    case ARGX_ERROR_NONE:
        /* --help で解析が終わったときは、値を読まずにヘルプを表示する */
        if (argx_result_flag(result, help))
        {
            status = print_help(root);
        }
        else
        {
            const char *text = NULL;
            int64_t times = 0;
            int64_t i;

            if (argx_result_positional_string(result, name, 0, &text) &&
                argx_result_option_int(result, count, &times))
            {
                for (i = 0; i < times; ++i)
                {
                    printf("hello, %s%s\n", text, argx_result_flag(result, loud) ? "!" : "");
                }
                printf("greeted %" PRId64 " time(s)\n", times);
                status = EXIT_SUCCESS;
            }
        }
        break;

    case ARGX_ERROR_INVALID_COMMAND_LINE:
        print_parse_error(result);
        break;

    default:
        /* ARGX_ERROR_OUT_OF_MEMORY。結果が作られない唯一のエラーコード */
        fprintf(stderr, "greet: %s\n", argx_error_message(error));
        break;
    }

    goto cleanup;

define_failed:
    fprintf(stderr, "greet: cannot define the command line: %s\n", argx_error_message(error));

cleanup:
    /* 結果、スキーマの順に破棄する。NULL の破棄は何もしない */
    argx_result_destroy(result);
    argx_command_destroy(root);

    return status;
}
```

## ビルドして実行する

`greet`ディレクトリで次のコマンドを実行し、ビルドします。初回の構成時に、CMakeがGitHubからArgXのソースを取得します。

```sh
cmake -S . -B build
cmake --build build
```

ビルドが終わると、`build/greet`が作られます。MSVCなどのマルチ構成のジェネレーターでは、`build/Debug/greet.exe`のように構成名のディレクトリに作られます。

### 正しいコマンドライン

```
$ ./build/greet --loud -n 2 world
hello, world!
hello, world!
greeted 2 time(s)
```

短いオプションはまとめて書くこともでき、`./build/greet -ln 2 world`も同じ結果になります。`--count=2`のように`=`で値を渡すこともできます。

### ヘルプの表示

```
$ ./build/greet --help
Usage: greet [OPTIONS] <name>

Greet somebody.

Arguments:
  <name>               Whom to greet.

Options:
  -h, --help           Print this help.
  -l, --loud           Add an exclamation mark.
  -n, --count <COUNT>  How often to greet. [default: 1]
```

スキーマに設定した説明文、値の名前、デフォルト値から、ヘルプが自動で生成されています。`--help`は終端フラグなので、`name`を指定していなくてもヘルプが表示され、終了コードは0になります。

### 誤ったコマンドライン

必須の位置引数がない場合や、整数に変換できない値を渡した場合は、エラーメッセージと使い方の行が表示され、終了コードは1になります。

```
$ ./build/greet
greet: missing required argument 'name'
Usage: greet [OPTIONS] <name>
For more information, try '--help'.

$ ./build/greet --count=many world
greet: invalid value 'many' for option '--count' (expected integer)
Usage: greet [OPTIONS] <name>
For more information, try '--help'.

$ ./build/greet -x world
greet: unknown option '-x'
Usage: greet [OPTIONS] <name>
For more information, try '--help'.
```

型の検証やエラーメッセージを自分で書かなくても、これだけのチェックが行われます。

## さらに使いこなす

ArgXには、この記事で扱わなかった機能もあります。

- **サブコマンド**：`argx_command_add_subcommand`で、`git commit`のようなサブコマンドを定義できます。サブコマンドの中にさらにサブコマンドを入れることもできます。
- **グローバルオプション**：`argx_option_set_global`で、サブコマンドの前にも後ろにも書けるオプションにできます。
- **回数と否定できるフラグ**：`argx_command_add_count`で`-vvv`のように指定回数を数えるオプションを、`argx_command_add_negatable`で`--color`と`--no-color`の組を定義できます。
- **リストオプション**：`argx_command_add_list`で、`-I a -I b`や`--keys a,b`のように指定されたすべての値を集めるオプションを定義できます。
- **選択肢と独自の型**：`argx_type_create_choice`で`tar`、`zip`のような選択肢を、`argx_type_create`で独自の変換を行う型を作れます。
- **ヘルプのカスタマイズ**：表示幅をターミナルに合わせたり、ヘルプを文字列として受け取ったりできます。日本語のような全角文字の説明文も、表示幅を測る関数を渡せば揃えて折り返せます。
- **Windowsのワイド文字**：`argx_parse_wide`で`wmain`の引数をそのまま解析できます。

サブコマンドや独自の型を使った例は、リポジトリの[examples/pack/pack.c](https://github.com/vabelorg/argx/blob/main/examples/pack/pack.c)にあり、[Tutorial](https://github.com/vabelorg/argx/blob/main/docs/getting-started/tutorial.md)で順に解説されています。具体的な使い方は[How-to](https://github.com/vabelorg/argx/blob/main/docs/guides/how-to.md)と[FAQ](https://github.com/vabelorg/argx/blob/main/docs/guides/faq.md)を参照してください。

## まとめ

ArgXを使うと、コマンドラインの仕様をスキーマとして一度定義するだけで、解析、型変換、エラーメッセージ、ヘルプまでをまとめて扱えます。ライブラリ自身は何も出力せず、プロセスも終了させないため、出力先や終了コードを自由に決められるのも利点です。

C言語でコマンドラインツールを作るときは、`getopt`の代わりに使ってみてはいかがでしょうか。
