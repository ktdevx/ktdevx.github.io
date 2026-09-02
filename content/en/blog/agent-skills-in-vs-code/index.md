---
title: How to Create and Use Agent Skills in VS Code
date: 2026-09-02T00:00:00+09:00
draft: false
tags:
  - GitHub
  - GitHub Copilot
  - VS Code
params:
  toc: true
---

Agent Skills let AI agents such as GitHub Copilot use additional procedures and decision criteria for specialized tasks. They make a repeatable workflow available for tasks such as investigation, editing, and testing.

This article explains how to create a project Agent Skill in VS Code and use it in chat. The hands-on example creates a `release-notes` skill that drafts release notes from a repository's changes.

## Prerequisites

Prepare the following:

- VS Code with access to GitHub Copilot Chat and Agent features
- A GitHub account that can use GitHub Copilot
- A Git repository where you can add a skill

Menu names and available models may vary by version and subscription.

## What are Agent Skills?

Agent Skills are an open standard that can be used by multiple AI agents. An Agent Skill is a specialized workflow that an AI agent loads when it is relevant. This article uses the skill through the GitHub Copilot extension for VS Code. For a project skill, a common location is:

```text
.github/skills/<skill-name>/SKILL.md
```

The YAML front matter in `SKILL.md` must contain at least these fields:

- `name`: The identifier of the skill. Use lowercase letters, numbers, and hyphens only, and make it match the parent directory name.
- `description`: A description of what the skill does and when to use it.

The body describes the procedure, constraints, and verification steps. You can also add scripts, examples, and reference files in the same directory.

Custom instructions and Agent Skills serve different purposes. Custom instructions are useful for continuously applying project conventions. Agent Skills are useful for loading task-specific procedures, such as testing, debugging, or deployment, when they are needed.

## Prepare the hands-on exercise

Open a practice Git repository in VS Code. If you use an existing repository, commit its current state first so that generated changes are easy to review.

Create the following directory from the project root:

```text
.github/
└── skills/
    └── release-notes/
        └── SKILL.md
```

You can create it in the Explorer or run these commands in PowerShell:

```powershell
New-Item -ItemType Directory -Force .github\skills\release-notes
New-Item -ItemType File -Force .github\skills\release-notes\SKILL.md
```

## Write the skill

Open `SKILL.md` and paste the following content:

```markdown
---
name: release-notes
description: Create a release notes draft from the changes in the current Git repository. Use when preparing a release summary, changelog entry, or pull request release notes.
---

# Release notes

Create a concise release notes draft from the current repository changes.

## Procedure

1. Inspect the current branch and the changes compared with the default branch.
2. Read relevant commit messages and changed files. Do not include secrets or full sensitive values in the draft.
3. Group changes into Added, Changed, Fixed, and Removed. Omit empty groups.
4. Write each item for a user who needs to understand the effect of the change.
5. Ask a clarifying question when the comparison branch or release scope is unclear.
6. Do not edit project files unless the user explicitly asks for a file change.

## Output format

Return the following sections:

- A one-sentence summary
- A Markdown release notes draft
- A short list of files or commits inspected
- Open questions and verification items

Keep the draft factual. Do not invent issue numbers, performance results, compatibility claims, or breaking changes.
```

Make the `description` specific about both the capability and the requests that should activate it. An unclear description makes automatic selection less reliable. Use the body to define the order of work and output format.

It is also useful to describe what the agent must not do. This example prevents file edits unless the user explicitly asks for them. For skills that run commands or edit files, document the scope, verification steps, and treatment of secrets.

## Check that VS Code recognizes the skill

Save `SKILL.md` and open the Chat view. Type `/` in the input field. `release-notes` should appear in the list of available skills.

If it does not appear, check the following:

1. Confirm that VS Code opened the repository root folder.
2. Confirm that the file is named exactly `SKILL.md`.
3. Confirm that `name: release-notes` matches the `release-notes` directory.
4. Make sure `name` does not contain uppercase letters, slashes, colons, or dots.
5. Confirm that the front matter starts and ends with `---`.
6. Close and reopen the Chat view to refresh the skill list.

Agent Skills can be loaded automatically when they are relevant to a request. To guarantee that this skill is used, select it explicitly with `/release-notes`.

## Run the skill

In a repository with changes, enter this prompt in Chat:

```text
/release-notes Create a draft for the next release from the changes on the current branch.
```

Review the result carefully:

- Is every described feature present in the actual diff?
- Are changes grouped correctly as Added, Changed, Fixed, or Removed?
- Are breaking-change or compatibility claims supported by evidence?
- Does the output contain any secrets or personal information?
- Are remaining verification items clearly identified?

You can also test automatic selection without using `/release-notes`:

```text
Summarize the changes for the next release as user-facing release notes.
```

If the skill is not selected automatically, make its `description` more specific or invoke it with the slash command. After changing the skill body, start a new chat before testing again.

## Use additional files

For a longer workflow, split supporting material into files in the skill directory instead of putting everything in `SKILL.md`.

```text
.github/skills/release-notes/
├── SKILL.md
├── examples/
│   └── release-notes.md
└── templates/
    └── changelog.md
```

Reference additional files with relative links from `SKILL.md`:

```markdown
Use the [changelog example](./templates/changelog.md) as the template.
```

Referencing a file tells the agent where to find the material when it needs it. If you include a script, review its input validation, network access, and file deletion behavior before using it.

## Agent Skill design guidelines

### Keep one purpose

A skill that combines testing, deployment, and release-note writing will have vague activation conditions and procedures. Split different goals into separate skills so only the relevant workflows are combined.

### Define the procedure and completion criteria

Phrases such as “check appropriately” are difficult to follow. Specify commands, files to inspect, output format, and what to do when a step fails.

### Limit permissions

Agent Skills describe procedures, but the agent may run commands or modify files while following them. For deletion, external communication, or deployment, document the scope and checkpoints, and review commands and diffs before execution.

### Keep secrets out

Do not put API keys, passwords, access tokens, or customer information in `SKILL.md` or its examples. Check the visibility and access permissions of any file that will be committed to the repository.

## Summary

Agent Skills let you store task-specific procedures, decision criteria, and output formats in a project and load them into GitHub Copilot when relevant.

To create one, add `.github/skills/<skill-name>/SKILL.md`, set `name` and `description`, and write specific instructions in the body. Start with a small skill such as `release-notes`, then improve it by reviewing its results against real requests.

See [Agent Skills in VS Code](https://code.visualstudio.com/docs/copilot/customization/agent-skills) and the [Agent Skills specification](https://agentskills.io/) for details.
