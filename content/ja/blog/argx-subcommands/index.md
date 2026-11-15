---
title: 【C言語】ArgXでサブコマンドを持つCLIを作る
date: 2026-11-16T08:00:00+09:00
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

記事の手順はUbuntu 24.04、CMake 3.28、GCC 13で動作を確認しています。ArgXのバージョンは`v0.1.0`です。

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
    GIT_TAG v0.1.0
)
FetchContent_MakeAvailable(ArgX)

add_executable(todo main.c)
target_link_libraries(todo PRIVATE ArgX::argx)
```

## 作るプログラム

この記事では、タスクを管理する架空のツール`todo`を作ります。実際にはデータを保存せず、受け取った内容を表示するだけのプログラムです。受け付けるコマンドラインは次のとおりです。

```
todo [-h] [-q] <COMMAND>
todo add [-h] [-p PRIORITY] <text>
todo list [-h] [-a]
todo tag [-h] [COMMAND]
todo tag add [-h] <name>
todo tag remove [-h] <name>
```

| コマンド | 動作 | 引数 |
| --- | --- | --- |
| `todo` | ルート。サブコマンドが必須 | `-q`, `--quiet`：何も表示しない |
| `todo add` | タスクを追加する | `-p`, `--priority`：優先度（整数、省略時は3）<br>`text`：タスクの内容（必須） |
| `todo list` | タスクを一覧表示する | `-a`, `--all`：完了したタスクも含める |
| `todo tag` | タグを管理する。サブコマンドを省略するとタグを一覧表示する | なし |
| `todo tag add` | タグを追加する | `name`：タグの名前（必須） |
| `todo tag remove` | タグを削除する | `name`：タグの名前（必須） |

すべてのコマンドに`-h`, `--help`があります。`tag`の下にさらにサブコマンドがあること、`tag`だけはサブコマンドを省略できることがポイントです。

以降では`main.c`の内容を順に説明します。コード全体は「[コード全体](#コード全体)」に掲載しています。

## サブコマンドを定義する

サブコマンドは`argx_command_add_subcommand`で追加します。

```c
argx_error_t argx_command_add_subcommand(argx_command_t *command, const char *name,
                                         argx_command_t **out);
```

第1引数に親のコマンド、第2引数にサブコマンドの名前を指定すると、第3引数にサブコマンドのハンドル（`argx_command_t *`）が書き込まれます。**サブコマンドもルートと同じコマンド**なので、`argx_command_add_flag`や`argx_command_add_positional`などで、オプションや位置引数を同じように追加できます。

ただし、1つのコマンドに位置引数とサブコマンドの両方を持たせることはできません。`todo`や`todo tag`のようにサブコマンドを持つコマンドには、位置引数を追加しないようにします。

### -h, --helpをすべてのコマンドに追加する

ArgXでは、**オプションはそれを定義したコマンドでしか認識されず、サブコマンドには引き継がれません**。ルートに`--help`を追加しただけでは、`todo add --help`は不明なオプションとしてエラーになります。そのため、`-h`, `--help`はコマンドごとに追加する必要があります。

サンプルでは、`-h`, `--help`を追加する関数と、サブコマンドを追加して説明と`-h`, `--help`をまとめて設定する関数を用意しています。

```c
static argx_error_t add_help(argx_command_t *command)
{
    argx_option_t *option = NULL;
    argx_error_t error;

    TRY(argx_command_add_flag(command, 'h', "help", &option));
    return argx_option_set_description(option, "Print this help.");
}

static argx_error_t add_subcommand(argx_command_t *parent, const char *name,
                                   const char *description, argx_command_t **out)
{
    argx_error_t error;

    TRY(argx_command_add_subcommand(parent, name, out));
    TRY(argx_command_set_description(*out, description));
    return add_help(*out);
}
```

`-h`, `--help`のハンドルは`add_help`の中でしか使いません。後で`--help`が指定されたかを調べるときは、コマンドから名前で検索します（後述）。

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
TRY(add_help(schema->root));
TRY(argx_command_add_flag(schema->root, 'q', "quiet", &schema->quiet));
TRY(argx_option_set_description(schema->quiet, "Print nothing."));

/* todo add [-h] [-p PRIORITY] <text> */
TRY(add_subcommand(schema->root, "add", "Add a task.", &schema->add));
TRY(argx_command_add_value(schema->add, 'p', "priority", argx_type_int(), &schema->priority));
TRY(argx_option_set_description(schema->priority, "The priority of the task."));
TRY(argx_option_set_value_name(schema->priority, "PRIORITY"));
TRY(argx_option_set_default(schema->priority, "3"));
TRY(argx_command_add_positional(schema->add, "text", argx_type_string(), ARGX_ARITY_REQUIRED,
                                &schema->text));
TRY(argx_positional_set_description(schema->text, "What to do."));

/* todo list [-h] [-a] */
TRY(add_subcommand(schema->root, "list", "List the tasks.", &schema->list));
TRY(argx_command_add_flag(schema->list, 'a', "all", &schema->all));
TRY(argx_option_set_description(schema->all, "Include finished tasks."));
```

オプションや位置引数を追加する先が、ルート（`schema->root`）ではなくサブコマンド（`schema->add`、`schema->list`）になっている点以外は、前回の記事と同じです。`argx_command_set_description`で設定した説明は、親コマンドのヘルプのサブコマンド一覧にも表示されます。

## ネストしたサブコマンドと省略可能なサブコマンド

`tag`の下に`add`と`remove`を追加します。サブコマンドの下にサブコマンドを追加するときも、親に`schema->tag`を指定するだけです。

```c
/* todo tag [-h] [COMMAND]: サブコマンドを省略すると、タグの一覧を表示する */
TRY(add_subcommand(schema->root, "tag", "Manage tags; lists them without a command.",
                   &schema->tag));
TRY(argx_command_set_subcommand_optional(schema->tag, true));

/* todo tag add [-h] <name> */
TRY(add_subcommand(schema->tag, "add", "Add a tag.", &schema->tag_add));
TRY(argx_command_add_positional(schema->tag_add, "name", argx_type_string(),
                                ARGX_ARITY_REQUIRED, &schema->tag_add_name));
TRY(argx_positional_set_description(schema->tag_add_name, "The name of the tag."));

/* todo tag remove [-h] <name> */
TRY(add_subcommand(schema->tag, "remove", "Remove a tag.", &schema->tag_remove));
TRY(argx_command_add_positional(schema->tag_remove, "name", argx_type_string(),
                                ARGX_ARITY_REQUIRED, &schema->tag_remove_name));
TRY(argx_positional_set_description(schema->tag_remove_name, "The name of the tag."));

return argx_command_validate(schema->root, NULL, NULL, NULL);
```

`tag add`の`add`と、ルートの`add`は同じ名前ですが、親が異なるため問題ありません。

### サブコマンドを省略可能にする

ArgXでは、**サブコマンドを持つコマンドは、既定でサブコマンドが必須**です。`todo`だけで実行すると、`ARGX_PARSE_ERROR_MISSING_SUBCOMMAND`という種類の解析エラーになります。

一方、`git remote`がサブコマンドなしでリモートの一覧を表示するように、サブコマンドを省略したときに独自の動作をさせたいこともあります。その場合は`argx_command_set_subcommand_optional`で`true`を設定します。この設定はコマンドごとで、ここでは`tag`だけを省略可能にし、ルートの`todo`はサブコマンドが必須のままにしています。

省略可能にすると、使い方の行の表記も変わります。

```
Usage: todo [OPTIONS] <COMMAND>       ← 必須
Usage: todo tag [OPTIONS] [COMMAND]   ← 省略可能
```

なお、サブコマンドを持たないコマンドに`true`を設定すると、`argx_command_validate`での検証がエラーになります。

## オプションを書く位置

前述のとおり、オプションは定義したコマンドでしか認識されません。そのため、**オプションは、それを定義したコマンド名の後ろ、かつ次のサブコマンド名の前**に書きます。

ルートの`-q`は`todo`と`add`の間に書くと認識されます。

```
$ ./build/todo -q add "Buy milk"
```

`add`の後ろに書くと、`add`には`-q`が定義されていないため、エラーになります。

```
$ ./build/todo add -q "Buy milk"
todo: unknown option '-q'
Usage: todo add [OPTIONS] <text>
For more information, try '--help'.
```

逆に、`add`の`-p`は`add`の後ろに書く必要があります。親と子で同じ名前のオプションを定義することもでき、その場合は別々のオプションとして扱われます。

## 解析結果からコマンドを判定する

解析は前回と同じく`argx_parse`で行います。解析に成功したら、`argx_result_command`で**最後に選ばれたコマンド**を取得し、スキーマのハンドルと比較して処理を分けます。

```c
static int run(const todo_schema_t *schema, const argx_result_t *result)
{
    const argx_command_t *command = argx_result_command(result);
    const char *text = NULL;
    int64_t priority = 0;

    /* ルートのオプションは、ルートのハンドルで読む */
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
- 親のコマンドのオプション（ここでは`-q`）も、同じ解析結果から親のハンドルを使って読み取れます。
- 選ばれなかったコマンドのオプションや位置引数は、「指定されなかった」ものとして読み取られます。

`todo -q tag add work`の場合、選ばれたコマンドは`todo`、`tag`、`tag add`の3つです。選ばれたコマンドはルートから順に`argx_result_command_count`と`argx_result_command_at`で取得でき、`argx_result_command`は最後の1つを返します。

## ヘルプとエラーを出力する

### --helpが指定されたかを調べる

`-h`, `--help`はコマンドごとに定義しているため、選ばれたコマンドを順に調べ、どれかで指定されていればヘルプを表示します。

```c
static bool help_was_given(const argx_result_t *result)
{
    size_t i;

    for (i = 0; i < argx_result_command_count(result); ++i)
    {
        const argx_command_t *command = argx_result_command_at(result, i);
        const argx_option_t *help = argx_command_find_long(command, "help", 4, NULL);

        if ((help != NULL) && argx_result_flag(result, help))
        {
            return true;
        }
    }
    return false;
}
```

`argx_command_find_long`は、長い名前でコマンドのオプションを検索します。第3引数は名前の長さです。この方法なら、`-h`, `--help`のハンドルをすべて構造体に保存しておく必要はありません。

### 選ばれたコマンドのヘルプを表示する

ヘルプは、最後に選ばれたコマンドについて表示します。これで、`todo --help`ではルートのヘルプが、`todo tag add --help`では`tag add`のヘルプが表示されます。

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
    if (help_was_given(result))
    {
        status = print_help(result);
    }
    else
    {
        status = run(&schema, result);
    }
    break;

case ARGX_ERROR_INVALID_COMMAND_LINE:
    if (help_was_given(result))
    {
        status = print_help(result);
    }
    else if (argx_result_error_kind(result) == ARGX_PARSE_ERROR_MISSING_SUBCOMMAND)
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

前回の記事と同じく、解析エラーのときにも`--help`を確認しています。たとえば`todo add --help`は必須の`text`がないため解析エラーになりますが、`--help`は読み取られているため、ヘルプを表示できます。

今回はそれに加えて、`argx_result_error_kind`で解析エラーの種類を調べています。サブコマンドがない（`ARGX_PARSE_ERROR_MISSING_SUBCOMMAND`）ときは、多くのCLIと同じように、そのコマンドのヘルプを表示します。何も処理していないため、終了コードは失敗（`status`の初期値の`EXIT_FAILURE`）のままにしています。

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

/* -h, --help を command に追加する。オプションは引き継がれないため、コマンドごとに追加する */
static argx_error_t add_help(argx_command_t *command)
{
    argx_option_t *option = NULL;
    argx_error_t error;

    TRY(argx_command_add_flag(command, 'h', "help", &option));
    return argx_option_set_description(option, "Print this help.");
}

/* サブコマンドを追加し、説明と -h, --help を設定する */
static argx_error_t add_subcommand(argx_command_t *parent, const char *name,
                                   const char *description, argx_command_t **out)
{
    argx_error_t error;

    TRY(argx_command_add_subcommand(parent, name, out));
    TRY(argx_command_set_description(*out, description));
    return add_help(*out);
}

/* スキーマを定義する */
static argx_error_t define_schema(todo_schema_t *schema)
{
    argx_error_t error;

    /* ルート: todo [-h] [-q] <COMMAND> */
    TRY(argx_command_create("todo", &schema->root));
    TRY(argx_command_set_description(schema->root, "Manage your tasks."));
    TRY(add_help(schema->root));
    TRY(argx_command_add_flag(schema->root, 'q', "quiet", &schema->quiet));
    TRY(argx_option_set_description(schema->quiet, "Print nothing."));

    /* todo add [-h] [-p PRIORITY] <text> */
    TRY(add_subcommand(schema->root, "add", "Add a task.", &schema->add));
    TRY(argx_command_add_value(schema->add, 'p', "priority", argx_type_int(), &schema->priority));
    TRY(argx_option_set_description(schema->priority, "The priority of the task."));
    TRY(argx_option_set_value_name(schema->priority, "PRIORITY"));
    TRY(argx_option_set_default(schema->priority, "3"));
    TRY(argx_command_add_positional(schema->add, "text", argx_type_string(), ARGX_ARITY_REQUIRED,
                                    &schema->text));
    TRY(argx_positional_set_description(schema->text, "What to do."));

    /* todo list [-h] [-a] */
    TRY(add_subcommand(schema->root, "list", "List the tasks.", &schema->list));
    TRY(argx_command_add_flag(schema->list, 'a', "all", &schema->all));
    TRY(argx_option_set_description(schema->all, "Include finished tasks."));

    /* todo tag [-h] [COMMAND]: サブコマンドを省略すると、タグの一覧を表示する */
    TRY(add_subcommand(schema->root, "tag", "Manage tags; lists them without a command.",
                       &schema->tag));
    TRY(argx_command_set_subcommand_optional(schema->tag, true));

    /* todo tag add [-h] <name> */
    TRY(add_subcommand(schema->tag, "add", "Add a tag.", &schema->tag_add));
    TRY(argx_command_add_positional(schema->tag_add, "name", argx_type_string(),
                                    ARGX_ARITY_REQUIRED, &schema->tag_add_name));
    TRY(argx_positional_set_description(schema->tag_add_name, "The name of the tag."));

    /* todo tag remove [-h] <name> */
    TRY(add_subcommand(schema->tag, "remove", "Remove a tag.", &schema->tag_remove));
    TRY(argx_command_add_positional(schema->tag_remove, "name", argx_type_string(),
                                    ARGX_ARITY_REQUIRED, &schema->tag_remove_name));
    TRY(argx_positional_set_description(schema->tag_remove_name, "The name of the tag."));

    return argx_command_validate(schema->root, NULL, NULL, NULL);
}

/* 選ばれたコマンドのどれかに -h, --help が指定されたかを返す */
static bool help_was_given(const argx_result_t *result)
{
    size_t i;

    for (i = 0; i < argx_result_command_count(result); ++i)
    {
        const argx_command_t *command = argx_result_command_at(result, i);
        const argx_option_t *help = argx_command_find_long(command, "help", 4, NULL);

        if ((help != NULL) && argx_result_flag(result, help))
        {
            return true;
        }
    }
    return false;
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

    /* ルートのオプションは、ルートのハンドルで読む */
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
        if (help_was_given(result))
        {
            status = print_help(result);
        }
        else
        {
            status = run(&schema, result);
        }
        break;

    case ARGX_ERROR_INVALID_COMMAND_LINE:
        if (help_was_given(result))
        {
            status = print_help(result);
        }
        else if (argx_result_error_kind(result) == ARGX_PARSE_ERROR_MISSING_SUBCOMMAND)
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

ルートのヘルプには、`Commands:`としてサブコマンドの一覧が表示されます。

```
$ ./build/todo --help
Usage: todo [OPTIONS] <COMMAND>

Manage your tasks.

Commands:
  add          Add a task.
  list         List the tasks.
  tag          Manage tags; lists them without a command.

Options:
  -h, --help   Print this help.
  -q, --quiet  Print nothing.
```

サブコマンドの`--help`では、そのサブコマンドのヘルプが表示されます。

```
$ ./build/todo add --help
Usage: todo add [OPTIONS] <text>

Add a task.

Arguments:
  <text>                     What to do.

Options:
  -h, --help                 Print this help.
  -p, --priority <PRIORITY>  The priority of the task. [default: 3]

$ ./build/todo tag --help
Usage: todo tag [OPTIONS] [COMMAND]

Manage tags; lists them without a command.

Commands:
  add         Add a tag.
  remove      Remove a tag.

Options:
  -h, --help  Print this help.
```

### 誤ったコマンドライン

サブコマンドを指定せずに`todo`だけを実行すると、ルートのヘルプが表示され、終了コードは1になります。

```
$ ./build/todo
Usage: todo [OPTIONS] <COMMAND>

Manage your tasks.

Commands:
  add          Add a task.
  list         List the tasks.
  tag          Manage tags; lists them without a command.

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

$ ./build/todo add -q x
todo: unknown option '-q'
Usage: todo add [OPTIONS] <text>
For more information, try '--help'.
```

## まとめ

ArgXでサブコマンドを持つCLIを作るときのポイントは次のとおりです。

- サブコマンドは`argx_command_add_subcommand`で追加し、ルートと同じようにオプションや位置引数を追加できます。サブコマンドの下にさらにサブコマンドを追加することもできます。
- オプションはサブコマンドに引き継がれないため、`-h`, `--help`はコマンドごとに定義します。オプションは、定義したコマンド名の後ろに書きます。
- サブコマンドは既定で必須です。`argx_command_set_subcommand_optional`で、コマンドごとに省略可能にできます。
- 解析後は`argx_result_command`で最後に選ばれたコマンドを取得し、ハンドルと比較して処理を分けます。

より大きな例として、選択肢や独自の型も使ったサンプルがリポジトリの[examples/pack/pack.c](https://github.com/vabelorg/argx/blob/main/examples/pack/pack.c)にあります。サブコマンドに関するほかの使い方は、[How-to](https://github.com/vabelorg/argx/blob/main/docs/guides/how-to.md)と[FAQ](https://github.com/vabelorg/argx/blob/main/docs/guides/faq.md)を参照してください。
