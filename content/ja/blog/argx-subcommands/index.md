---
title: 【C言語】ArgXでサブコマンドを持つCLIを作る
date: 2026-11-16T08:00:00+09:00
lastmod: 2026-11-17T08:00:00+09:00
draft: false
tags:
  - C
  - CMake
  - ArgX
params:
  toc: true
---

`git commit`や`docker run`のように、1つのコマンドの下に複数の機能を「サブコマンド」として持たせたCLIはよく見かけます。

ここでは、C99向けのコマンドライン引数パーサー「[ArgX](https://github.com/vabelorg/argx)」で、サブコマンドを持つCLIを作る方法を解説します。ArgXの基本的な使い方（スキーマの定義、検証、解析、値の読み取り、破棄）は「[【C言語】ArgXでコマンドライン引数を解析する](/blog/argx-usage)」で解説しているため、先にそちらを読んでおくと理解しやすくなります。

## 前提条件

前回の記事と同じく、次の環境を前提とします。

- CMake 3.21以上
- C99に対応したCコンパイラ（GCC、Clang、MSVCなど）
- Git

記事の手順はUbuntu 24.04、CMake 3.28、GCC 13で動作を確認しています。ArgXのバージョンは`v0.2.0`です。

`v0.2.0`でグローバルオプションと終端フラグが追加されたため、記事の内容を更新しました。`v0.1.x`では`-h`, `--help`をコマンドごとに定義し、ルートのオプションはサブコマンド名の前にしか書けませんでしたが、`v0.2.0`ではルートに1回定義するだけで、すべてのサブコマンドで使えます。

## プロジェクトを準備する

次の構成のプロジェクトを作ります。

```
todo/
├── CMakeLists.txt
└── main.c
```

`CMakeLists.txt`は前回の記事とほぼ同じで、実行ファイルの名前だけを`todo`に変えています。

```cmake
cmake_minimum_required(VERSION 3.21)
project(todo LANGUAGES C)

include(FetchContent)
FetchContent_Declare(ArgX
    GIT_REPOSITORY https://github.com/vabelorg/argx.git
    GIT_TAG v0.2.0
)
FetchContent_MakeAvailable(ArgX)

add_executable(todo main.c)
target_link_libraries(todo PRIVATE ArgX::argx)
```

## 作るプログラム

この記事では、タスクを管理する架空のツール`todo`を作ります。実際にはデータを保存せず、受け取った内容を表示するだけのプログラムです。受け付けるコマンドラインは次のとおりです。

```
todo [-h] [-q] <COMMAND>
todo add [-p PRIORITY] <text>
todo list [-a]
todo tag [COMMAND]
todo tag add <name>
todo tag remove <name>
```

| コマンド | 動作 | 引数 |
| --- | --- | --- |
| `todo` | ルート。サブコマンドが必須 | `-h`, `--help`：ヘルプを表示する<br>`-q`, `--quiet`：何も表示しない |
| `todo add` | タスクを追加する | `-p`, `--priority`：優先度（整数、省略時は3）<br>`text`：タスクの内容（必須） |
| `todo list` | タスクを一覧表示する | `-a`, `--all`：完了したタスクも含める |
| `todo tag` | タグを管理する。サブコマンドを省略するとタグを一覧表示する | なし |
| `todo tag add` | タグを追加する | `name`：タグの名前（必須） |
| `todo tag remove` | タグを削除する | `name`：タグの名前（必須） |

ルートの`-h`, `--help`と`-q`, `--quiet`は**グローバルオプション**で、`todo add -q "Buy milk"`のようにサブコマンド名の後ろにも書けます。`tag`の下にさらにサブコマンドがあること、`tag`だけはサブコマンドを省略できることもポイントです。

以降では`main.c`の内容を順に説明します。コード全体は「[コード全体](#コード全体)」に掲載しています。

## サブコマンドを定義する

サブコマンドは`argx_command_add_subcommand`で追加します。

```c
argx_error_t argx_command_add_subcommand(argx_command_t *command, const char *name,
                                         argx_command_t **out);
```

第1引数に親のコマンド、第2引数にサブコマンドの名前を指定すると、第3引数にサブコマンドのハンドル（`argx_command_t *`）が書き込まれます。**サブコマンドもルートと同じコマンド**なので、`argx_command_add_flag`や`argx_command_add_positional`などで、オプションや位置引数を同じように追加できます。

ただし、1つのコマンドに位置引数とサブコマンドの両方を持たせることはできません。`todo`や`todo tag`のようにサブコマンドを持つコマンドには、位置引数を追加しないようにします。

サンプルでは、サブコマンドを追加して説明を設定する関数を用意しています。

```c
static argx_error_t add_subcommand(argx_command_t *parent, const char *name,
                                   const char *description, argx_command_t **out)
{
    argx_error_t error;

    TRY(argx_command_add_subcommand(parent, name, out));
    return argx_command_set_description(*out, description);
}
```

今回のサンプルでは、前回の記事と違って定義を関数に分けているため、`TRY`マクロは失敗したときに`goto`ではなく`return error;`でエラーコードを返すようにしています。

```c
#define TRY(call)                     \
    do                                \
    {                                 \
        error = (call);               \
        if (error != ARGX_ERROR_NONE) \
        {                             \
            return error;             \
        }                             \
    } while (0)
```

### ハンドルを構造体にまとめる

サブコマンドが増えるとハンドルも増えるため、構造体にまとめておきます。解析後にどのコマンドが選ばれたかを判定したり、値を読み取ったりするときにも使います。

```c
typedef struct
{
    argx_command_t *root;
    argx_option_t *help;
    argx_option_t *quiet;

    argx_command_t *add;
    argx_option_t *priority;
    argx_positional_t *text;

    argx_command_t *list;
    argx_option_t *all;

    argx_command_t *tag;
    argx_command_t *tag_add;
    argx_positional_t *tag_add_name;
    argx_command_t *tag_remove;
    argx_positional_t *tag_remove_name;
} todo_schema_t;
```

### ルートとサブコマンドを定義する

ルートと、`add`、`list`の定義は次のとおりです。

```c
/* ルート: todo [-h] [-q] <COMMAND> */
TRY(argx_command_create("todo", &schema->root));
TRY(argx_command_set_description(schema->root, "Manage your tasks."));

/* -h, --help: 解析を終わらせる（terminal）、すべてのサブコマンドで使える（global） */
TRY(argx_command_add_flag(schema->root, 'h', "help", &schema->help));
TRY(argx_option_set_description(schema->help, "Print this help."));
TRY(argx_option_set_terminal(schema->help, true));
TRY(argx_option_set_global(schema->help, true));

/* -q, --quiet: サブコマンド名の前にも後ろにも書ける */
TRY(argx_command_add_flag(schema->root, 'q', "quiet", &schema->quiet));
TRY(argx_option_set_description(schema->quiet, "Print nothing."));
TRY(argx_option_set_global(schema->quiet, true));

/* todo add [-p PRIORITY] <text> */
TRY(add_subcommand(schema->root, "add", "Add a task.", &schema->add));
TRY(argx_command_add_value(schema->add, 'p', "priority", argx_type_int(), &schema->priority));
TRY(argx_option_set_description(schema->priority, "The priority of the task."));
TRY(argx_option_set_value_name(schema->priority, "PRIORITY"));
TRY(argx_option_set_default(schema->priority, "3"));
TRY(argx_command_add_positional(schema->add, "text", argx_type_string(), ARGX_ARITY_REQUIRED,
                                &schema->text));
TRY(argx_positional_set_description(schema->text, "What to do."));

/* todo list [-a] */
TRY(add_subcommand(schema->root, "list", "List the tasks.", &schema->list));
TRY(argx_command_add_flag(schema->list, 'a', "all", &schema->all));
TRY(argx_option_set_description(schema->all, "Include finished tasks."));
```

`add`と`list`は、オプションや位置引数を追加する先が、ルート（`schema->root`）ではなくサブコマンド（`schema->add`、`schema->list`）になっている点以外は、前回の記事と同じです。`argx_command_set_description`で設定した説明は、親コマンドのヘルプのサブコマンド一覧にも表示されます。

ルートの`-h`, `--help`と`-q`, `--quiet`には、`argx_option_set_global`で**グローバルオプション**の設定をしています。また`-h`, `--help`は、前回の記事と同じく`argx_option_set_terminal`で終端フラグにしています。どちらも後で詳しく説明します。

## ネストしたサブコマンドと省略可能なサブコマンド

`tag`の下に`add`と`remove`を追加します。サブコマンドの下にサブコマンドを追加するときも、親に`schema->tag`を指定するだけです。

```c
/* todo tag [COMMAND]: サブコマンドを省略すると、タグの一覧を表示する */
TRY(add_subcommand(schema->root, "tag", "Manage tags. Without a command, list the tags.",
                   &schema->tag));
TRY(argx_command_set_summary(schema->tag, "Manage tags."));
TRY(argx_command_set_subcommand_optional(schema->tag, true));

/* todo tag add <name> */
TRY(add_subcommand(schema->tag, "add", "Add a tag.", &schema->tag_add));
TRY(argx_command_add_positional(schema->tag_add, "name", argx_type_string(),
                                ARGX_ARITY_REQUIRED, &schema->tag_add_name));
TRY(argx_positional_set_description(schema->tag_add_name, "The name of the tag."));

/* todo tag remove <name> */
TRY(add_subcommand(schema->tag, "remove", "Remove a tag.", &schema->tag_remove));
TRY(argx_command_add_positional(schema->tag_remove, "name", argx_type_string(),
                                ARGX_ARITY_REQUIRED, &schema->tag_remove_name));
TRY(argx_positional_set_description(schema->tag_remove_name, "The name of the tag."));

return argx_command_validate(schema->root, NULL, NULL, NULL);
```

`tag add`の`add`と、ルートの`add`は同じ名前ですが、親が異なるため問題ありません。

### サブコマンド一覧の要約を設定する

`argx_command_set_summary`は、親コマンドのヘルプのサブコマンド一覧（`Commands:`）に表示する**要約**を設定します。要約を設定すると、一覧には要約が、`todo tag --help`には説明の全文が表示されます。要約を設定しない場合、一覧には説明の1行目が表示されます。

ここでは、`tag`の説明にサブコマンドを省略したときの動作まで書き、一覧には短い要約だけを表示しています（後述の「[ヘルプを表示する](#ヘルプを表示する)」を参照）。

### サブコマンドを省略可能にする

ArgXでは、**サブコマンドを持つコマンドは、既定でサブコマンドが必須**です。`todo`だけで実行すると、`ARGX_PARSE_ERROR_MISSING_SUBCOMMAND`という種類の解析エラーになります。

一方、`git remote`がサブコマンドなしでリモートの一覧を表示するように、サブコマンドを省略したときに独自の動作をさせたいこともあります。その場合は`argx_command_set_subcommand_optional`で`true`を設定します。この設定はコマンドごとで、ここでは`tag`だけを省略可能にし、ルートの`todo`はサブコマンドが必須のままにしています。

省略可能にすると、使い方の行の表記も変わります。

```
Usage: todo [OPTIONS] <COMMAND>       ← 必須
Usage: todo tag [OPTIONS] [COMMAND]   ← 省略可能
```

なお、サブコマンドを持たないコマンドに`true`を設定すると、`argx_command_validate`での検証がエラーになります。

## オプションを書く位置とグローバルオプション

ArgXでは、**オプションはそれを定義したコマンドでしか認識されず、サブコマンドには引き継がれません**。そのため、通常のオプションは、**それを定義したコマンド名の後ろ、かつ次のサブコマンド名の前**に書きます。`add`の`-p`は`add`の後ろに書く必要があり、`add`の前に書くと、ルートには`-p`が定義されていないためエラーになります。

```
$ ./build/todo -p 1 add "Buy milk"
todo: unknown option '-p'
Usage: todo [OPTIONS] <COMMAND>
For more information, try '--help'.
```

### グローバルオプション

`--help`や`--quiet`のようにプログラム全体に関わるオプションは、どのサブコマンドでも使えるほうが便利です。`argx_option_set_global`で`true`を設定したオプションは**グローバルオプション**になり、定義したコマンドと、その下のすべてのサブコマンドで認識されます。

ルートの`-q`はグローバルオプションなので、`add`の前にも後ろにも書けます。

```
$ ./build/todo -q add "Buy milk"
$ ./build/todo add -q "Buy milk"
```

どちらも`-q`が認識され、何も表示されずに終了コード0で終わります。`-h`, `--help`もグローバルオプションなので、ルートに1回定義するだけで`todo add --help`や`todo tag add --help`でも使えます。

グローバルオプションには、次の性質があります。

- **どこに書いても1つのオプション**です。サブコマンドにコピーされるわけではないため、`todo add -q`の`-q`も、定義したときのハンドル（`schema->quiet`）で読み取ります。
- 複数回書いた場合は、通常のオプションと同じ規則で扱われます。たとえば回数を数えるオプションなら、`-v add -v`は合計の2になります。
- 認識されるのは、定義したコマンドとその子孫だけです。サブコマンドに定義したグローバルオプションは、親コマンドでは使えません。
- 子孫のコマンドでは、グローバルオプションと同じ名前のオプションを定義できません。たとえば`add`に`-q`を追加すると、`argx_command_validate`が`ARGX_ERROR_NAME_CONFLICT`を返します。

なお、グローバルオプションではない場合は、親と子で同じ名前のオプションを定義でき、別々のオプションとして扱われます。

## 解析結果からコマンドを判定する

解析は前回と同じく`argx_parse`で行います。解析に成功したら、`argx_result_command`で**最後に選ばれたコマンド**を取得し、スキーマのハンドルと比較して処理を分けます。

```c
static int run(const todo_schema_t *schema, const argx_result_t *result)
{
    const argx_command_t *command = argx_result_command(result);
    const char *text = NULL;
    int64_t priority = 0;

    /* グローバルオプションは、どこに書かれても定義したルートのハンドルで読む */
    if (argx_result_flag(result, schema->quiet))
    {
        return EXIT_SUCCESS;
    }

    if (command == schema->add)
    {
        if (argx_result_positional_string(result, schema->text, 0, &text) &&
            argx_result_option_int(result, schema->priority, &priority))
        {
            printf("add \"%s\" (priority %" PRId64 ")\n", text, priority);
        }
    }
    else if (command == schema->list)
    {
        printf("list %s tasks\n", argx_result_flag(result, schema->all) ? "all" : "open");
    }
    else if (command == schema->tag)
    {
        /* サブコマンドを省略した "todo tag" */
        printf("list tags\n");
    }
    else if (command == schema->tag_add)
    {
        /* tag_add_name を読み取って表示する（省略） */
    }
    else if (command == schema->tag_remove)
    {
        /* tag_remove_name を読み取って表示する（省略） */
    }
    return EXIT_SUCCESS;
}
```

- `todo tag add work`では`schema->tag_add`、`todo tag`では`schema->tag`が返されます。ルートの`todo`はサブコマンドが必須のため、解析に成功した時点でルートが返されることはありません。
- 親のコマンドのオプション（ここでは`-q`）も、同じ解析結果から親のハンドルを使って読み取れます。グローバルオプションの`-q`は、`todo -q add`と`todo add -q`のどちらで指定されても`schema->quiet`で読み取れます。
- 選ばれなかったコマンドのオプションや位置引数は、「指定されなかった」ものとして読み取られます。

`todo -q tag add work`の場合、選ばれたコマンドは`todo`、`tag`、`tag add`の3つです。選ばれたコマンドはルートから順に`argx_result_command_count`と`argx_result_command_at`で取得でき、`argx_result_command`は最後の1つを返します。

## ヘルプとエラーを出力する

### --helpが指定されたかを調べる

`-h`, `--help`はルートに1つだけ定義したグローバルオプションなので、`todo --help`でも`todo tag add --help`でも、`argx_result_flag(result, schema.help)`だけで指定されたかを調べられます。

また、`-h`, `--help`は終端フラグなので、読み取った時点で解析が終わり、成功します。`todo add --help`は必須の`text`がなく、`todo --help`はサブコマンドがありませんが、どちらも解析エラーになりません。終端フラグより後ろは読まれないため、`todo --help add`はルートのヘルプになります。

### 選ばれたコマンドのヘルプを表示する

ヘルプは、最後に選ばれたコマンドについて表示します。終端フラグで解析が終わったときは、そのフラグを読んだ時点のコマンドが最後に選ばれたコマンドになります。これで、`todo --help`ではルートのヘルプが、`todo tag add --help`では`tag add`のヘルプが表示されます。

```c
static int print_help(const argx_result_t *result)
{
    if (argx_help_write(argx_result_command(result), NULL, write_to_stream, stdout) !=
        ARGX_ERROR_NONE)
    {
        return EXIT_FAILURE;
    }
    return EXIT_SUCCESS;
}
```

解析エラーのときは、`argx_result_error_command`でエラーが見つかったコマンドを取得し、そのコマンドの使い方の行を表示します。`todo tag add`で名前を省略した場合は、`Usage: todo tag add [OPTIONS] <name>`のように、サブコマンドまで含んだ使い方が表示されます。

```c
static void print_parse_error(const argx_result_t *result)
{
    fprintf(stderr, "todo: %s\n", argx_result_error_message(result));
    argx_help_write_usage(argx_result_error_command(result), NULL, write_to_stream, stderr);
    fprintf(stderr, "For more information, try '--help'.\n");
}
```

### サブコマンドがないときにヘルプを表示する

`argx_parse`の戻り値で分岐する部分は次のとおりです。

```c
error = argx_parse(schema.root, argc, argv, &result);
switch (error)
{
case ARGX_ERROR_NONE:
    if (argx_result_flag(result, schema.help))
    {
        status = print_help(result);
    }
    else
    {
        status = run(&schema, result);
    }
    break;

case ARGX_ERROR_INVALID_COMMAND_LINE:
    if (argx_result_error_kind(result) == ARGX_PARSE_ERROR_MISSING_SUBCOMMAND)
    {
        /* サブコマンドがないときは、そのコマンドのヘルプを表示して失敗で終わる */
        (void)print_help(result);
    }
    else
    {
        print_parse_error(result);
    }
    break;

default:
    fprintf(stderr, "todo: %s\n", argx_error_message(error));
    break;
}
```

前回の記事と同じく、解析に成功したときは、ほかの値を読む前に`--help`を確認します。終端フラグで解析が終わったときは、必須の値の確認もデフォルト値の適用もされていないためです。

解析エラーのときは、`argx_result_error_kind`で解析エラーの種類を調べています。サブコマンドがない（`ARGX_PARSE_ERROR_MISSING_SUBCOMMAND`）ときは、多くのCLIと同じように、そのコマンドのヘルプを表示します。何も処理していないため、終了コードは失敗（`status`の初期値の`EXIT_FAILURE`）のままにしています。

ヘルプではなく、ほかの解析エラーと同じようにエラーメッセージを表示したい場合は、この`else if`の分岐を削除します。その場合、`todo`だけで実行すると`todo: missing required command`と表示されます。

## コード全体

`main.c`の全体は次のとおりです。

```c
#include <argx/argx.h>

#include <inttypes.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

/* 失敗する可能性のある呼び出しを確認し、失敗したらそのエラーコードを返す */
#define TRY(call)                     \
    do                                \
    {                                 \
        error = (call);               \
        if (error != ARGX_ERROR_NONE) \
        {                             \
            return error;             \
        }                             \
    } while (0)

/* スキーマのハンドルをまとめた構造体 */
typedef struct
{
    argx_command_t *root;
    argx_option_t *help;
    argx_option_t *quiet;

    argx_command_t *add;
    argx_option_t *priority;
    argx_positional_t *text;

    argx_command_t *list;
    argx_option_t *all;

    argx_command_t *tag;
    argx_command_t *tag_add;
    argx_positional_t *tag_add_name;
    argx_command_t *tag_remove;
    argx_positional_t *tag_remove_name;
} todo_schema_t;

/* サブコマンドを追加し、説明を設定する */
static argx_error_t add_subcommand(argx_command_t *parent, const char *name,
                                   const char *description, argx_command_t **out)
{
    argx_error_t error;

    TRY(argx_command_add_subcommand(parent, name, out));
    return argx_command_set_description(*out, description);
}

/* スキーマを定義する */
static argx_error_t define_schema(todo_schema_t *schema)
{
    argx_error_t error;

    /* ルート: todo [-h] [-q] <COMMAND> */
    TRY(argx_command_create("todo", &schema->root));
    TRY(argx_command_set_description(schema->root, "Manage your tasks."));

    /* -h, --help: 解析を終わらせる（terminal）、すべてのサブコマンドで使える（global） */
    TRY(argx_command_add_flag(schema->root, 'h', "help", &schema->help));
    TRY(argx_option_set_description(schema->help, "Print this help."));
    TRY(argx_option_set_terminal(schema->help, true));
    TRY(argx_option_set_global(schema->help, true));

    /* -q, --quiet: サブコマンド名の前にも後ろにも書ける */
    TRY(argx_command_add_flag(schema->root, 'q', "quiet", &schema->quiet));
    TRY(argx_option_set_description(schema->quiet, "Print nothing."));
    TRY(argx_option_set_global(schema->quiet, true));

    /* todo add [-p PRIORITY] <text> */
    TRY(add_subcommand(schema->root, "add", "Add a task.", &schema->add));
    TRY(argx_command_add_value(schema->add, 'p', "priority", argx_type_int(), &schema->priority));
    TRY(argx_option_set_description(schema->priority, "The priority of the task."));
    TRY(argx_option_set_value_name(schema->priority, "PRIORITY"));
    TRY(argx_option_set_default(schema->priority, "3"));
    TRY(argx_command_add_positional(schema->add, "text", argx_type_string(), ARGX_ARITY_REQUIRED,
                                    &schema->text));
    TRY(argx_positional_set_description(schema->text, "What to do."));

    /* todo list [-a] */
    TRY(add_subcommand(schema->root, "list", "List the tasks.", &schema->list));
    TRY(argx_command_add_flag(schema->list, 'a', "all", &schema->all));
    TRY(argx_option_set_description(schema->all, "Include finished tasks."));

    /* todo tag [COMMAND]: サブコマンドを省略すると、タグの一覧を表示する */
    TRY(add_subcommand(schema->root, "tag", "Manage tags. Without a command, list the tags.",
                       &schema->tag));
    TRY(argx_command_set_summary(schema->tag, "Manage tags."));
    TRY(argx_command_set_subcommand_optional(schema->tag, true));

    /* todo tag add <name> */
    TRY(add_subcommand(schema->tag, "add", "Add a tag.", &schema->tag_add));
    TRY(argx_command_add_positional(schema->tag_add, "name", argx_type_string(),
                                    ARGX_ARITY_REQUIRED, &schema->tag_add_name));
    TRY(argx_positional_set_description(schema->tag_add_name, "The name of the tag."));

    /* todo tag remove <name> */
    TRY(add_subcommand(schema->tag, "remove", "Remove a tag.", &schema->tag_remove));
    TRY(argx_command_add_positional(schema->tag_remove, "name", argx_type_string(),
                                    ARGX_ARITY_REQUIRED, &schema->tag_remove_name));
    TRY(argx_positional_set_description(schema->tag_remove_name, "The name of the tag."));

    return argx_command_validate(schema->root, NULL, NULL, NULL);
}

/* ライブラリはヘルプのテキストを分割してこの関数に渡す */
static bool write_to_stream(void *user_data, const char *text, size_t length)
{
    return fwrite(text, 1, length, (FILE *)user_data) == length;
}

/* 最後に選ばれたコマンドのヘルプを標準出力に書き込む */
static int print_help(const argx_result_t *result)
{
    if (argx_help_write(argx_result_command(result), NULL, write_to_stream, stdout) !=
        ARGX_ERROR_NONE)
    {
        return EXIT_FAILURE;
    }
    return EXIT_SUCCESS;
}

/* 解析エラーのメッセージと、エラーが見つかったコマンドの使い方の行を書き込む */
static void print_parse_error(const argx_result_t *result)
{
    fprintf(stderr, "todo: %s\n", argx_result_error_message(result));
    argx_help_write_usage(argx_result_error_command(result), NULL, write_to_stream, stderr);
    fprintf(stderr, "For more information, try '--help'.\n");
}

/* 最後に選ばれたコマンドで処理を分ける */
static int run(const todo_schema_t *schema, const argx_result_t *result)
{
    const argx_command_t *command = argx_result_command(result);
    const char *text = NULL;
    int64_t priority = 0;

    /* グローバルオプションは、どこに書かれても定義したルートのハンドルで読む */
    if (argx_result_flag(result, schema->quiet))
    {
        return EXIT_SUCCESS;
    }

    if (command == schema->add)
    {
        if (argx_result_positional_string(result, schema->text, 0, &text) &&
            argx_result_option_int(result, schema->priority, &priority))
        {
            printf("add \"%s\" (priority %" PRId64 ")\n", text, priority);
        }
    }
    else if (command == schema->list)
    {
        printf("list %s tasks\n", argx_result_flag(result, schema->all) ? "all" : "open");
    }
    else if (command == schema->tag)
    {
        /* サブコマンドを省略した "todo tag" */
        printf("list tags\n");
    }
    else if (command == schema->tag_add)
    {
        if (argx_result_positional_string(result, schema->tag_add_name, 0, &text))
        {
            printf("add tag \"%s\"\n", text);
        }
    }
    else if (command == schema->tag_remove)
    {
        if (argx_result_positional_string(result, schema->tag_remove_name, 0, &text))
        {
            printf("remove tag \"%s\"\n", text);
        }
    }
    return EXIT_SUCCESS;
}

int main(int argc, char **argv)
{
    todo_schema_t schema = { 0 };
    argx_result_t *result = NULL;
    argx_error_t error;
    int status = EXIT_FAILURE;

    error = define_schema(&schema);
    if (error != ARGX_ERROR_NONE)
    {
        fprintf(stderr, "todo: cannot define the command line: %s\n", argx_error_message(error));
        goto cleanup;
    }

    error = argx_parse(schema.root, argc, argv, &result);
    switch (error)
    {
    case ARGX_ERROR_NONE:
        /* --help で解析が終わったときは、値を読まずにヘルプを表示する */
        if (argx_result_flag(result, schema.help))
        {
            status = print_help(result);
        }
        else
        {
            status = run(&schema, result);
        }
        break;

    case ARGX_ERROR_INVALID_COMMAND_LINE:
        if (argx_result_error_kind(result) == ARGX_PARSE_ERROR_MISSING_SUBCOMMAND)
        {
            /* サブコマンドがないときは、そのコマンドのヘルプを表示して失敗で終わる */
            (void)print_help(result);
        }
        else
        {
            print_parse_error(result);
        }
        break;

    default:
        /* ARGX_ERROR_OUT_OF_MEMORY。結果が作られない唯一のエラーコード */
        fprintf(stderr, "todo: %s\n", argx_error_message(error));
        break;
    }

cleanup:
    /* 結果、スキーマの順に破棄する。サブコマンドはルートと一緒に破棄される */
    argx_result_destroy(result);
    argx_command_destroy(schema.root);

    return status;
}
```

スキーマの定義に失敗した場合も、途中まで作られたスキーマは`argx_command_destroy`で破棄できます。サブコマンドはルートと一緒に破棄されるため、個別に破棄する必要はありません。

## ビルドして実行する

`todo`ディレクトリで次のコマンドを実行し、ビルドします。

```sh
cmake -S . -B build
cmake --build build
```

### サブコマンドを実行する

```
$ ./build/todo add "Buy milk"
add "Buy milk" (priority 3)

$ ./build/todo add -p 1 "Write a blog post"
add "Write a blog post" (priority 1)

$ ./build/todo list --all
list all tasks

$ ./build/todo tag add work
add tag "work"

$ ./build/todo tag
list tags
```

`todo tag`は、サブコマンドを省略可能にしているため、エラーにならずにタグの一覧を表示する処理が実行されています。

### ヘルプを表示する

ルートのヘルプには、`Commands:`としてサブコマンドの一覧が表示されます。`tag`には、説明ではなく`argx_command_set_summary`で設定した要約が表示されています。

```
$ ./build/todo --help
Usage: todo [OPTIONS] <COMMAND>

Manage your tasks.

Commands:
  add          Add a task.
  list         List the tasks.
  tag          Manage tags.

Options:
  -h, --help   Print this help.
  -q, --quiet  Print nothing.
```

サブコマンドの`--help`では、そのサブコマンドのヘルプが表示されます。`add`は必須の`text`を省略していますが、`--help`が終端フラグなのでエラーになりません。

```
$ ./build/todo add --help
Usage: todo add [OPTIONS] <text>

Add a task.

Arguments:
  <text>                     What to do.

Options:
  -p, --priority <PRIORITY>  The priority of the task. [default: 3]

Global options:
  -h, --help                 Print this help.
  -q, --quiet                Print nothing.

$ ./build/todo tag --help
Usage: todo tag [OPTIONS] [COMMAND]

Manage tags. Without a command, list the tags.

Commands:
  add          Add a tag.
  remove       Remove a tag.

Global options:
  -h, --help   Print this help.
  -q, --quiet  Print nothing.
```

サブコマンドのヘルプでは、親のコマンドで定義したグローバルオプションが`Global options:`にまとめて表示されます。`todo tag --help`には、`tag`の説明の全文が表示されています。

### 誤ったコマンドライン

サブコマンドを指定せずに`todo`だけを実行すると、ルートのヘルプが表示され、終了コードは1になります。

```
$ ./build/todo
Usage: todo [OPTIONS] <COMMAND>

Manage your tasks.

Commands:
  add          Add a task.
  list         List the tasks.
  tag          Manage tags.

Options:
  -h, --help   Print this help.
  -q, --quiet  Print nothing.
```

そのほかの誤りでは、エラーメッセージと、エラーが見つかったコマンドの使い方の行が表示されます。

```
$ ./build/todo unknown
todo: unknown command 'unknown'
Usage: todo [OPTIONS] <COMMAND>
For more information, try '--help'.

$ ./build/todo tag add
todo: missing required argument 'name'
Usage: todo tag add [OPTIONS] <name>
For more information, try '--help'.

$ ./build/todo -p 1 add x
todo: unknown option '-p'
Usage: todo [OPTIONS] <COMMAND>
For more information, try '--help'.
```

## まとめ

ArgXでサブコマンドを持つCLIを作るときのポイントは次のとおりです。

- サブコマンドは`argx_command_add_subcommand`で追加し、ルートと同じようにオプションや位置引数を追加できます。サブコマンドの下にさらにサブコマンドを追加することもできます。
- オプションはサブコマンドに引き継がれないため、定義したコマンド名の後ろに書きます。`argx_option_set_global`でグローバルオプションにすると、その下のすべてのサブコマンドでも使えます。
- `-h`, `--help`は、ルートに1回だけ定義し、グローバルオプションかつ終端フラグ（`argx_option_set_terminal`）にします。必須の引数やサブコマンドがなくても、ヘルプを表示できます。
- 親のヘルプのサブコマンド一覧に表示する文は、`argx_command_set_summary`で説明とは別に設定できます。
- サブコマンドは既定で必須です。`argx_command_set_subcommand_optional`で、コマンドごとに省略可能にできます。
- 解析後は`argx_result_command`で最後に選ばれたコマンドを取得し、ハンドルと比較して処理を分けます。

より大きな例として、選択肢や独自の型、リストオプションも使ったサンプルがリポジトリの[examples/pack/pack.c](https://github.com/vabelorg/argx/blob/main/examples/pack/pack.c)にあります。サブコマンドに関するほかの使い方は、[How-to](https://github.com/vabelorg/argx/blob/main/docs/guides/how-to.md)と[FAQ](https://github.com/vabelorg/argx/blob/main/docs/guides/faq.md)を参照してください。
