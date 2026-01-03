# Commit Conventions

This project follows [Conventional Commits](https://www.conventionalcommits.org/) to communicate the nature of changes.

## Commit Message Format

```text
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

## Types

- **feat**: A new feature (triggers a Minor release)
- **fix**: A bug fix (triggers a Patch release)
- **feat!** or **fix!**: A breaking change (triggers a Major release)
- **chore**: Maintenance tasks, dependency updates, or image updates
- **docs**: Documentation only changes
- **style**: Changes that do not affect the meaning of the code (white-space, formatting, etc)
- **refactor**: A code change that neither fixes a bug nor adds a feature
- **test**: Adding missing tests or correcting existing tests

## Examples

- `chore: update to md2conf v0.5.3`
- `feat: add support for custom CSS`
- `feat!: rename image_tag to image_version`
- `fix: handle spaces in input paths`
- `docs: update maintainer guide`
