---
title: Parse Command-Line Arguments in C with ArgX
date: 2026-11-15T00:00:00+09:00
draft: false
tags:
  - C
  - CMake
  - ArgX
params:
  toc: true
---

When you write a command-line tool in C, parsing `argv` takes more work than you might expect. Even with `getopt`, long options depend on the platform, and you still have to write the type conversions, the required-argument checks, and the help text that `--help` prints.

This article explains how to use [ArgX](https://github.com/vabelorg/argx), a command-line argument parser for C99, by building a small sample program.

## What is ArgX?

ArgX is a library that takes a command line defined once as a **schema**, and from that one definition parses `argv`, checks it, converts the values, and generates the help. Its main features are:

- Plain C99, with no dependencies beyond the C standard library.
- Builds on Linux (GCC, Clang), macOS (Clang) and Windows (MSVC), as a static or a shared library.
- Flags, counts (such as `-vv`), flags negatable with `--no-`, options with a value, positionals, and nested subcommands.
- Values converted to strings, integers, floating-point numbers, choices, or types you define.
- Help and usage text generated from the schema.
- The library prints nothing, never exits the process, and reads no environment variables. Errors come back as an error code and a one-line message.

The last point matters: your code decides where the help and the errors go and which exit status the program returns.

## Prerequisites

This article assumes the following:

- CMake 3.21 or later
- A C99 compiler (GCC, Clang, MSVC, etc.)
- Git (CMake uses it to fetch the ArgX sources)

The steps were tested on Ubuntu 24.04 with CMake 3.28 and GCC 13, using ArgX `v0.1.0`.

## Setting Up the Project

Create a project with this layout:

```
greet/
├── CMakeLists.txt
└── main.c
```

Write the following in `CMakeLists.txt`:

```cmake
cmake_minimum_required(VERSION 3.21)
project(greet LANGUAGES C)

include(FetchContent)
FetchContent_Declare(ArgX
    GIT_REPOSITORY https://github.com/vabelorg/argx.git
    GIT_TAG v0.1.0
)
FetchContent_MakeAvailable(ArgX)

add_executable(greet main.c)
target_link_libraries(greet PRIVATE ArgX::argx)
```

`FetchContent` downloads external sources while CMake configures the project and adds them to the build. `GIT_TAG` pins the version, and linking `ArgX::argx` with `target_link_libraries` also sets up the include path for the ArgX headers. Check the [releases](https://github.com/vabelorg/argx/releases) for the latest version to put in `GIT_TAG`.

Besides FetchContent, you can use `add_subdirectory`, `find_package` with an installed ArgX, or pkg-config. See [Installation](https://github.com/vabelorg/argx/blob/main/docs/getting-started/installation.md) in the official documentation for details.

## How a Program Uses ArgX

A program using ArgX goes through these steps:

1. **Define the schema**: create a command and add options and positionals to it.
2. **Validate the schema**: check the definitions for conflicts. Parsing and help generation only accept a validated schema.
3. **Parse `argv`**: this creates a result.
4. **Read the values**: take the converted values out of the result.
5. **Destroy**: destroy the result, then the schema.

In this article, we build `greet`, a program that takes a name and prints a greeting. It accepts this command line:

```
greet [-h] [-l] [-n COUNT] name
```

| Argument | Kind | Meaning |
| --- | --- | --- |
| `-h`, `--help` | Flag | Print the help |
| `-l`, `--loud` | Flag | Add `!` to the greeting |
| `-n`, `--count` | Option with a value (integer) | How many times to greet; 1 if omitted |
| `name` | Positional (required) | Whom to greet |

The following sections walk through `main.c` piece by piece. The whole file is in [The Complete Code](#the-complete-code).

## Defining the Schema

First, create the root command and add the options and the positional.

```c
TRY(argx_command_create("greet", &root));
TRY(argx_command_set_description(root, "Greet somebody."));
TRY(argx_command_add_flag(root, 'h', "help", &help));
TRY(argx_option_set_description(help, "Print this help."));
TRY(argx_command_add_flag(root, 'l', "loud", &loud));
TRY(argx_option_set_description(loud, "Add an exclamation mark."));
TRY(argx_command_add_value(root, 'n', "count", argx_type_int(), &count));
TRY(argx_option_set_description(count, "How often to greet."));
TRY(argx_option_set_value_name(count, "COUNT"));
TRY(argx_option_set_default(count, "1"));
TRY(argx_command_add_positional(root, "name", argx_type_string(), ARGX_ARITY_REQUIRED, &name));
TRY(argx_positional_set_description(name, "Whom to greet."));
```

Here is what each function does:

- `argx_command_create`: creates a command. The name appears in the help.
- `argx_command_add_flag`: adds a flag, which takes no value. You give a short name (`'h'`) and a long name (`"help"`), and the last argument receives a **handle** (`argx_option_t *`). You use the handle to set attributes and to read the value later.
- `argx_command_add_value`: adds an option that takes a value. Here the value type is `argx_type_int()`, an integer.
- `argx_option_set_value_name`: sets the name that stands for the value in the help (`<COUNT>`).
- `argx_option_set_default`: sets the value used when the option is omitted, as a string. Validation, described below, checks that the option's value type accepts it.
- `argx_command_add_positional`: adds a positional. `ARGX_ARITY_REQUIRED` means "exactly one". The other arities are `ARGX_ARITY_OPTIONAL` (zero or one), `ARGX_ARITY_ZERO_OR_MORE`, and `ARGX_ARITY_ONE_OR_MORE`.
- `*_set_description`: sets the description shown in the help.

ArgX gives `--help` no special treatment: you define it as an ordinary flag.

### The TRY Macro for Error Handling

Functions that can fail return an `argx_error_t`, which is `ARGX_ERROR_NONE` on success. Writing an `if` after every call gets long, so the sample uses the `TRY` macro below to jump to the `define_failed` label on a failure.

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

The idea behind error handling with `goto` is explained in "[Simplify Memory Management with goto Statements in C](/blog/c-goto-memory-free)".

## Validating the Schema

When the definitions are complete, validate the schema with `argx_command_validate`.

```c
TRY(argx_command_validate(root, NULL, NULL, NULL));
```

Validation checks for conflicts that span more than one definition, such as a default value that the value type does not accept, or a required positional after an optional one. Mistakes that a single definition shows, such as a duplicate name, are reported earlier, by the add function such as `argx_command_add_flag`. The last three arguments can receive the faulty command, option, and positional; we don't need them here, so we pass `NULL`.

## Parsing argv

Pass `argc` and `argv` to `argx_parse`. It returns one of three codes:

| Return value | Meaning | Result |
| --- | --- | --- |
| `ARGX_ERROR_NONE` | Parsing succeeded | Created |
| `ARGX_ERROR_INVALID_COMMAND_LINE` | The command line has an error | Created |
| `ARGX_ERROR_OUT_OF_MEMORY` | An allocation failed | Not created |

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
        /* Read the values and do the work (see below). */
    }
    break;

case ARGX_ERROR_INVALID_COMMAND_LINE:
    if (argx_result_flag(result, help))
    {
        status = print_help(root);
    }
    else
    {
        print_parse_error(result);
    }
    break;

default:
    fprintf(stderr, "greet: %s\n", argx_error_message(error));
    break;
}
```

Note that **`--help` is checked even after a parse error**. `greet --help` is a parse error, because the required positional `name` is missing, but the result holds everything read before the error. So if `--help` was given, the help can still be printed.

`argx_result_flag` returns, as a `bool`, whether a flag was given.

## Printing the Help and Errors

ArgX prints nothing by itself. Instead, it takes a function that writes text, and passes the help to it piece by piece. Here we provide a function that writes to a stream with `fwrite`.

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

The fourth argument of `argx_help_write` (`stdout`) is passed unchanged to the write function as `user_data`. The second argument takes help options such as the width; `NULL` uses the defaults.

On a parse error, write the error message and the usage line to the standard error stream.

```c
static void print_parse_error(const argx_result_t *result)
{
    fprintf(stderr, "greet: %s\n", argx_result_error_message(result));
    argx_help_write_usage(argx_result_error_command(result), NULL, write_to_stream, stderr);
    fprintf(stderr, "For more information, try '--help'.\n");
}
```

`argx_result_error_message` returns a one-line message such as `missing required argument 'name'`. `argx_help_write_usage` writes only the `Usage: greet [OPTIONS] <name>` line.

## Reading the Values

After a successful parse, read the values from the result with the handles.

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

- `argx_result_positional_string`: reads a positional's value as a string. The third argument is the index of the value, for positionals that take several values.
- `argx_result_option_int`: reads an option's value as an `int64_t`. If `-n` was omitted, it holds the default value, `1`.

Both return `true` when there is a value. The conversion to an integer already happened during parsing, so there is no need to call `strtol` or the like.

## Destroying

Finally, destroy the result, then the schema.

```c
cleanup:
    argx_result_destroy(result);
    argx_command_destroy(root);
```

Destroying `NULL` does nothing, so a single cleanup covers every path, including early failures. The options and positionals added to the schema are destroyed together with their command, so you never destroy a handle on its own.

## The Complete Code

Here is the whole `main.c`:

```c
#include <argx/argx.h>

#include <inttypes.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

/* Checks a call that can fail; on a failure, goes to the message. */
#define TRY(call)                     \
    do                                \
    {                                 \
        error = (call);               \
        if (error != ARGX_ERROR_NONE) \
        {                             \
            goto define_failed;       \
        }                             \
    } while (0)

/* The library passes the help text to this function, part by part. */
static bool write_to_stream(void *user_data, const char *text, size_t length)
{
    return fwrite(text, 1, length, (FILE *)user_data) == length;
}

/* Writes the help of command to the standard output. */
static int print_help(const argx_command_t *command)
{
    if (argx_help_write(command, NULL, write_to_stream, stdout) != ARGX_ERROR_NONE)
    {
        return EXIT_FAILURE;
    }
    return EXIT_SUCCESS;
}

/* Writes the message of a parse error and the usage line to the standard error stream. */
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

    /* The schema. The descriptions are for the help. */
    TRY(argx_command_create("greet", &root));
    TRY(argx_command_set_description(root, "Greet somebody."));
    TRY(argx_command_add_flag(root, 'h', "help", &help));
    TRY(argx_option_set_description(help, "Print this help."));
    TRY(argx_command_add_flag(root, 'l', "loud", &loud));
    TRY(argx_option_set_description(loud, "Add an exclamation mark."));
    TRY(argx_command_add_value(root, 'n', "count", argx_type_int(), &count));
    TRY(argx_option_set_description(count, "How often to greet."));
    TRY(argx_option_set_value_name(count, "COUNT"));
    TRY(argx_option_set_default(count, "1"));
    TRY(argx_command_add_positional(root, "name", argx_type_string(), ARGX_ARITY_REQUIRED, &name));
    TRY(argx_positional_set_description(name, "Whom to greet."));
    TRY(argx_command_validate(root, NULL, NULL, NULL));

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
        /* The result holds what was read before the error: "greet --help" works without a name. */
        if (argx_result_flag(result, help))
        {
            status = print_help(root);
        }
        else
        {
            print_parse_error(result);
        }
        break;

    default:
        /* ARGX_ERROR_OUT_OF_MEMORY, the only code that leaves no result. */
        fprintf(stderr, "greet: %s\n", argx_error_message(error));
        break;
    }

    goto cleanup;

define_failed:
    fprintf(stderr, "greet: cannot define the command line: %s\n", argx_error_message(error));

cleanup:
    /* The result first, then the schema. Destroying NULL does nothing. */
    argx_result_destroy(result);
    argx_command_destroy(root);

    return status;
}
```

## Building and Running

Run the following commands in the `greet` directory to build. On the first configure, CMake fetches the ArgX sources from GitHub.

```sh
cmake -S . -B build
cmake --build build
```

The build creates `build/greet`. With a multi-configuration generator such as MSVC, it goes into a directory named after the configuration, such as `build/Debug/greet.exe`.

### A Valid Command Line

```
$ ./build/greet --loud -n 2 world
hello, world!
hello, world!
greeted 2 time(s)
```

Short options can be combined, so `./build/greet -ln 2 world` gives the same output. You can also pass a value with `=`, as in `--count=2`.

### Printing the Help

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

The help is generated from the descriptions, the value name, and the default value set in the schema. It is printed even though no `name` was given.

### Invalid Command Lines

When the required positional is missing or a value cannot be converted to an integer, the program prints the error message and the usage line, and exits with status 1.

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

You get all of these checks without writing any validation or error messages yourself.

## Going Further

ArgX has more features than this article covers:

- **Subcommands**: `argx_command_add_subcommand` defines subcommands like `git commit`, which can have subcommands of their own.
- **Counts and negatable flags**: `argx_command_add_count` defines an option that counts how often it is given, like `-vvv`, and `argx_command_add_negatable` defines a pair such as `--color` and `--no-color`.
- **Choices and your own types**: `argx_type_create_choice` creates a value type with choices such as `tar` and `zip`, and `argx_type_create` creates a type with your own conversion.
- **Customizing the help**: fit the help to the terminal width, or get it as a string.
- **Wide characters on Windows**: `argx_parse_wide` parses the arguments of `wmain` directly.

[examples/pack/pack.c](https://github.com/vabelorg/argx/blob/main/examples/pack/pack.c) in the repository uses subcommands and user-defined types, and the [Tutorial](https://github.com/vabelorg/argx/blob/main/docs/getting-started/tutorial.md) walks through it step by step. For specific tasks, see the [How-to](https://github.com/vabelorg/argx/blob/main/docs/guides/how-to.md) and the [FAQ](https://github.com/vabelorg/argx/blob/main/docs/guides/faq.md).

## Conclusion

With ArgX, you define the command line once as a schema, and get parsing, type conversion, error messages, and help from it. Since the library prints nothing and never exits the process, you stay in control of where output goes and which exit status the program returns.

Next time you write a command-line tool in C, consider trying it instead of `getopt`.
