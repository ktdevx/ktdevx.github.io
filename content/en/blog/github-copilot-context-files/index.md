---
title: How to Configure GitHub Copilot Context Files
date: 2026-09-02T00:00:00+09:00
draft: false
tags:
  - GitHub
  - GitHub Copilot
  - VS Code
params:
  toc: true
---

GitHub Copilot can use more than the file you have open or the code you are typing. It can also use instructions stored in your project when generating answers and changes. Keeping project rules in context files reduces the need to repeat the same explanation in every request.

This article explains the main types of context files available in Visual Studio Code (VS Code) and how to configure them in a repository. The supported files and labels can vary by Copilot version and agent. Check the latest official documentation when you use these features.

## Prerequisites

Prepare the following:

- VS Code
- A GitHub account with access to GitHub Copilot
- A project managed with Git

This article uses `PROJECT_ROOT` to represent the root directory of the project. If you already opened the project in VS Code, replace `PROJECT_ROOT` with its actual location.

## Types of context files

Use the following files for different types of shared project instructions in VS Code.

| File | Main purpose |
| --- | --- |
| `.github/copilot-instructions.md` | Instructions for the entire repository |
| `.github/instructions/NAME.instructions.md` | Instructions for specific files or directories |
| `AGENTS.md` | Instructions for an agent, applied to work under its directory |

Use `copilot-instructions.md` for the project purpose and common development rules. Changing its file name or location can prevent it from being discovered automatically.

Path-specific instruction files use `applyTo` in front matter to define their targets. For example, the following applies to all TypeScript files:

```markdown
---
applyTo: "**/*.ts,**/*.tsx"
---
```

`AGENTS.md` is useful when different directories in a monorepo need different rules. Support can vary by agent and execution environment, so check the documentation for the agent you use.

## Add repository-wide instructions

Start by writing the rules that should be shared across all work in `.github/copilot-instructions.md`.

### Create the file

Create the following directory and file at the project root:

```text
PROJECT_ROOT/
└── .github/
    └── copilot-instructions.md
```

Keep the instructions short and specific. For example:

```markdown
# Project instructions

- This project is a multilingual website built with Hugo Extended.
- Content is managed separately in content/ja/ and content/en/.
- When changing a blog post, check both the Japanese and English versions.
- Run hugo --minify after changes to verify the build.
- Do not edit generated public/ or resources/_gen/ files directly.
```

Include the project purpose, the role of important directories, required commands, and rules to follow when making changes. Focus on information that is needed repeatedly instead of copying a long document into the file.

## Add path-specific instructions

When rules differ by language or directory, create instruction files in `.github/instructions/`.

For example, save Markdown rules in the following location:

```text
PROJECT_ROOT/
└── .github/
    └── instructions/
        └── markdown.instructions.md
```

```markdown
---
applyTo: "**/*.md"
---

- Use short headings that describe the content.
- Put commands in code blocks.
- Include a way to verify each procedure after it runs.
```

To target only one directory, use a glob such as `content/en/**/*.md`. Separate multiple file extensions with commas in the `applyTo` value.

When a repository-wide instruction and a path-specific instruction both match a request, both may be used. Conflicting instructions can reduce the quality of answers and changes, so keep common rules and local rules clearly separated.

## Use AGENTS.md

Use `AGENTS.md` for rules specific to an agent's work. Put it at the repository root to provide instructions for agent work across the project.

```text
PROJECT_ROOT/
└── AGENTS.md
```

In a monorepo, place additional files closer to the subproject when its rules differ:

```text
PROJECT_ROOT/
├── AGENTS.md
└── packages/
    └── web/
        └── AGENTS.md
```

For work in a subdirectory, the nearest `AGENTS.md` takes precedence. Keep the root rules and subproject rules consistent where they overlap.

`AGENTS.md` is not necessarily applied in the same way to every Copilot feature. Code completion, Chat, Agent, GitHub.com Cloud Agent, and Code Review can support different customization types.

## Write useful instructions

Include information that helps Copilot make verifiable decisions:

- The project purpose and main technologies
- The role of directories and files
- Coding conventions and naming rules
- Test, build, and static analysis commands
- Files that must not be changed and compatibility requirements
- Checks to perform after making changes

For example, instead of writing “make the code clean,” write “do not rename the public API and run the existing tests.” Split instructions into small bullet points and state important conditions and exceptions.

## Check whether instructions are applied

After saving the file, open Copilot Chat in VS Code and check whether the instructions are being used.

1. Open the project root in VS Code.
2. Save an instruction file such as `.github/copilot-instructions.md`.
3. Ask Chat about the project structure or the checks required after a change.
4. Check whether the answer reflects the content of the instruction file.
5. If you ask an Agent to work, review the changed files and commands it ran.

To check path-specific instructions, ask about a file that matches `applyTo`. For example, if instructions target Markdown files, ask about headings or links in a Markdown article.

Seeing an instruction file in the context does not guarantee that the answer is correct. Check the response references or Agent debug logs, and compare the result with a request that states the relevant requirement explicitly.

## Troubleshoot missing instructions

If a context file does not appear to be used, check the following:

1. Confirm that the file name is `copilot-instructions.md` or follows the `NAME.instructions.md` pattern.
2. Confirm that `copilot-instructions.md` is inside the repository's `.github` directory.
3. Confirm that path-specific files are inside `.github/instructions`.
4. Confirm that the `applyTo` glob matches the target file path.
5. Confirm that the repository root is open in VS Code.
6. Update VS Code and GitHub Copilot when possible.
7. If you use an Agent, inspect the Agent debug logs for loaded files.

When you open only a subdirectory of a monorepo, a setting for discovering customizations in parent repositories may affect the result. The setting name and default value can change with VS Code versions, so check the official documentation.

## Things to keep in mind

### Keep instructions short and specific

Too many instructions can hide important conditions or create conflicts. Separate repository-wide rules from rules for a particular type of file.

### Verify generated results

A context file does not guarantee correct code. Review the diff, types, exception handling, boundary cases, and security concerns, then run tests and static analysis.

### Do not include sensitive information

Do not put API keys, passwords, personal information, customer information, or confidential company information in context files. When a repository is shared, other people or services may be able to access the content.

### Check feature support

The Copilot features that use a context file depend on its type. VS Code, GitHub.com, Cloud Agent, and Code Review may not behave the same way. Check the official documentation for the environment you use.

## Summary

GitHub Copilot context files can reduce the need to repeat a project's purpose, development rules, and verification steps.

- Put shared rules in `.github/copilot-instructions.md`.
- Put file- or directory-specific rules in `.github/instructions/*.instructions.md`.
- Put agent-specific rules in `AGENTS.md`.
- Keep instructions short and specific, and always verify generated results.

For details, see [Repository custom instructions for GitHub Copilot (GitHub Docs)](https://docs.github.com/en/copilot/customizing-copilot/adding-repository-custom-instructions-for-github-copilot) and [Copilot customization in VS Code](https://code.visualstudio.com/docs/copilot/copilot-customization).
