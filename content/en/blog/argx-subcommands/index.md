---
title: Build a CLI with Subcommands in C Using ArgX
date: 2026-11-15T00:00:00+09:00
draft: false
tags:
  - C
  - CMake
  - ArgX
params:
  toc: true
---

Many command-line tools, such as `git commit` or `docker run`, group their features under one command as "subcommands".

This article explains how to build a CLI with subcommands using [ArgX](https://github.com/vabelorg/argx), a command-line argument parser for C99. The basics of ArgX (defining, validating and parsing a schema, reading the values, and destroying everything) are covered in "[Parse Command-Line Arguments in C with ArgX](/blog/argx-usage)", so reading that article first will make this one easier to follow.

## Prerequisites

As in the previous article, this article assumes the following:

- CMake 3.21 or later
- A C99 compiler (GCC, Clang, MSVC, etc.)
- Git

The steps were tested on Ubuntu 24.04 with CMake 3.28 and GCC 13, using ArgX `v0.1.0`.

## Setting Up the Project

Create a project with this layout:

```
todo/
├── CMakeLists.txt
└── main.c
```

`CMakeLists.txt` is almost the same as in the previous article; only the name of the executable changes to `todo`.

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

## The Program We Build

In this article, we build `todo`, a made-up task manager. It stores nothing; it only prints what it received. It accepts these command lines:

```
todo [-h] [-q] <COMMAND>
todo add [-h] [-p PRIORITY] <text>
todo list [-h] [-a]
todo tag [-h] [COMMAND]
todo tag add [-h] <name>
todo tag remove [-h] <name>
```

| Command | What it does | Arguments |
| --- | --- | --- |
| `todo` | The root; a subcommand is required | `-q`, `--quiet`: print nothing |
| `todo add` | Adds a task | `-p`, `--priority`: the priority (integer, 3 if omitted)<br>`text`: what to do (required) |
| `todo list` | Lists the tasks | `-a`, `--all`: include finished tasks |
| `todo tag` | Manages tags; lists them when no subcommand is given | None |
| `todo tag add` | Adds a tag | `name`: the name of the tag (required) |
| `todo tag remove` | Removes a tag | `name`: the name of the tag (required) |

Every command has `-h`, `--help`. Note that `tag` has subcommands of its own, and that only `tag` can be used without a subcommand.

The following sections walk through `main.c` piece by piece. The whole file is in [The Complete Code](#the-complete-code).

## Defining Subcommands

A subcommand is added with `argx_command_add_subcommand`.

```c
argx_error_t argx_command_add_subcommand(argx_command_t *command, const char *name,
                                         argx_command_t **out);
```

Pass the parent command and the name of the subcommand, and the third argument receives the handle of the subcommand (`argx_command_t *`). **A subcommand is a command just like the root**, so you add options and positionals to it with the same functions, such as `argx_command_add_flag` and `argx_command_add_positional`.

One command cannot have both positionals and subcommands, though. Don't add positionals to a command that has subcommands, such as `todo` or `todo tag`.

### Adding -h, --help to Every Command

In ArgX, **an option is recognized only by the command that defines it, and subcommands do not inherit it**. If only the root has `--help`, `todo add --help` fails with an unknown option. So every command needs its own `-h`, `--help`.

The sample has a function that adds `-h`, `--help`, and a function that adds a subcommand together with its description and `-h`, `--help`.

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

The handle of `-h`, `--help` is used only inside `add_help`. To check later whether `--help` was given, the program looks the option up by name in each command (see below).

Unlike in the previous article, the definitions are split into functions here, so the `TRY` macro returns the error code with `return error;` instead of jumping with `goto`.

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

### Keeping the Handles in a Structure

More subcommands mean more handles, so keep them in a structure. It is also used after parsing, to tell which command was selected and to read the values.

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

### Defining the Root and the Subcommands

Here are the definitions of the root, `add`, and `list`:

```c
/* The root: todo [-h] [-q] <COMMAND> */
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

The only difference from the previous article is that options and positionals go to a subcommand (`schema->add`, `schema->list`) instead of the root (`schema->root`). The description set with `argx_command_set_description` also appears in the list of subcommands in the parent's help.

## Nested and Optional Subcommands

Next, add `add` and `remove` under `tag`. To add a subcommand to a subcommand, just pass `schema->tag` as the parent.

```c
/* todo tag [-h] [COMMAND]: without a subcommand, it lists the tags. */
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

The `add` of `tag add` has the same name as the root's `add`, which is fine because their parents differ.

### Making Subcommands Optional

In ArgX, **a command with subcommands requires one by default**. Running `todo` alone is a parse error of the kind `ARGX_PARSE_ERROR_MISSING_SUBCOMMAND`.

Sometimes, though, a command should do something of its own when no subcommand is given, the way `git remote` lists the remotes. For that, set `argx_command_set_subcommand_optional` to `true`. The setting belongs to each command: here only `tag` is optional, and the root `todo` still requires a subcommand.

Making the subcommands optional also changes the usage line:

```
Usage: todo [OPTIONS] <COMMAND>       ← required
Usage: todo tag [OPTIONS] [COMMAND]   ← optional
```

Setting `true` on a command without subcommands makes `argx_command_validate` fail.

## Where to Write Options

As mentioned above, an option is recognized only by the command that defines it. So **write an option after the name of the command that defines it, and before the name of that command's subcommand**.

The root's `-q` is recognized between `todo` and `add`:

```
$ ./build/todo -q add "Buy milk"
```

After `add`, it is an error, because `add` defines no `-q`:

```
$ ./build/todo add -q "Buy milk"
todo: unknown option '-q'
Usage: todo add [OPTIONS] <text>
For more information, try '--help'.
```

Likewise, the `-p` of `add` must come after `add`. A parent and a child may define options with the same name; they are separate options.

## Telling Which Command Was Selected

Parsing works as in the previous article, with `argx_parse`. After a successful parse, get **the last selected command** with `argx_result_command`, and compare it with the handles in the schema to choose what to do.

```c
static int run(const todo_schema_t *schema, const argx_result_t *result)
{
    const argx_command_t *command = argx_result_command(result);
    const char *text = NULL;
    int64_t priority = 0;

    /* An option of the root is read with the root's handle. */
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
        /* "todo tag" without a subcommand. */
        printf("list tags\n");
    }
    else if (command == schema->tag_add)
    {
        /* Reads tag_add_name and prints it (omitted). */
    }
    else if (command == schema->tag_remove)
    {
        /* Reads tag_remove_name and prints it (omitted). */
    }
    return EXIT_SUCCESS;
}
```

- `todo tag add work` gives `schema->tag_add`, and `todo tag` gives `schema->tag`. The root `todo` requires a subcommand, so a successful parse never ends in the root.
- An option of a parent command (here `-q`) is read from the same result with the parent's handle.
- Options and positionals of commands that were not selected read as not given.

For `todo -q tag add work`, three commands are selected: `todo`, `tag`, and `tag add`. `argx_result_command_count` and `argx_result_command_at` give them in order from the root, and `argx_result_command` returns the last one.

## Printing the Help and Errors

### Checking Whether --help Was Given

Each command defines its own `-h`, `--help`, so go through the selected commands and print the help if any of them got it.

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

`argx_command_find_long` looks up an option of a command by its long name; the third argument is the length of the name. This way, there is no need to keep every `-h`, `--help` handle in the structure.

### Printing the Help of the Selected Command

The help is printed for the last selected command. So `todo --help` prints the help of the root, and `todo tag add --help` the help of `tag add`.

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

On a parse error, `argx_result_error_command` gives the command in which the error was found, and the program prints that command's usage line. If the name is missing from `todo tag add`, the usage line includes the subcommands: `Usage: todo tag add [OPTIONS] <name>`.

```c
static void print_parse_error(const argx_result_t *result)
{
    fprintf(stderr, "todo: %s\n", argx_result_error_message(result));
    argx_help_write_usage(argx_result_error_command(result), NULL, write_to_stream, stderr);
    fprintf(stderr, "For more information, try '--help'.\n");
}
```

### Printing the Help When No Subcommand Is Given

Here is the part that branches on the return value of `argx_parse`:

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
        /* No subcommand: print the help of that command, and fail. */
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

As in the previous article, `--help` is checked even after a parse error. For example, `todo add --help` is a parse error because the required `text` is missing, but `--help` was read, so the help can still be printed.

This time, the program also checks the kind of the parse error with `argx_result_error_kind`. When the subcommand is missing (`ARGX_PARSE_ERROR_MISSING_SUBCOMMAND`), it prints the help of that command, as most CLIs do. Nothing was done, so the exit status stays a failure (`EXIT_FAILURE`, the initial value of `status`).

To print an error message instead, like for any other parse error, remove this `else if` branch. Running `todo` alone then prints `todo: missing required command`.

## The Complete Code

Here is the whole `main.c`:

```c
#include <argx/argx.h>

#include <inttypes.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

/* Checks a call that can fail; on a failure, returns its error code. */
#define TRY(call)                     \
    do                                \
    {                                 \
        error = (call);               \
        if (error != ARGX_ERROR_NONE) \
        {                             \
            return error;             \
        }                             \
    } while (0)

/* The handles of the schema. */
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

/* Adds -h, --help to command. Options are not inherited, so every command needs its own. */
static argx_error_t add_help(argx_command_t *command)
{
    argx_option_t *option = NULL;
    argx_error_t error;

    TRY(argx_command_add_flag(command, 'h', "help", &option));
    return argx_option_set_description(option, "Print this help.");
}

/* Adds a subcommand with its description and -h, --help. */
static argx_error_t add_subcommand(argx_command_t *parent, const char *name,
                                   const char *description, argx_command_t **out)
{
    argx_error_t error;

    TRY(argx_command_add_subcommand(parent, name, out));
    TRY(argx_command_set_description(*out, description));
    return add_help(*out);
}

/* Defines the schema. */
static argx_error_t define_schema(todo_schema_t *schema)
{
    argx_error_t error;

    /* The root: todo [-h] [-q] <COMMAND> */
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

    /* todo tag [-h] [COMMAND]: without a subcommand, it lists the tags. */
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

/* Tells whether -h or --help was given to one of the selected commands. */
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

/* The library passes the help text to this function, part by part. */
static bool write_to_stream(void *user_data, const char *text, size_t length)
{
    return fwrite(text, 1, length, (FILE *)user_data) == length;
}

/* Writes the help of the last selected command to the standard output. */
static int print_help(const argx_result_t *result)
{
    if (argx_help_write(argx_result_command(result), NULL, write_to_stream, stdout) !=
        ARGX_ERROR_NONE)
    {
        return EXIT_FAILURE;
    }
    return EXIT_SUCCESS;
}

/* Writes the message of a parse error and the usage line of the command it was found in. */
static void print_parse_error(const argx_result_t *result)
{
    fprintf(stderr, "todo: %s\n", argx_result_error_message(result));
    argx_help_write_usage(argx_result_error_command(result), NULL, write_to_stream, stderr);
    fprintf(stderr, "For more information, try '--help'.\n");
}

/* Branches on the last selected command. */
static int run(const todo_schema_t *schema, const argx_result_t *result)
{
    const argx_command_t *command = argx_result_command(result);
    const char *text = NULL;
    int64_t priority = 0;

    /* An option of the root is read with the root's handle. */
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
        /* "todo tag" without a subcommand. */
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
            /* No subcommand: print the help of that command, and fail. */
            (void)print_help(result);
        }
        else
        {
            print_parse_error(result);
        }
        break;

    default:
        /* ARGX_ERROR_OUT_OF_MEMORY, the only code that leaves no result. */
        fprintf(stderr, "todo: %s\n", argx_error_message(error));
        break;
    }

cleanup:
    /* The result first, then the schema. Subcommands go with the root. */
    argx_result_destroy(result);
    argx_command_destroy(schema.root);

    return status;
}
```

If defining the schema fails partway, the partly built schema can still be destroyed with `argx_command_destroy`. Subcommands are destroyed with the root, so you never destroy them on their own.

## Building and Running

Run the following commands in the `todo` directory to build:

```sh
cmake -S . -B build
cmake --build build
```

### Running Subcommands

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

`todo tag` is not an error, because its subcommands are optional; the code that lists the tags runs instead.

### Printing the Help

The root's help lists the subcommands under `Commands:`.

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

The `--help` of a subcommand prints the help of that subcommand.

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

### Invalid Command Lines

Running `todo` alone, without a subcommand, prints the root's help and exits with status 1.

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

Other mistakes print the error message and the usage line of the command in which the error was found.

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

## Conclusion

The key points for building a CLI with subcommands in ArgX are:

- Add a subcommand with `argx_command_add_subcommand`, then add options and positionals to it as you would to the root. Subcommands can have subcommands of their own.
- Subcommands do not inherit options, so define `-h`, `--help` on every command, and write each option after the name of the command that defines it.
- Subcommands are required by default; `argx_command_set_subcommand_optional` makes them optional, per command.
- After parsing, get the last selected command with `argx_result_command` and compare it with your handles to choose what to do.

For a larger example that also uses choices and user-defined types, see [examples/pack/pack.c](https://github.com/vabelorg/argx/blob/main/examples/pack/pack.c) in the repository. For more about subcommands, see the [How-to](https://github.com/vabelorg/argx/blob/main/docs/guides/how-to.md) and the [FAQ](https://github.com/vabelorg/argx/blob/main/docs/guides/faq.md).
