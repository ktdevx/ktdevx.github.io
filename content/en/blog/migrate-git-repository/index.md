---
title: Migrate a Git Repository to Another Server
date: 2024-09-29T22:57:58+09:00
draft: false
params:
  toc: true
---

This guide explains how to migrate a Git repository to another server.

## Create an Empty Bare Repository on the Destination Server

First, create an empty bare repository on the destination server. Run the following command on the destination server:

```
git init --bare
```

The goal of this guide is to migrate the Git repository to this newly created bare repository.

## Clone the Bare Repository from the Source Repository

Run the following command on your PC to clone a bare repository from the source repository:

```
git clone --bare <path-to-source-repository>
```

By adding the `--bare` option to the `clone` command, you can clone it as a bare repository.

## Push the Bare Repository to the Destination Repository

Run the following commands on your PC to push the previously cloned bare repository to the destination repository:

```
cd <path-to-cloned-bare-repository>
git push --mirror <path-to-destination-repository>
```

The `--mirror` option in the `push` command syncs all branches, tags, and references in the specified repository.

## Delete the Cloned Bare Repository

Run the following commands on your PC to delete the bare repository that is no longer needed:

```
cd ..
rm -rf <cloned-bare-repository>
```

Don't forget to delete the source repository as well. This completes the Git repository migration process.
