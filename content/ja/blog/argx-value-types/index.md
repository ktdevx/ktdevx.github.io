---
title: 【C言語】ArgXのオプションの種類と値の型を使いこなす
date: 2026-11-17T00:00:00+09:00
draft: false
tags:
  - C
  - CMake
  - ArgX
params:
  toc: true
---

コマンドラインツールでは、`-vvv`のように重ねて指定するオプション、`--no-color`のように打ち消すオプション、`-I a -I b`のように値を何個でも受け取るオプション、`tar`か`zip`のように決まった値だけを受け付けるオプションがよく使われます。

ここでは、C99向けのコマンドライン引数パーサー「[ArgX](https://github.com/vabelorg/argx)」で、こうしたオプションの種類と値の型を使い分ける方法を解説します。ArgXの基本的な使い方（スキーマの定義、検証、解析、値の読み取り、破棄）は「[【C言語】ArgXでコマンドライン引数を解析する](/blog/argx-usage)」で解説しているため、先にそちらを読んでおくと理解しやすくなります。

## 前提条件

これまでの記事と同じく、次の環境を前提とします。

- CMake 3.21以上
- C99に対応したCコンパイラ（GCC、Clang、MSVCなど）
- Git

記事の手順はUbuntu 24.04、CMake 3.28、GCC 13で動作を確認しています。ArgXのバージョンは`v0.2.0`です。

## プロジェクトを準備する

次の構成のプロジェクトを作ります。

```
chunk/
├── CMakeLists.txt
└── main.c
```

`CMakeLists.txt`はこれまでの記事とほぼ同じで、実行ファイルの名前だけを`chunk`に変えています。

```cmake
cmake_minimum_required(VERSION 3.21)
project(chunk LANGUAGES C)

include(FetchContent)
FetchContent_Declare(ArgX
    GIT_REPOSITORY https://github.com/vabelorg/argx.git
    GIT_TAG v0.2.0
)
FetchContent_MakeAvailable(ArgX)

add_executable(chunk main.c)
target_link_libraries(chunk PRIVATE ArgX::argx)
```

## 作るプログラム

この記事では、ファイルを決まった大きさの断片に分割する架空のツール`chunk`を作ります。実際にはファイルを読まず、受け取った設定とファイル名を表示するだけのプログラムです。受け付けるコマンドラインは次のとおりです。

```
chunk [-h] [-v]... [--color | --no-color] [--naming numeric|alpha] [-s SIZE] [--merge RATIO]
      [-e PATTERN[,PATTERN...]]... <file>...
```

| 引数 | 種類 | 意味 |
| --- | --- | --- |
| `-h`, `--help` | フラグ | ヘルプを表示する |
| `-v`, `--verbose` | 回数を数えるオプション | 重ねるほど詳しく表示する |
| `--color`, `--no-color` | 否定できるフラグ | 出力に色を付けるか。省略時はオン |
| `--naming` | 値を取るオプション（選択肢） | 断片の名前の付け方。`numeric`か`alpha`。省略時は`numeric` |
| `-s`, `--size` | 値を取るオプション（独自の型） | 断片の大きさ。`10K`や`4M`のように単位を付けられる。省略時は`1M` |
| `--merge` | 値を取るオプション（浮動小数点数） | 最後の断片が`SIZE`のこの割合より小さければ、1つ前の断片に結合する。省略時は`0.1` |
| `-e`, `--exclude` | リストオプション（文字列） | 分割しないファイルのパターン。何回でも指定でき、`,`で区切って複数書ける |
| `file` | 位置引数（1個以上） | 分割するファイル |

以降では`main.c`の内容を順に説明します。コード全体は「[コード全体](#コード全体)」に掲載しています。エラー処理の`TRY`マクロ、ヘルプとエラーを出力する`print_help`と`print_parse_error`、`-h`, `--help`を終端フラグにして解析結果を分岐する方法は、入門記事と同じです。

## オプションの種類

ArgXのオプションには、次の5種類があります。

| 種類 | 追加する関数 | 解析結果の読み取り |
| --- | --- | --- |
| フラグ | `argx_command_add_flag` | `argx_result_flag`（`bool`） |
| 否定できるフラグ | `argx_command_add_negatable` | `argx_result_flag`（`bool`） |
| 回数を数えるオプション | `argx_command_add_count` | `argx_result_count`（`size_t`） |
| 値を取るオプション | `argx_command_add_value` | 値の型に応じた`argx_result_option_*` |
| リストオプション | `argx_command_add_list` | 値の型に応じた`argx_result_option_*_at` |

フラグと値を取るオプションは入門記事で扱いました。ここでは回数を数えるオプションと否定できるフラグを説明します。リストオプションは値の型と組み合わせて使うため、後述の「[リストオプション](#リストオプション)」で説明します。

### 回数を数えるオプション

`-v`を重ねた回数で表示の詳しさを変えるようなオプションは、`argx_command_add_count`で追加します。引数はフラグを追加する`argx_command_add_flag`と同じです。

```c
TRY(argx_command_add_count(root, 'v', "verbose", &verbose));
TRY(argx_option_set_description(verbose, "Print more; can be repeated."));
```

解析後は、`argx_result_count`で指定された回数を取り出します。

```c
size_t level = argx_result_count(result, verbose);
```

`-v -v`、`-vv`、`--verbose --verbose`はどれも2になり、指定がなければ0になります。`-vvv -v`のように書き方を混ぜても、合計の4になります。

### 否定できるフラグ

`--color`と`--no-color`のように、オンとオフを切り替えるフラグは`argx_command_add_negatable`で追加します。否定形の名前は`no-`と長い名前をつなげて自動で作られるため、**長い名前は必須**です。この例では短い名前を付けないため、`'\0'`を指定しています。

```c
TRY(argx_command_add_negatable(root, '\0', "color", &color));
TRY(argx_option_set_description(color, "Color the output."));
TRY(argx_option_set_initial(color, true));
```

`argx_option_set_initial`は、どちらも指定されなかったときの状態（初期状態）を設定します。既定は`false`で、ここでは色付きを標準にするため`true`にしています。

値は普通のフラグと同じく`argx_result_flag`で読み取ります。

```c
argx_result_flag(result, color) ? "on" : "off"
```

| コマンドライン | `argx_result_flag`の値 |
| --- | --- |
| どちらも指定しない | 初期状態（ここでは`true`） |
| `--color` | `true` |
| `--no-color` | `false` |
| `--no-color --color` | `true`（最後に指定したほう） |

否定形の名前は、ほかのオプションの名前と重複してはいけません。たとえば同じコマンドに`no-color`という長い名前のオプションがあると、`argx_command_add_negatable`が`ARGX_ERROR_NAME_CONFLICT`を返します。

## 値の型

値を取るオプション、リストオプション、位置引数には、それぞれ1つの値の型を指定します。値の型は、コマンドラインの文字列を検査し、値に変換するものです。ArgXには次の値の型があります。

| 値の型 | 取得・作成する関数 | 値のCの型 | 読み取る関数（オプション） |
| --- | --- | --- | --- |
| 文字列 | `argx_type_string()` | `const char *` | `argx_result_option_string` |
| 整数 | `argx_type_int()` | `int64_t` | `argx_result_option_int` |
| 浮動小数点数 | `argx_type_float()` | `double` | `argx_result_option_float` |
| 選択肢 | `argx_type_create_choice()` | `size_t`（選択肢の番号） | `argx_result_option_choice` |
| 独自の型 | `argx_type_create()` | 自分で決める | `argx_result_option_value` |

位置引数の値は、`_option_`を`_positional_`に変えた関数（`argx_result_positional_float`など）で読み取ります。

文字列、整数、浮動小数点数の型はライブラリが持っているため、作成も破棄も不要です。選択肢と独自の型は自分で作成し、使い終わったら`argx_type_destroy`で破棄します。

### 浮動小数点数

`argx_type_float()`を指定すると、値を`double`で受け取れます。

```c
TRY(argx_command_add_value(root, '\0', "merge", argx_type_float(), &merge));
TRY(argx_option_set_description(merge, "Merge a last piece smaller than RATIO of SIZE."));
TRY(argx_option_set_value_name(merge, "RATIO"));
TRY(argx_option_set_default(merge, "0.1"));
```

受け付けるのは`1`、`.5`、`-1.5e-3`のような10進数の表記です。小数点は、ロケールにかかわらず常に`.`です。前後の空白、無限大、NaN、16進数の表記は受け付けません。

```c
double ratio = 0.0;

argx_result_option_float(result, merge, &ratio);
```

### 選択肢

決まった値の中から1つを選ばせるときは、`argx_type_create_choice`で選択肢の型を作ります。

```c
static const char *const namings[] = { "numeric", "alpha" };
```

```c
TRY(argx_type_create_choice(namings, sizeof namings / sizeof namings[0], &naming_type));
```

```c
TRY(argx_command_add_value(root, '\0', "naming", naming_type, &naming));
TRY(argx_option_set_description(naming, "How to name the pieces."));
TRY(argx_option_set_default(naming, "numeric"));
```

`argx_type_create_choice`には、選択肢の文字列の配列と個数を渡します。文字列はコピーされるため、配列は型を作った後に解放しても問題ありません。選択肢が0個の場合や、同じ選択肢が2つある場合は`ARGX_ERROR_INVALID_DEFINITION`になります。

比較は大文字と小文字を区別する完全一致です。解析結果からは、一致した選択肢の**番号**を`size_t`で受け取ります。番号は配列の添字と同じなので、元の配列から文字列を引けます。

```c
size_t name_index = 0;

if (argx_result_option_choice(result, naming, &name_index))
{
    printf("naming: %s\n", namings[name_index]);
}
```

文字列を`strcmp`で比べる代わりに番号で`switch`できるのも、選択肢の型を使う利点です。

ヘルプには、選択肢の一覧が`[choices: numeric, alpha]`のように自動で表示されます（後述の「[ヘルプを表示する](#ヘルプを表示する)」を参照）。

### 独自の型

`10K`や`4M`のように単位付きでサイズを受け取りたいときなど、組み込みの型で表せない値は、`argx_type_create`で独自の型を作ります。

```c
argx_error_t argx_type_create(const char *name, size_t value_size,
                              argx_convert_fn_t convert_fn,
                              argx_release_fn_t release_fn, void *context,
                              argx_type_t **out);
```

| 引数 | 内容 |
| --- | --- |
| `name` | 型の名前。エラーメッセージの`(expected size)`などに使われる |
| `value_size` | 変換後の値の大きさ（バイト数） |
| `convert_fn` | 文字列を値に変換する関数 |
| `release_fn` | 値を後始末する関数。不要なら`NULL` |
| `context` | 2つの関数に渡されるユーザーデータ。不要なら`NULL` |

この記事では、サイズを`uint64_t`のバイト数に変換する型`size`を作ります。

```c
TRY(argx_type_create("size", sizeof(uint64_t), convert_size, NULL, NULL, &size_type));
```

変換関数`convert_size`は次のとおりです。数字の並びの後ろに、1024倍ごとの単位`K`、`M`、`G`（小文字も可）を1文字だけ付けられます。

```c
static argx_error_t convert_size(const char *text, void *value, void *context)
{
    const char *p = text;
    uint64_t number = 0;
    uint64_t unit = 1;

    (void)context;

    if ((*p < '0') || (*p > '9'))
    {
        return ARGX_ERROR_INVALID_VALUE;
    }
    for (; (*p >= '0') && (*p <= '9'); ++p)
    {
        uint64_t digit = (uint64_t)(*p - '0');

        if (number > ((UINT64_MAX - digit) / 10))
        {
            return ARGX_ERROR_INVALID_VALUE;
        }
        number = (number * 10) + digit;
    }

    switch (*p)
    {
    case 'K':
    case 'k':
        unit = UINT64_C(1) << 10;
        ++p;
        break;
    case 'M':
    case 'm':
        unit = UINT64_C(1) << 20;
        ++p;
        break;
    case 'G':
    case 'g':
        unit = UINT64_C(1) << 30;
        ++p;
        break;
    default:
        break;
    }

    if ((*p != '\0') || (number == 0) || (number > (UINT64_MAX / unit)))
    {
        return ARGX_ERROR_INVALID_VALUE;
    }

    *(uint64_t *)value = number * unit;
    return ARGX_ERROR_NONE;
}
```

変換関数を書くときの決まりは次のとおりです。

- `text`を変換できたら、結果を`value`に書き込んで`ARGX_ERROR_NONE`を返します。`value`は、`value_size`バイト以上の大きさがあり、どの型にも合うように配置されたバッファーです。
- 受け付けない文字列には`ARGX_ERROR_INVALID_VALUE`を返します。すると、解析は`invalid value ... (expected size)`という解析エラーになります。メモリ確保に失敗したときは`ARGX_ERROR_OUT_OF_MEMORY`を返します。
- **副作用を持たせてはいけません**。同じ入力には常に同じ結果を返す必要があります。変換関数は解析のときだけでなく、`argx_command_validate`でデフォルト値（ここでは`1M`）を確認するときにも呼ばれるためです。

この例では、`0`、桁あふれする値、`10X`のような未知の単位を受け付けないようにしています。

値の中で文字列を複製するなど、変換のたびに後始末が必要な場合は`release_fn`を指定します。`release_fn`は、成功した変換1回につき1回だけ呼ばれます。上限値などの設定を変換関数に渡したいときは、`context`にポインターを渡します。`context`は値の型を破棄するまで有効にしておく必要があります。

デフォルト値も検証で変換されるため、たとえば`argx_option_set_default(size, "1X")`のように変換できない値を設定すると、`argx_command_validate`が`ARGX_ERROR_INVALID_DEFAULT`を返します。

```
chunk: cannot define the command line: default value rejected by its value type
```

独自の型の値は、`argx_result_option_value`で読み取ります。変換関数が書き込んだバッファーへのポインターが返るため、自分で決めたCの型として読み取ります。

```c
const uint64_t *bytes = argx_result_option_value(result, size);

if (bytes != NULL)
{
    printf("size: %" PRIu64 " bytes\n", *bytes);
}
```

値がない場合は`NULL`が返ります。この例ではデフォルト値があるため、解析に成功していれば必ず値があります。

## 複数の値を取る位置引数

位置引数の個数は、`argx_command_add_positional`の第4引数（arity）で指定します。

| arity | 値の個数 |
| --- | --- |
| `ARGX_ARITY_REQUIRED` | ちょうど1個 |
| `ARGX_ARITY_OPTIONAL` | 0個か1個 |
| `ARGX_ARITY_ZERO_OR_MORE` | 0個以上 |
| `ARGX_ARITY_ONE_OR_MORE` | 1個以上 |

`chunk`は分割するファイルを1つ以上受け取るため、`ARGX_ARITY_ONE_OR_MORE`を指定します。

```c
TRY(argx_command_add_positional(root, "file", argx_type_string(), ARGX_ARITY_ONE_OR_MORE,
                                &files));
TRY(argx_positional_set_description(files, "The files to split."));
```

値は`argx_result_positional_count`で個数を調べ、番号を指定して1つずつ取り出します。番号はコマンドラインに書かれた順に0から始まります。

```c
for (i = 0; i < argx_result_positional_count(result, files); ++i)
{
    if (argx_result_positional_string(result, files, i, &file))
    {
        printf("  %s\n", file);
    }
}
```

複数の値を取る位置引数には、次の制約があります。違反すると`argx_command_validate`が`ARGX_ERROR_INVALID_DEFINITION`を返します。

- `ARGX_ARITY_ZERO_OR_MORE`と`ARGX_ARITY_ONE_OR_MORE`の後ろには、位置引数を追加できません。
- `ARGX_ARITY_OPTIONAL`と`ARGX_ARITY_ZERO_OR_MORE`の後ろには、`ARGX_ARITY_REQUIRED`と`ARGX_ARITY_ONE_OR_MORE`を追加できません。

`-`で始まるファイル名を渡したいときは、`--`の後ろに書くと、オプションではなく位置引数として扱われます。

## リストオプション

値を取るオプションを複数回指定すると、最後の値だけが使われます。`-I dir1 -I dir2`や`--exclude '*.log' --exclude '*.tmp'`のように、指定されたすべての値を使いたいときは、`argx_command_add_list`で**リストオプション**を追加します。引数は値を取るオプションを追加する`argx_command_add_value`と同じです。

```c
TRY(argx_command_add_list(root, 'e', "exclude", argx_type_string(), &exclude));
TRY(argx_option_set_description(exclude, "Skip the files that match."));
TRY(argx_option_set_value_name(exclude, "PATTERN"));
TRY(argx_option_set_separator(exclude, ','));
```

`argx_option_set_separator`は、1つの値を複数の項目に分ける区切り文字を設定します。ここでは`,`を設定しているため、`-e '*.log' --exclude '*.tmp,*.bak'`は`*.log`、`*.tmp`、`*.bak`の3つの項目になります。区切り文字に使えるのはASCIIの記号だけで、設定しなければ値は分割されません。

| コマンドライン（区切り文字`,`） | 項目 |
| --- | --- |
| `-e a -e b` | `a`、`b` |
| `--exclude a,b -ec` | `a`、`b`、`c` |
| 指定しない | なし（0個） |
| `-e a,,b` | 解析エラー（空の項目がある） |

項目はそれぞれ値の型で変換されます。たとえば`argx_type_int()`のリストオプションなら、`--ports 80,443`は2つの整数になります。

解析後は、複数の値を取る位置引数と同じように、`argx_result_option_value_count`で個数を調べ、番号を指定して1つずつ取り出します。番号は、コマンドラインに書かれた順に0から始まります。

```c
for (i = 0; i < argx_result_option_value_count(result, exclude); ++i)
{
    const char *pattern = NULL;

    if (argx_result_option_string_at(result, exclude, i, &pattern))
    {
        printf("  exclude %s\n", pattern);
    }
}
```

値を読み取る関数は、通常の関数の名前に`_at`を付けたもの（`argx_result_option_int_at`、`argx_result_option_value_at`など）です。リストオプションの値は、番号のない`argx_result_option_string`などでは読み取れません。

リストオプションには、`argx_option_set_default`の代わりに`argx_option_add_default`でデフォルト値を1項目ずつ追加できます。デフォルト値は、コマンドラインで一度も指定されなかったときだけ使われ、指定されたときは追加ではなく置き換えになります。

## 値の出どころを調べる

デフォルト値があるオプションは、解析に成功すれば必ず値を持ちます。そのため、値を読み取っただけでは、ユーザーが指定した値なのかデフォルト値なのかを区別できません。これを調べるのが`argx_result_option_source`です。

```c
printf("  --size from %s\n", source_text(argx_result_option_source(result, size)));
```

戻り値は`argx_source_t`で、次のいずれかです。

| 値 | 意味 |
| --- | --- |
| `ARGX_SOURCE_COMMAND_LINE` | コマンドラインで指定された |
| `ARGX_SOURCE_DEFAULT` | 指定されず、デフォルト値（フラグなどは初期状態）が使われた |
| `ARGX_SOURCE_NONE` | 値がない（指定されず、デフォルト値もない） |

フラグ、否定できるフラグ、回数を数えるオプションは、指定がなくても`false`、初期状態、0という値を持つため、指定されなければ`ARGX_SOURCE_DEFAULT`になります。位置引数の出どころは`argx_result_positional_source`で調べられます。

サンプルでは、`argx_source_t`を表示用の文字列に変換する関数を用意しています。今後のバージョンで値が追加される可能性があるため、`switch`には`default`を書いておきます。

```c
static const char *source_text(argx_source_t source)
{
    switch (source)
    {
    case ARGX_SOURCE_COMMAND_LINE:
        return "command line";
    case ARGX_SOURCE_DEFAULT:
        return "default";
    default:
        return "none";
    }
}
```

`chunk`では、`-v`を指定したときだけ、各オプションの値の出どころを表示します。

## 値の型を破棄する順序

スキーマは、選択肢と独自の型を**借りている**だけで、コピーはしていません。そのため、値の型はそれを使うスキーマよりも長く有効にしておく必要があります。破棄は次の順序で行います。

1. 解析結果（`argx_result_destroy`）
2. スキーマ（`argx_command_destroy`）
3. 値の型（`argx_type_destroy`）
4. 値の型の`context`（使っている場合）

```c
cleanup:
    argx_result_destroy(result);
    argx_command_destroy(root);
    argx_type_destroy(size_type);
    argx_type_destroy(naming_type);
```

順序を誤っても検出されず、解放済みのメモリを使う不具合になるため注意してください。作成は逆に、値の型を先、スキーマを後にします。

どの関数も`NULL`を渡すと何もしないため、途中で失敗した場合も同じ後始末で済みます。`argx_type_int()`などの組み込みの型は`argx_type_destroy`に渡しても無視されますが、そもそも破棄する必要はありません。

## コード全体

`main.c`の全体は次のとおりです。

```c
#include <argx/argx.h>

#include <inttypes.h>
#include <stdbool.h>
#include <stdint.h>
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

/* --naming の選択肢。値はこの配列の番号で受け取る */
static const char *const namings[] = { "numeric", "alpha" };

/*
 * 型 "size" の変換関数。"512"、"10K"、"4M"、"1G" のような文字列を
 * バイト数（uint64_t）に変換する。受け付けない文字列には ARGX_ERROR_INVALID_VALUE を返す
 */
static argx_error_t convert_size(const char *text, void *value, void *context)
{
    const char *p = text;
    uint64_t number = 0;
    uint64_t unit = 1;

    (void)context;

    if ((*p < '0') || (*p > '9'))
    {
        return ARGX_ERROR_INVALID_VALUE;
    }
    for (; (*p >= '0') && (*p <= '9'); ++p)
    {
        uint64_t digit = (uint64_t)(*p - '0');

        if (number > ((UINT64_MAX - digit) / 10))
        {
            return ARGX_ERROR_INVALID_VALUE;
        }
        number = (number * 10) + digit;
    }

    switch (*p)
    {
    case 'K':
    case 'k':
        unit = UINT64_C(1) << 10;
        ++p;
        break;
    case 'M':
    case 'm':
        unit = UINT64_C(1) << 20;
        ++p;
        break;
    case 'G':
    case 'g':
        unit = UINT64_C(1) << 30;
        ++p;
        break;
    default:
        break;
    }

    if ((*p != '\0') || (number == 0) || (number > (UINT64_MAX / unit)))
    {
        return ARGX_ERROR_INVALID_VALUE;
    }

    *(uint64_t *)value = number * unit;
    return ARGX_ERROR_NONE;
}

/* 値の出どころを表示用の文字列にする */
static const char *source_text(argx_source_t source)
{
    switch (source)
    {
    case ARGX_SOURCE_COMMAND_LINE:
        return "command line";
    case ARGX_SOURCE_DEFAULT:
        return "default";
    default:
        return "none";
    }
}

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
    fprintf(stderr, "chunk: %s\n", argx_result_error_message(result));
    argx_help_write_usage(argx_result_error_command(result), NULL, write_to_stream, stderr);
    fprintf(stderr, "For more information, try '--help'.\n");
}

int main(int argc, char **argv)
{
    argx_type_t *naming_type = NULL;
    argx_type_t *size_type = NULL;
    argx_command_t *root = NULL;
    argx_option_t *help = NULL;
    argx_option_t *verbose = NULL;
    argx_option_t *color = NULL;
    argx_option_t *naming = NULL;
    argx_option_t *size = NULL;
    argx_option_t *merge = NULL;
    argx_option_t *exclude = NULL;
    argx_positional_t *files = NULL;
    argx_result_t *result = NULL;
    argx_error_t error;
    int status = EXIT_FAILURE;

    /* 値の型を作る。スキーマより先に作り、スキーマより後に破棄する */
    TRY(argx_type_create_choice(namings, sizeof namings / sizeof namings[0], &naming_type));
    TRY(argx_type_create("size", sizeof(uint64_t), convert_size, NULL, NULL, &size_type));

    /* スキーマを定義する */
    TRY(argx_command_create("chunk", &root));
    TRY(argx_command_set_description(root, "Split files into pieces."));
    TRY(argx_command_add_flag(root, 'h', "help", &help));
    TRY(argx_option_set_description(help, "Print this help."));
    TRY(argx_option_set_terminal(help, true));

    /* 回数を数えるオプション：-v、-vv、--verbose */
    TRY(argx_command_add_count(root, 'v', "verbose", &verbose));
    TRY(argx_option_set_description(verbose, "Print more; can be repeated."));

    /* 否定できるフラグ：--color と --no-color。指定がなければオン */
    TRY(argx_command_add_negatable(root, '\0', "color", &color));
    TRY(argx_option_set_description(color, "Color the output."));
    TRY(argx_option_set_initial(color, true));

    /* 選択肢 */
    TRY(argx_command_add_value(root, '\0', "naming", naming_type, &naming));
    TRY(argx_option_set_description(naming, "How to name the pieces."));
    TRY(argx_option_set_default(naming, "numeric"));

    /* 独自の型 */
    TRY(argx_command_add_value(root, 's', "size", size_type, &size));
    TRY(argx_option_set_description(size, "The size of a piece."));
    TRY(argx_option_set_value_name(size, "SIZE"));
    TRY(argx_option_set_default(size, "1M"));

    /* 浮動小数点数 */
    TRY(argx_command_add_value(root, '\0', "merge", argx_type_float(), &merge));
    TRY(argx_option_set_description(merge, "Merge a last piece smaller than RATIO of SIZE."));
    TRY(argx_option_set_value_name(merge, "RATIO"));
    TRY(argx_option_set_default(merge, "0.1"));

    /* リストオプション：指定されたすべての値を集める。値は "," でも区切れる */
    TRY(argx_command_add_list(root, 'e', "exclude", argx_type_string(), &exclude));
    TRY(argx_option_set_description(exclude, "Skip the files that match."));
    TRY(argx_option_set_value_name(exclude, "PATTERN"));
    TRY(argx_option_set_separator(exclude, ','));

    /* 1つ以上の値を取る位置引数 */
    TRY(argx_command_add_positional(root, "file", argx_type_string(), ARGX_ARITY_ONE_OR_MORE,
                                    &files));
    TRY(argx_positional_set_description(files, "The files to split."));

    TRY(argx_command_validate(root, NULL, NULL, NULL));

    /* コマンドラインを解析し、戻り値で分岐する */
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
            size_t level = argx_result_count(result, verbose);
            size_t name_index = 0;
            const uint64_t *bytes = argx_result_option_value(result, size);
            double ratio = 0.0;
            const char *file = NULL;
            size_t i;

            if ((bytes != NULL) && argx_result_option_choice(result, naming, &name_index) &&
                argx_result_option_float(result, merge, &ratio))
            {
                printf("size: %" PRIu64 " bytes, naming: %s, merge: %.2f, color: %s\n", *bytes,
                       namings[name_index], ratio,
                       argx_result_flag(result, color) ? "on" : "off");

                if (level >= 1)
                {
                    printf("verbose: %lu\n", (unsigned long)level);
                    printf("  --size from %s\n",
                           source_text(argx_result_option_source(result, size)));
                    printf("  --naming from %s\n",
                           source_text(argx_result_option_source(result, naming)));
                    printf("  --merge from %s\n",
                           source_text(argx_result_option_source(result, merge)));
                }

                /* リストオプションの値は、番号を指定して1つずつ取り出す */
                for (i = 0; i < argx_result_option_value_count(result, exclude); ++i)
                {
                    const char *pattern = NULL;

                    if (argx_result_option_string_at(result, exclude, i, &pattern))
                    {
                        printf("  exclude %s\n", pattern);
                    }
                }

                for (i = 0; i < argx_result_positional_count(result, files); ++i)
                {
                    if (argx_result_positional_string(result, files, i, &file))
                    {
                        printf("  %s\n", file);
                    }
                }
                status = EXIT_SUCCESS;
            }
        }
        break;

    case ARGX_ERROR_INVALID_COMMAND_LINE:
        print_parse_error(result);
        break;

    default:
        /* ARGX_ERROR_OUT_OF_MEMORY。結果が作られない唯一のエラーコード */
        fprintf(stderr, "chunk: %s\n", argx_error_message(error));
        break;
    }

    goto cleanup;

define_failed:
    fprintf(stderr, "chunk: cannot define the command line: %s\n", argx_error_message(error));

cleanup:
    /* 結果、スキーマ、値の型の順に破棄する。NULL の破棄は何もしない */
    argx_result_destroy(result);
    argx_command_destroy(root);
    argx_type_destroy(size_type);
    argx_type_destroy(naming_type);

    return status;
}
```

## ビルドして実行する

`chunk`ディレクトリで次のコマンドを実行し、ビルドします。

```sh
cmake -S . -B build
cmake --build build
```

### オプションを省略する

オプションをすべて省略すると、デフォルト値と初期状態が使われます。

```
$ ./build/chunk a.bin b.bin
size: 1048576 bytes, naming: numeric, merge: 0.10, color: on
  a.bin
  b.bin
```

`-v`を付けると、値がすべてデフォルト値から来ていることを確認できます。

```
$ ./build/chunk -v a.bin
size: 1048576 bytes, naming: numeric, merge: 0.10, color: on
verbose: 1
  --size from default
  --naming from default
  --merge from default
  a.bin
```

### オプションを指定する

```
$ ./build/chunk -vv --no-color --naming=alpha -s 10K --merge 0.25 a.bin
size: 10240 bytes, naming: alpha, merge: 0.25, color: off
verbose: 2
  --size from command line
  --naming from command line
  --merge from command line
  a.bin
```

`10K`が独自の型で10240バイトに変換され、値の出どころが`command line`に変わっています。値はほかのオプションと同じく`-s4m`や`--merge=.5`のようにも書けます。

```
$ ./build/chunk --merge=.5 -s4m a.bin
size: 4194304 bytes, naming: numeric, merge: 0.50, color: on
  a.bin
```

否定できるフラグは、最後に指定したほうが使われます。

```
$ ./build/chunk --no-color --color a.bin
size: 1048576 bytes, naming: numeric, merge: 0.10, color: on
  a.bin
```

リストオプションは、指定したすべての値が、書いた順に`,`で分割されて取り出されます。

```
$ ./build/chunk -e '*.log' --exclude '*.tmp,*.bak' a.bin b.bin
size: 1048576 bytes, naming: numeric, merge: 0.10, color: on
  exclude *.log
  exclude *.tmp
  exclude *.bak
  a.bin
  b.bin
```

### ヘルプを表示する

```
$ ./build/chunk --help
Usage: chunk [OPTIONS] <file>...

Split files into pieces.

Arguments:
  <file>...                     The files to split.

Options:
  -h, --help                    Print this help.
  -v, --verbose...              Print more; can be repeated.
      --[no-]color              Color the output. [default: on]
      --naming <choice>         How to name the pieces. [choices: numeric,
                                alpha] [default: numeric]
  -s, --size <SIZE>             The size of a piece. [default: 1M]
      --merge <RATIO>           Merge a last piece smaller than RATIO of SIZE.
                                [default: 0.1]
  -e, --exclude <PATTERN>[,<PATTERN>...]
                                Skip the files that match. [repeatable]
```

オプションの種類と値の型に応じて、ヘルプの表示も変わります。

- 回数を数えるオプションは`--verbose...`のように`...`が付き、重ねて指定できることがわかります。
- 否定できるフラグは`--[no-]color`と表示され、初期状態が`[default: on]`で示されます。
- 選択肢は`[choices: numeric, alpha]`で一覧が示されます。値の名前を設定していないため、値の部分には型の名前が`<choice>`と表示されています。
- 1つ以上の値を取る位置引数は`<file>...`と表示されます。
- 区切り文字を設定したリストオプションは`<PATTERN>[,<PATTERN>...]`と表示され、何回でも指定できることが`[repeatable]`で示されます。

`--exclude`の見出しは長いため、説明は次の行から始まっています。説明の列は最も長い見出しに合わせて右に寄りますが、上限があるため、上限を超える見出しの説明だけが次の行に回ります。

### 誤ったコマンドライン

値の型に合わない値を渡すと、型の名前を含むエラーメッセージが表示され、終了コードは1になります。独自の型でも、変換関数が`ARGX_ERROR_INVALID_VALUE`を返すだけで同じ形式のメッセージになります。

```
$ ./build/chunk -s 10X a.bin
chunk: invalid value '10X' for option '-s' (expected size)
Usage: chunk [OPTIONS] <file>...
For more information, try '--help'.

$ ./build/chunk --naming zip a.bin
chunk: invalid value 'zip' for option '--naming' (expected choice)
Usage: chunk [OPTIONS] <file>...
For more information, try '--help'.

$ ./build/chunk --merge 1e a.bin
chunk: invalid value '1e' for option '--merge' (expected float)
Usage: chunk [OPTIONS] <file>...
For more information, try '--help'.

$ ./build/chunk -e '*.log,,*.tmp' a.bin
chunk: option '-e' has an empty item in '*.log,,*.tmp'
Usage: chunk [OPTIONS] <file>...
For more information, try '--help'.

$ ./build/chunk
chunk: missing required argument 'file'
Usage: chunk [OPTIONS] <file>...
For more information, try '--help'.
```

`--no-`の形は否定できるフラグにしかないため、`--no-verbose`は不明なオプションとしてエラーになります。

```
$ ./build/chunk --no-verbose a.bin
chunk: unknown option '--no-verbose'
Usage: chunk [OPTIONS] <file>...
For more information, try '--help'.
```

## まとめ

ArgXのオプションの種類と値の型を使い分けるときのポイントは次のとおりです。

- `-vvv`のように重ねるオプションは`argx_command_add_count`で追加し、`argx_result_count`で回数を読み取ります。
- `--color`と`--no-color`の組は`argx_command_add_negatable`で追加し、指定がないときの状態を`argx_option_set_initial`で設定します。
- 浮動小数点数は`argx_type_float()`で、ロケールに依存せずに`double`へ変換できます。
- 決まった値から選ばせるときは`argx_type_create_choice`を使い、選択肢の番号で値を受け取ります。
- 組み込みの型で表せない値は`argx_type_create`で独自の型にします。変換関数には副作用を持たせないようにします。
- 複数の値を取る位置引数は、`argx_result_positional_count`で個数を調べて1つずつ取り出します。
- 指定されたすべての値を集めるオプションは`argx_command_add_list`で追加し、`argx_result_option_value_count`と`_at`の付いた関数で1つずつ取り出します。`argx_option_set_separator`で、1つの値を区切り文字で分けることもできます。
- 値がコマンドラインで指定されたのかデフォルト値なのかは、`argx_result_option_source`で調べられます。
- 自分で作った値の型は、解析結果、スキーマの後に破棄します。

各関数の詳細は、公式ドキュメントの[Value Types](https://github.com/vabelorg/argx/blob/main/docs/references/types.md)、[Schemas](https://github.com/vabelorg/argx/blob/main/docs/references/schema.md)、[Parsing](https://github.com/vabelorg/argx/blob/main/docs/references/parse.md)を参照してください。サブコマンドと組み合わせた例は、リポジトリの[examples/pack/pack.c](https://github.com/vabelorg/argx/blob/main/examples/pack/pack.c)にあります。サブコマンドの使い方は「[【C言語】ArgXでサブコマンドを持つCLIを作る](/blog/argx-subcommands)」で解説しています。
