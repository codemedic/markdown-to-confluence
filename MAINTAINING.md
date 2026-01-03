# Maintainer Guide

This document provides guidance for maintainers of the markdown-to-confluence GitHub Action.

## Table of Contents

- [Architecture](#architecture)
- [Docker Image Management](#docker-image-management)
- [Release Process](#release-process)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)

## Architecture

### Repository Structure

```text
markdown-to-confluence/
├── action.yml                    # GitHub Action definition
├── README.md                     # User documentation
├── MAINTAINING.md                # This file
├── scripts/
│   ├── run-md2conf.sh           # Main execution script
│   ├── update-docker-image.sh   # Automation for image updates
│   ├── retag-images.sh          # Re-tag images for testing
│   ├── image-config.sh          # Docker image configuration
│   ├── functions.sh             # Shared functions library
│   └── test-*.sh                # Unit test scripts
├── test/docs/                    # Sample documentation
└── .github/workflows/
    ├── unit-tests.yml           # Unit test automation
    └── test-action.yml          # Integration test workflow
```

### Design Decisions

**SHA256 Pinning**: Images are pinned with both version tags and SHA256 digests for immutability and security.

**External Scripts**: Bash logic is extracted from action.yml into separate scripts for:

- Testability (scripts can be run locally)
- Maintainability (easier to review and modify)
- Reusability (scripts can be used outside GitHub Actions)

**Independent Versioning**: Action version is decoupled from upstream md2conf version, allowing flexibility in release timing.

## Docker Image Management

### Automated Updates

Use `scripts/update-docker-image.sh` to check and update Docker image references:

```bash
# Check for new upstream version (within current major)
./scripts/update-docker-image.sh --check

# Update to latest version (within current major)
./scripts/update-docker-image.sh

# Update alternative configuration
./scripts/update-docker-image.sh --alternative

# Upgrade to a new major version
./scripts/update-docker-image.sh --major v2

# Update to specific version
./scripts/update-docker-image.sh --version v0.5.3
```

### What Gets Updated

The script updates `scripts/image-config.sh` (or `scripts/image-config-alternative.sh` if `--alternative` is used) with:

- Image repository
- Version tag
- SHA256 digests for all 4 variants (all, minimal, mermaid, plantuml)

### Alternative Configuration

For testing fork builds or custom image sets, you can use `scripts/image-config-alternative.sh`. This file is ignored by default unless `use_experimental_features` is set to `true` in the action inputs.

To update the alternative configuration:

```bash
# Point to your own repository in image-config-alternative.sh first, then run:
./scripts/update-docker-image.sh --alternative
```

### Testing Fork Builds

When testing builds from a fork (e.g., `codemedic/md2conf`), you might need to re-tag existing images with a new version for testing purposes. Use `scripts/retag-images.sh` to automate this:

```bash
# Usage: ./scripts/retag-images.sh <old-prefix-hash> <new-version>
# Example: Re-tag images starting with 'cd4d8cf' to '1.2.3'
./scripts/retag-images.sh cd4d8cf 1.2.3
```

This script pulls images from `codemedic/md2conf` matching the prefix, tags them with the new version, and pushes them back to the same repository.

### Dependencies

- **docker**: Pull images and extract digests
- **jq**: Parse Docker Hub API responses
- **curl**: Query Docker Hub API
- **envsubst**: Generate configuration from template (part of `gettext`)

Install on Ubuntu/Debian:

```bash
sudo apt-get install docker.io jq curl gettext
```

Install on macOS:

```bash
brew install docker jq curl
```

### Manual Image Updates

If automation fails, manually update `scripts/image-config.sh`:

1. Pull image:

   ```bash
   docker pull leventehunyadi/md2conf:v0.5.3
   ```

2. Get SHA256:

   ```bash
   docker inspect --format='{{index .RepoDigests 0}}' leventehunyadi/md2conf:v0.5.3
   ```

3. Update configuration file with version and SHA

## Release Process

### Versioning Strategy

This project follows [Semantic Versioning](https://semver.org/).

| Release Type | Condition | Example |
| :--- | :--- | :--- |
| **Patch** | Bug fixes, documentation updates, or upstream image updates (no interface changes). | `v1.0.0` → `v1.0.1` |
| **Minor** | New features or inputs added in a backward-compatible manner. | `v1.0.1` → `v1.1.0` |
| **Major** | Breaking changes to the action interface (renaming/removing inputs, changing behavior). | `v1.1.0` → `v2.0.0` |

**Conventional Commits**:

Maintainers are encouraged to use [Conventional Commits](https://www.conventionalcommits.org/) to clearly communicate the nature of changes. Refer to [COMMIT_CONVENTIONS.md](COMMIT_CONVENTIONS.md) for a full list of types and examples.

- `fix:` for patches.
- `feat:` for minor releases.
- `feat!:` or `fix!:` for major releases (breaking changes).
- `chore:`, `docs:`, `style:`, `refactor:`, `test:` for other changes.

**Development Tags**:

Tags containing a hyphen (e.g., `v1.2.3-dev1`, `v1.2.3-rc1`) are treated as development or pre-release versions. These tags:

- Trigger the standard test workflows.
- **Do not** update the major version alias (e.g., `v1` will not be moved to a `-dev` tag).

**Upstream Tracking**:

- Monitor <https://github.com/hunyadi/md2conf/releases>
- Update when new md2conf versions are released
- Test carefully before releasing

### Patch Release (Image Update)

When upstream releases a new md2conf version:

```bash
# 1. Update images
./scripts/update-docker-image.sh

# 2. Review changes
git diff scripts/image-config.sh

# 3. Test locally (requires Confluence credentials)
export CONFLUENCE_DOMAIN="your-domain.atlassian.net"
export CONFLUENCE_API_KEY="your-api-key"
export CONFLUENCE_SPACE_KEY="TEST"
cd test/docs && ../../scripts/run-md2conf.sh
cd ../..

# 4. Commit
git add scripts/image-config.sh
git commit -m "chore: update to md2conf v0.5.3"

# 5. Tag and push
git tag v1.0.1
git push origin main --tags

# 6. (Optional) Sync major version tag locally
git fetch --tags --force
# The tag-alias workflow updates major version tags (e.g., v1) on the remote.
# Use this to sync your local tags with the remote state.
```

### Minor Release (New Feature)

When adding new functionality:

```bash
# 1. Implement feature
#    - Update action.yml (add inputs)
#    - Update scripts/run-md2conf.sh (handle new inputs)
#    - Update README.md (document new inputs)

# 2. Test
cd test/docs && ../../scripts/run-md2conf.sh

# 3. Commit
git commit -am "feat: add support for custom CSS"

# 4. Tag and push
git tag v1.1.0
git push origin main --tags

# 5. (Optional) Sync major version tag locally
git fetch --tags --force
```

### Major Release (Breaking Changes)

When introducing breaking changes:

```bash
# 1. Update code with breaking changes
# 2. Update README.md with migration guide
# 3. Update sample documentation
# 4. Commit with detailed description
git commit -am "feat!: rename image_tag to image_version

BREAKING CHANGE: The 'image_tag' input has been renamed to
'image_version' for clarity. Update your workflows:

Before:
  image_tag: 'v0.5.3'

After:
  image_version: 'v0.5.3'"

# 5. Tag major version
git tag v2.0.0
git push origin main --tags

# 6. (Optional) Sync major version tag locally
git fetch --tags --force
```

## Testing

### Unit Tests

The project includes unit tests for bash scripts to ensure core functionality works correctly.

**Running unit tests:**

```bash
# Run all test scripts
./scripts/test-image-config.sh

# Or let the workflow script discover and run all tests
find scripts -name 'test-*.sh' -type f -exec {} \;
```

**Adding new tests:**

1. Create a new test script following the naming convention: `scripts/test-<feature>.sh`
2. Make it executable: `chmod +x scripts/test-<feature>.sh`
3. Follow the pattern in `scripts/test-image-config.sh`:
   - Source the script under test
   - Mock external dependencies
   - Implement test functions with clear assertions
   - Provide pass/fail summary

The `.github/workflows/unit-tests.yml` workflow automatically discovers and runs all `test-*.sh` scripts on pull requests.

### Local Integration Testing

Test the action locally using the sample documentation:

```bash
# Set up environment
export CONFLUENCE_DOMAIN="your-domain.atlassian.net"
export CONFLUENCE_API_KEY="your-api-key"
export CONFLUENCE_SPACE_KEY="TEST"
export CONFLUENCE_ROOT_PAGE_ID="123456"  # Optional

# Export inputs as INPUT_* environment variables
export INPUT_PATH="test/docs"
export INPUT_SPACE="$CONFLUENCE_SPACE_KEY"
export INPUT_API_KEY="$CONFLUENCE_API_KEY"
export INPUT_DOMAIN="$CONFLUENCE_DOMAIN"
export INPUT_ROOT_PAGE_ID="$CONFLUENCE_ROOT_PAGE_ID"
export INPUT_KEEP_HIERARCHY="true"
export INPUT_RENDER_MERMAID="true"
export INPUT_RENDER_PLANTUML="true"
export INPUT_DIAGRAM_FORMAT="svg"
export GITHUB_WORKSPACE="$PWD"

# Run the script
./scripts/run-md2conf.sh
```

### CI Testing

The project includes two CI workflows:

**Unit Tests (`.github/workflows/unit-tests.yml`):**
- Runs on all pull requests and pushes to master
- Executes all `scripts/test-*.sh` test scripts
- No credentials required
- Fast feedback on code changes

**Integration Tests (`.github/workflows/test-action.yml`):**
- **Pull Requests**: Dry-run mode (doesn't require credentials)
- **Main Branch**: Live test against Confluence (requires configured secrets)

Configure repository secrets for live integration testing:

**Secrets:**

- `CONFLUENCE_API_KEY`

**Variables:**

- `CONFLUENCE_DOMAIN`
- `CONFLUENCE_USER_NAME`
- `CONFLUENCE_SPACE_KEY`
- `CONFLUENCE_ROOT_PAGE_ID`

### Sample Documentation

The `test/docs/` directory contains sample content for validation:

- **index.md**: Main documentation page
- **plantuml-embedded.md**: Embedded PlantUML diagrams
- **plantuml-linked.md**: External PlantUML files
- **mermaid-embedded.md**: Embedded Mermaid diagrams
- **mermaid-linked.md**: External Mermaid files
- **diagrams/**: External diagram files (.puml, .mmd)

Update sample content when adding new features or fixing bugs.

## Troubleshooting

### Script Errors

#### Error: Image configuration not found

- Ensure `scripts/image-config.sh` exists
- Run `./scripts/update-docker-image.sh` to generate
- Check if `use_experimental_features` is set correctly

#### Error: Failed to pull image

- Check Docker daemon is running: `docker ps`
- Verify network connectivity
- Check image exists: `docker pull leventehunyadi/md2conf:latest`

#### Error: jq command not found

- Install jq: `sudo apt-get install jq` (Ubuntu) or `brew install jq` (macOS)

### Action Failures

#### Permission denied on scripts

- Ensure scripts are executable: `chmod +x scripts/*.sh`

#### Path does not exist in workspace

- Verify `INPUT_PATH` is relative to repository root
- Check path exists: `ls -la $GITHUB_WORKSPACE/$INPUT_PATH`

#### Docker image pull failure

- Check SHA digest is valid
- Verify network allows Docker Hub access
- Try pulling manually: `docker pull leventehunyadi/md2conf:latest@sha256:...`

### Upstream Tracking

**How to check for new upstream releases:**

```bash
# Check GitHub releases
gh release list --repo hunyadi/md2conf --limit 5

# Check Docker Hub tags
curl -s "https://hub.docker.com/v2/repositories/leventehunyadi/md2conf/tags/?page_size=10" | \
  jq -r '.results[].name' | \
  grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+$' | \
  sort -V
```

## Contributing

### Adding New Inputs

1. Add input to `action.yml`. Use **snake_case** for input names and group related inputs with comments.
2. Handle input in `scripts/run-md2conf.sh`.
3. Document in `README.md`.
4. Add test case in `test/docs/`
5. Update this guide if needed

### Modifying Scripts

1. Update script in `scripts/`
2. For reusable functions, add to `scripts/functions.sh`
3. Source `functions.sh` in scripts: `source "${SCRIPT_DIR}/functions.sh"`
4. **Best Practices**:
   - **Fail Fast**: Use `set -euo pipefail` in all scripts.
   - **Quote Variables**: Always quote variables to handle paths with spaces.
   - **Use Arrays**: Use arrays for complex command arguments to avoid quoting issues.
   - **Log Grouping**: Use `echo "::group::Title"` and `echo "::endgroup::"` for cleaner GitHub Actions logs.
5. Test locally
6. Update documentation
7. Commit with descriptive message

### Security Considerations

- **Never commit secrets**: Use environment variables or GitHub secrets.
- **Secrets in Docker**: When passing secrets to Docker, use a temporary environment file instead of `--env` to avoid secrets appearing in process lists:

  ```bash
  ENV_FILE=$(mktemp)
  echo "SECRET_VAR=${SECRET_VALUE}" >> "$ENV_FILE"
  docker run --env-file "$ENV_FILE" ...
  rm "$ENV_FILE"
  ```

- **Validate inputs**: Check for injection attacks in user inputs. Fail early with clear error messages.
- **Pin dependencies**: Use SHA256 for Docker images.
- **Review updates**: Manually review upstream changes before adopting.

## Resources

- **Upstream Project**: <https://github.com/hunyadi/md2conf>
- **Docker Images**: <https://hub.docker.com/r/leventehunyadi/md2conf>
- **GitHub Actions Docs**: <https://docs.github.com/en/actions>
- **Composite Actions**: <https://docs.github.com/en/actions/creating-actions/creating-a-composite-action>
