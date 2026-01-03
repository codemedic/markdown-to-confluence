#!/usr/bin/env bash
set -euo pipefail

# Docker Image Update Automation
# Checks upstream Docker Hub for new image versions and updates image-config.sh
# with version tags and SHA256 digests.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || exit 1
readonly SCRIPT_DIR

# Source shared functions
# shellcheck source=functions.sh
source "${SCRIPT_DIR}/functions.sh"

# Function to get SHA256 digest for a specific image tag
get_image_sha() {
    local repo="$1"
    local tag="$2"

    log_info "Fetching SHA256 for ${repo}:${tag}..."

    # Pull the image to get its digest
    if ! docker pull "${repo}:${tag}" >/dev/null 2>&1; then
        log_error "Failed to pull ${repo}:${tag}"
        return 1
    fi

    # Get the SHA256 digest
    local sha
    sha=$(docker inspect --format='{{index .RepoDigests 0}}' "${repo}:${tag}" | cut -d'@' -f2 | cut -d':' -f2)

    if [[ -z "$sha" ]]; then
        log_error "Failed to extract SHA256 for ${repo}:${tag}"
        return 1
    fi

    echo "$sha"
}

# Function to query Docker Hub API for latest tag
get_latest_version() {
    local repo="$1"
    local major_filter="${2:-}"

    if [[ -n "$major_filter" ]]; then
        log_info "Querying Docker Hub for latest version of ${repo} (major: ${major_filter})..."
    else
        log_info "Querying Docker Hub for latest version of ${repo}..."
    fi

    # Try to get the most recent versioned tag (*.*.*)
    local latest_tag
    local filter_regex='^[0-9]+\.[0-9]+\.[0-9]+$'
    if [[ -n "$major_filter" ]]; then
        # Strip 'v' if present in major filter
        local clean_major="${major_filter#v}"
        filter_regex="^${clean_major}\.[0-9]+\.[0-9]+$"
    fi

    latest_tag=$(curl -s "https://hub.docker.com/v2/repositories/${repo}/tags/?page_size=100" | \
        jq -r '.results[].name' | \
        grep -E "$filter_regex" | \
        sort -V | \
        tail -n1)

    if [[ -z "$latest_tag" ]]; then
        if [[ -n "$major_filter" ]]; then
            log_error "No versioned tag found for major version ${major_filter}"
            return 1
        fi
        log_warn "No versioned tag found, using 'latest'"
        latest_tag="latest"
    fi

    echo "$latest_tag"
}

# Function to update image-config.sh
update_config() {
    local config_file="$1"
    local repo="$2"
    local version="$3"
    local sha_all="$4"
    local sha_minimal="$5"
    local sha_mermaid="$6"
    local sha_plantuml="$7"

    local timestamp
    timestamp=$(date --utc +"%Y-%m-%d %H:%M:%S UTC")

    local template="${SCRIPT_DIR}/image-config.sh.template"
    if [[ ! -f "$template" ]]; then
        log_error "Template not found: ${template}"
        return 1
    fi

    TIMESTAMP="$timestamp" \
    REPO="$repo" \
    VERSION="$version" \
    SHA_ALL="$sha_all" \
    SHA_MINIMAL="$sha_minimal" \
    SHA_MERMAID="$sha_mermaid" \
    SHA_PLANTUML="$sha_plantuml" \
    envsubst '$TIMESTAMP,$REPO,$VERSION,$SHA_ALL,$SHA_MINIMAL,$SHA_MERMAID,$SHA_PLANTUML' \
        < "$template" > "$config_file"

    log_info "Updated ${config_file}"
}

# Main execution
main() {
    local check_only=false
    local version=""
    local major_version=""
    local config_file="${SCRIPT_DIR}/image-config.sh"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --check)
                check_only=true
                shift
                ;;
            --alternative)
                config_file="${SCRIPT_DIR}/image-config-alternative.sh"
                shift
                ;;
            --major)
                major_version="$2"
                shift 2
                ;;
            --version)
                version="$2"
                shift 2
                ;;
            --help)
                cat <<EOF
Usage: $0 [OPTIONS]

Update Docker image references with SHA256 digests.

Options:
  --check           Check for updates without modifying files
  --alternative     Update image-config-alternative.sh instead of image-config.sh
  --major <v>       Filter by major version (e.g., 1). Defaults to current major.
  --version <tag>   Use specific version tag (default: auto-detect latest)
  --help            Show this help message

Examples:
  # Check for latest version in current major
  $0 --check

  # Update to latest version in current major
  $0

  # Update alternative config
  $0 --alternative

  # Upgrade to a new major version
  $0 --major 2

  # Update to specific version
  $0 --version 0.5.3
EOF
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Strip 'v' prefix from inputs if present
    major_version="${major_version#v}"
    version="${version#v}"

    # Check dependencies
    if ! command -v docker &> /dev/null; then
        log_error "Docker is required but not installed"
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        log_error "jq is required but not installed"
        exit 1
    fi

    if ! command -v envsubst &> /dev/null; then
        log_error "envsubst is required but not installed (usually part of gettext)"
        exit 1
    fi

    # Load current configuration to get repository and current major version
    if [[ -f "$config_file" ]]; then
        # shellcheck source=scripts/image-config.sh
        source "$config_file"
    else
        log_warn "Configuration file ${config_file} not found. Using defaults."
        DEFAULT_IMAGE_REPOSITORY="leventehunyadi/md2conf"
        DEFAULT_IMAGE_VERSION="latest"
    fi

    local repo="${DEFAULT_IMAGE_REPOSITORY}"

    # Determine major version filter if not specified
    if [[ -z "$version" && -z "$major_version" ]]; then
        if [[ "$DEFAULT_IMAGE_VERSION" =~ ^([0-9]+)\. ]]; then
            major_version="${BASH_REMATCH[1]}"
            log_info "Detected current major version: ${major_version}"
        fi
    fi

    # Determine version to use
    if [[ -z "$version" ]]; then
        version=$(get_latest_version "$repo" "$major_version")
        log_info "Detected latest version: ${version}"
    else
        log_info "Using specified version: ${version}"
    fi

    # Get SHA256 digests for all variants
    log_info "Fetching SHA256 digests for all image variants..."

    sha_all=$(get_image_sha "$repo" "${version}")
    sha_minimal=$(get_image_sha "$repo" "${version}-minimal")
    sha_mermaid=$(get_image_sha "$repo" "${version}-mermaid")
    sha_plantuml=$(get_image_sha "$repo" "${version}-plantuml")

    # Display results
    echo ""
    log_info "Image Details:"
    echo "  Repository: ${repo}"
    echo "  Version: ${version}"
    echo "  Config: ${config_file}"
    echo ""
    echo "  SHA256 Digests:"
    echo "    all:      ${sha_all}"
    echo "    minimal:  ${sha_minimal}"
    echo "    mermaid:  ${sha_mermaid}"
    echo "    plantuml: ${sha_plantuml}"
    echo ""

    if [[ "$check_only" == true ]]; then
        log_info "Check complete (no files modified)"
        exit 0
    fi

    # Update configuration
    update_config "$config_file" "$repo" "$version" "$sha_all" "$sha_minimal" "$sha_mermaid" "$sha_plantuml"

    log_info "Update complete!"
    log_info "Next steps:"
    echo "  1. Review changes: git diff ${config_file}"
    echo "  2. Test locally: cd test/docs && ../../scripts/run-md2conf.sh"
    echo "  3. Commit changes: git add ${config_file} && git commit -m 'chore: update to md2conf ${version}'"
    echo "  4. Create release: git tag v1.x.x && git push --tags"
}

main "$@"
