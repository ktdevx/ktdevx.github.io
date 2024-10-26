---
title: Install MinGW on Windows
date: 2024-09-28T16:25:47+09:00
draft: false
params:
  toc: true
---

MinGW is a free tool that can be used as a C/C++ development environment. While MinGW itself is no longer actively developed, its successor MinGW-w64 is under active development.

This guide explains the steps to install MinGW-w64 on Windows.

## Download MinGW

Go to the [official download page](https://www.mingw-w64.org/downloads/) and download MinGW.

Follow the link to MinGW-W64-builds, which will lead you to a GitHub page where the files are hosted.

The files are distributed in 7z format, so download the version you prefer. Here is a detailed explanation of the files.

### i686 / x86_64

These indicate the architecture. i686 is for 32-bit systems, and x86_64 is for 64-bit systems.

### posix / win32 / mcf

These indicate the threading model.

posix uses POSIX threads, but it tends to be slower compared to win32.

win32 uses the threading functionality provided by the Win32 API. However, it does not support C++11 threads.

mcf is a blend of both posix and win32, offering speed and compatibility with C++11 threads.

If you are building an existing project, follow the project’s specified settings.

### msvcrt / ucrt

These indicate the runtime library.

msvcrt is the runtime library from older versions of Microsoft Visual C++. It is compatible with Windows XP and earlier versions.

ucrt is the Universal C Runtime, which is standard for Windows 10 and later.

If you are starting a new project, it is recommended to use ucrt. If compatibility with older Windows systems is needed, choose msvcrt.

## Install MinGW

After downloading the compressed file, extract it to a location of your choice. It’s best to place it in a path that uses only ASCII characters and contains no spaces.

Inside the extracted mingw64/bin folder, you will find build tools like gcc and g++.

## Add bin Folder to PATH

At this point, the system doesn’t know the path to the gcc binary, so typing gcc in the Command Prompt will not work.

Therefore, add the path to the bin folder to the system's environment variable Path. This allows you to run gcc from the Command Prompt.

You could also create a script to automate adding the path.

## Compile a C Source Code File

To check if everything is working, create a simple C source code file named main.c.

In this example, we’ll create a program that prints "Hello, World!" when executed.

```c
#include <stdio.h>

int main(void)
{
    printf("Hello, World!\n");
    return 0;
}
```

In the Command Prompt, run `gcc main.c`, and an executable named a.exe will be generated.

Run it from the Command Prompt, and if "Hello, World!" is printed, then everything is working correctly.
