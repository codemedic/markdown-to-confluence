# md2conf GitHub Action

Publish Markdown documentation to Confluence from your GitHub Actions workflows.

## Quick Start

```yaml
name: Publish Docs to Confluence

on:
  push:
    branches:
      - main

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6

      - uses: codemedic/markdown-to-confluence@v1
        with:
          path: './docs'
          space: 'MYSPACE'
          api_key: ${{ secrets.CONFLUENCE_API_KEY }}
```

**Note:** Generate an API token in Confluence (Settings → Personal Settings → API tokens) and add it to your repository secrets as `CONFLUENCE_API_KEY`.

## Configuration

### Required Inputs

| Input | Description |
|-------|-------------|
| `path` | Path to the Markdown file or directory to publish |
| `space` | Confluence space key |
| `api_key` | Confluence API key (store in secrets) |

### Connection Settings

| Input | Description | Default |
|-------|-------------|---------|
| `domain` | Confluence domain (e.g., `your-domain.atlassian.net`) | - |
| `api_url` | Confluence API URL (for scoped tokens, overrides domain) | - |
| `username` | Confluence username (for basic auth) | - |

### Publishing Settings

| Input | Description | Default |
|-------|-------------|---------|
| `root_page_id` | Parent page ID for published pages | - |
| `keep_hierarchy` | Maintain source directory structure | `false` |
| `title_prefix` | Prepend string to page titles | - |
| `skip_title_heading` | Skip first heading if used as title | `true` |
| `generated_by` | Footer text (set to `none` to disable) | `This page has been generated with a tool.` |

### Rendering Settings

| Input | Description | Default |
|-------|-------------|---------|
| `render_mermaid` | Render Mermaid diagrams as images | `true` |
| `render_plantuml` | Render PlantUML diagrams as images | `true` |
| `render_drawio` | Render draw.io diagrams as images | `false` |
| `render_latex` | Render LaTeX formulas as images | `false` |
| `diagram_format` | Output format for diagrams (`png` or `svg`) | `png` |
| `alignment` | Alignment for block-level images (`center`, `left`, `right`) | `center` |
| `max_image_width` | Maximum display width for images in pixels | - |

### Docker Image Settings

| Input | Description | Default |
|-------|-------------|---------|
| `image_repository` | Docker image repository to use | From `image-config.sh` |
| `image_tag` | Docker image tag | From `image-config.sh` |

**Note:** The action uses SHA-pinned images from the configuration file by default. You can override these with custom values if needed.

### Debugging

| Input | Description | Default |
|-------|-------------|---------|
| `debug` | Enable debug logging for troubleshooting | `false` |

## Examples

### Publish a Single File

```yaml
- uses: codemedic/markdown-to-confluence@v1
  with:
    path: './README.md'
    space: 'MYSPACE'
    root_page_id: '123456'
    api_key: ${{ secrets.CONFLUENCE_API_KEY }}
```

### Preserve Directory Structure

```yaml
- uses: codemedic/markdown-to-confluence@v1
  with:
    path: './docs'
    space: 'MYSPACE'
    keep_hierarchy: true
    api_key: ${{ secrets.CONFLUENCE_API_KEY }}
```

### Use Minimal Image (No Diagram Rendering)

```yaml
- uses: codemedic/markdown-to-confluence@v1
  with:
    path: './docs'
    space: 'MYSPACE'
    api_key: ${{ secrets.CONFLUENCE_API_KEY }}
    image_tag: 'latest-minimal'
    render_mermaid: false
    render_plantuml: false
```

### Custom Title Prefix

```yaml
- uses: codemedic/markdown-to-confluence@v1
  with:
    path: './docs'
    space: 'MYSPACE'
    title_prefix: '[Dev] '
    api_key: ${{ secrets.CONFLUENCE_API_KEY }}
```

### SVG Diagrams

```yaml
- uses: codemedic/markdown-to-confluence@v1
  with:
    path: './docs'
    space: 'MYSPACE'
    diagram_format: 'svg'
    api_key: ${{ secrets.CONFLUENCE_API_KEY }}
```

### Debug Mode

Enable debug logging for troubleshooting:

```yaml
- uses: codemedic/markdown-to-confluence@v1
  with:
    path: './docs'
    space: 'MYSPACE'
    api_key: ${{ secrets.CONFLUENCE_API_KEY }}
    debug: true
```

## Docker Image Variants

Available image variants for the `image_tag` input:

| Tag | Description |
|-----|-------------|
| `{version}` | Full image with Mermaid and PlantUML |
| `{version}-minimal` | No diagram rendering |
| `{version}-mermaid` | Mermaid support only |
| `{version}-plantuml` | PlantUML support only |

Where `{version}` is a specific version (e.g., `1.2.3`) or `latest`.

## About

This action provides a GitHub Actions interface for the [md2conf](https://github.com/hunyadi/md2conf) tool. For detailed documentation about the tool itself, see the [upstream repository](https://github.com/hunyadi/md2conf).

## For Maintainers

See [MAINTAINING.md](MAINTAINING.md) for information about:

- Updating Docker image references
- Release process
- Testing procedures
- Troubleshooting
