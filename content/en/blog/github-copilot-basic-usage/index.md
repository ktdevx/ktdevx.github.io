---
title: Basic GitHub Copilot Usage in VS Code
date: 2026-09-02T00:00:00+09:00
draft: false
tags:
  - GitHub
  - GitHub Copilot
  - VS Code
params:
  toc: true
---

GitHub Copilot in Visual Studio Code (VS Code) can help you write, investigate, and modify code with AI assistance.

This article explains how to set up GitHub Copilot in VS Code and try its basic features, including code completion and chat. Always review generated code and run tests when appropriate.

## Prerequisites

Prepare the following:

- VS Code
- A GitHub account
- A plan or free allowance that supports GitHub Copilot

Use a recent version of VS Code when possible. GitHub Copilot plans and usage limits may change, so check the [GitHub Copilot plans page](https://github.com/features/copilot/plans) for the latest information.

## Install the GitHub Copilot extension

1. Start VS Code.
2. Select the Extensions icon in the Activity Bar.
3. Enter `GitHub Copilot` in the search box.
4. Select the GitHub Copilot extension published by GitHub.
5. Select **Install**.

Depending on the version, GitHub Copilot Chat may be included in the same extension. Check the publisher and description in the search results before installing an extension.

## Sign in with your GitHub account

After installing the extension, VS Code may ask you to sign in to your GitHub account.

1. Start GitHub sign-in from the status bar or the Accounts menu in VS Code.
2. When your browser opens, sign in to your GitHub account.
3. Authorize VS Code.
4. Return to VS Code and confirm that the Accounts menu shows you are signed in.

If sign-in does not work, restart VS Code and check the Accounts menu again. If you use an organization account, check whether an administrator has restricted GitHub Copilot access.

## Use code completion

Code completion suggests continuations based on the code and comments you are entering. For example, enter the following comment in a Python file:

```python
# Return the sum of all numbers from 1 through the given number
```

Start entering a function on the next line. A suggested implementation may appear as faint text. To accept the suggestion, press `Tab` in the usual configuration. To dismiss it and continue typing, press `Esc`.

When a suggestion does not match your goal, make the comment more specific. Including argument names, the return value, and whether error handling is required can make your intent clearer.

## Review multiple suggestions

When a suggestion is displayed, other suggestions may be available. The keyboard commands for switching suggestions can vary with the VS Code version, extension version, and keyboard layout.

To view available commands, right-click in the editor and inspect the GitHub Copilot menu, or search for `Copilot` in the Command Palette (`Ctrl+Shift+P`). Before accepting a suggestion, review its logic, error handling, and treatment of external input.

## Ask questions in Copilot Chat

Copilot Chat lets you ask questions about code and errors in natural language.

1. Open Chat from the Activity Bar.
2. Enter a question in the input box.
3. Add relevant files or code as context when necessary.
4. Send the question and review the answer.

For example, enter a specific request such as:

```text
Explain what this function does. Also check whether it handles an empty input safely.
```

Do not assume that the answer is correct. Check that the explanation matches the actual code. Including the project goal, libraries in use, and relevant error messages can make your question more useful.

## Choose Ask, Plan, or Agent mode

The mode selector in Copilot Chat lets you choose an interaction style for your task. The available modes and their names may vary with the VS Code and Copilot versions.

### Ask mode

Ask mode is for asking questions about code, explaining behavior, and investigating errors. It is generally useful when you want an answer or code example without asking Copilot to modify files.

For example, you could enter:

```text
Find the files that handle authentication in this project and explain the flow.
```

### Plan mode

Plan mode is for organizing the investigation and implementation steps before making changes. For work involving several files, creating a plan first can make the target files, sequence of changes, and verification steps easier to review.

Review the plan and provide any corrections before asking Copilot to implement it. Creating a plan does not mean that the code has been changed correctly.

### Agent mode

Agent mode lets Copilot work through a task step by step, which can include inspecting files, editing code, and running tests or commands. For example, you could ask:

```text
Add input validation to the user registration form and create tests for it.
```

Agent mode may change files or run commands. Review any confirmation request before allowing the action, then review the diff, test results, and commands after it finishes. As a simple rule, use Ask for a small investigation, Plan for work that needs preparation, and Agent for a clearly defined implementation task.

## Choose a model

The model picker in Chat lets you switch between available AI models. Models can differ in response speed, strengths, context handling, and how usage is calculated.

Consider the balance between the task and usage when choosing a model:

- Choose a standard or faster model for short explanations and simple questions.
- Choose a model with stronger reasoning for complex design, debugging, or multi-file changes.
- When you want to reduce usage, check the multiplier or description shown next to the model name.

The available models and multipliers depend on your Copilot plan, organization settings, and the current service. A particular model may not always be available, so use the latest information shown in the Chat model picker.

## Choose thinking effort

Models that support reasoning may provide a thinking effort setting. A higher effort can make it easier to work through a complex problem, but it may take longer and use more of your allowance.

- Low effort: checking terminology, short explanations, and simple changes
- Medium effort: ordinary debugging and test creation
- High effort: complex design, isolating a difficult cause, and broad changes

Not every model or plan provides a thinking effort setting. Use it when the selector is available and match it to the complexity of the task. A higher effort does not guarantee a correct answer, so review the generated result.

## Understand credits

Credits are a way to measure AI usage in GitHub Copilot. The amount available each month depends on the plan, and the amount consumed can vary by the request, model, and feature. An advanced model or task may consume more than one credit for a single request.

Credits are not a score for code quality or correctness. The quantity and terminology shown in VS Code can also vary with your subscription and GitHub's billing system. Check your account settings or usage page for the remaining amount and reset date. When appropriate, choose a lower-cost model or Ask mode to manage usage.

## Explain or modify selected code

You can ask questions about a selected section of code.

1. Select the code you want to understand in the editor.
2. Right-click and open the GitHub Copilot menu.
3. Choose an action such as explaining the code, modifying it, or creating tests.
4. Review the proposed change.

When asking for a modification, state the goal precisely. For example:

```text
Add input validation to this code. Keep the existing return value format unchanged.
```

Review the diff before applying the proposed change. If the change is broad, inspect each part and undo anything unnecessary.

## Use inline chat

Inline chat lets you make a request about the current code without leaving the editor.

1. Select the target code in the editor.
2. Search for `Copilot` in the Command Palette and choose the command that starts inline chat.
3. Enter the change you want.
4. Review the displayed diff, then apply or cancel it.

Include both the scope and constraints in your request. For example: `Modify only this function and do not change the name of its public API`.

## Review and apply suggestions

Use the following process when adopting a GitHub Copilot suggestion:

1. Review the diff before and after the change.
2. Confirm that the generated logic matches your request.
3. Check types, return values, exceptions, and boundary cases.
4. Run tests and static analysis.
5. Save and commit the change only after it passes your checks.

When fixing an error, investigate the error message instead of hiding it. Do not assume that an error is resolved just because Copilot suggested a change. Run the application or tests to verify the result.

## Things to keep in mind

### Do not enter sensitive information

Do not enter API keys, passwords, personal information, customer information, or confidential company information in prompts or chat. Replace real values with a minimal example that does not expose sensitive data.

### Verify generated code

Generated code may contain errors, vulnerabilities, or inefficient processing. Review code involving authentication, authorization, input validation, encryption, and database operations against official documentation and test results.

### Check licenses and dependencies

If you use generated code in publicly distributed software, check the project's license and the terms of dependent libraries. Investigate any concerns about the origin or usage conditions of code before adopting it.

### Keep changes small

Small, focused requests make generated diffs easier to review than a request to generate a large feature all at once. Consider working on a Git branch so you can restore the previous state when necessary.

## Summary

In VS Code, GitHub Copilot can help with code completion, questions in chat, explanations and modifications of selected code, and inline chat.

Copilot is a development aid, not a replacement for review. Check the request and the diff, and use tests, static analysis, and security reviews as part of your workflow.

For detailed setup instructions, see [Setting up GitHub Copilot (GitHub Docs)](https://docs.github.com/en/copilot/how-tos/set-up).
