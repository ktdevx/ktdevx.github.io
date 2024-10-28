---
title: Basic Git Operations
date: 2024-09-29T23:00:26+09:00
draft: false
params:
  toc: true
---

Git allows you to manage the history of changes for programs and documents, enabling you to revert to previous states and collaborate efficiently with others.

This guide explains basic Git operations.

## Install Git

Detailed instructions for installing Git can be found in the following article. Refer to it to install Git in your environment.

[How to Install Git on Windows](/blog/install-git-on-windows)

## Initial Git Configuration

To use Git, you need to set your username and email address. Use the following commands for the initial configuration:

```
git config --global user.name <username>
git config --global user.email <email>
```

## Clone a Repository

Projects managed by Git are organized into units called repositories. To clone a remote repository, use the following command:

```
git clone <remote-repository>
```

This clones the remote repository.

## Create and Switching Branches

Git allows you to develop different features or fixes concurrently using multiple branches. Use the following commands to create and switch branches.

First, check out the branch you want to base the new branch on:

```
git checkout <base-branch>
```

Then create and switch to the new branch:

```
git branch <new-branch>
git checkout <new-branch>
```

This example creates a new branch called `feature` and switches to it.

To reflect the new branch in the remote repository, use the `git push` command:

```
git push -u origin <new-branch>
```

This pushes the branch to the remote repository.

## Add Files and Committing Changes

To add files to the repository and record changes, use the following commands:

```
echo "Hello, World!" > README.md
git add README.md
git commit -m "Initial commit"
```

In this example, the file `README.md` is added, and the changes are committed with the message "Initial commit." If you don’t use the `-m` option, a text editor will open for you to enter the commit message.

Note that changes are only reflected in the local repository at this point.

## Push Changes to the Remote Repository

To push changes to the remote repository, use the following command:

```
git push
```

This command reflects the committed changes in the remote repository.

## Merge Changes Between Branches

You can merge changes from multiple branches into a single branch. Use the following commands to merge branches:

```
git checkout <target-branch>
git merge <source-branch>
```

This merges the changes between branches. If you merged locally, don’t forget to push the changes.

## Pull Changes from the Remote Repository

To pull changes from the remote repository and update your local repository, use the following command:

```
git pull
```

This reflects the changes from the remote repository locally.

## External Links

* [Git](https://git-scm.com/)
