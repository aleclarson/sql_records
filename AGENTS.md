# Agent Instructions

This repository is optimized for autonomous agent workflows. When operating in this repository, agents should follow these directives:

## Automated Commits

Agents are instructed to commit their work automatically upon completion of a task or a significant sub-task. 

### Commit Message Specification

All commit messages MUST follow the [Conventional Commits](https://www.conventionalcommits.org/) specification. This ensures a consistent and machine-readable commit history.

The message should be structured as follows:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

#### Allowed Types:

- **feat**: A new feature
- **fix**: A bug fix
- **docs**: Documentation only changes
- **style**: Changes that do not affect the meaning of the code (white-space, formatting, missing semi-colons, etc)
- **refactor**: A code change that neither fixes a bug nor adds a feature
- **perf**: A code change that improves performance
- **test**: Adding missing tests or correcting existing tests
- **build**: Changes that affect the build system or external dependencies (example scopes: gulp, broccoli, npm)
- **ci**: Changes to our CI configuration files and scripts (example scopes: Travis, Circle, BrowserStack, SauceLabs)
- **chore**: Other changes that don't modify src or test files
- **revert**: Reverts a previous commit

### Workflow

1.  **Stage Changes**: Use `git add` to stage the relevant changes.
2.  **Commit**: Use `git commit -m "<message>"` with a conventional commit message.
3.  **No Push**: Do not push changes to remote branches unless explicitly requested by the user.
