#!/usr/bin/env bash
set -euo pipefail

# Script to re-tag and push Docker images from a forked repository.
# Useful for testing builds with different version tags.

# Source shared functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || exit 1
readonly SCRIPT_DIR
# shellcheck source=functions.sh
source "${SCRIPT_DIR}/functions.sh"

# Constants
readonly REPO="codemedic/md2conf"

function usage() {
    echo "Usage: $0 <old-prefix-hash> <new-version>"
    echo "Example: $0 cd4d8cf 1.2.3"
    exit 1
}

# Check if arguments are provided
if [[ $# -lt 2 ]]; then
    usage
fi

readonly OLD_PREFIX="$1"
readonly NEW_VERSION="$2"

function validate_dependencies() {
    if ! command -v jq &> /dev/null; then
        log_error "jq is required but not installed."
        exit 1
    fi
    if ! command -v curl &> /dev/null; then
        log_error "curl is required but not installed."
        exit 1
    fi
    if ! command -v docker &> /dev/null; then
        log_error "docker is required but not installed."
        exit 1
    fi
}

function retag_images() {
    log_info "Fetching tags for ${REPO} matching '${OLD_PREFIX}*'..."

    # Fetch tags and filter locally
    # page_size=100 ensures we get up to 100 tags in one call
    local tags
    tags=$(curl -s "https://hub.docker.com/v2/repositories/${REPO}/tags/?page_size=100" | \
        jq -r '.results[].name' | grep "^${OLD_PREFIX}" || true)

    if [[ -z "${tags}" ]]; then
        log_error "No tags found starting with: ${OLD_PREFIX}"
        exit 1
    fi

    # Iterate, re-tag, and push
    for tag in ${tags}; do
        # Replace the OLD_PREFIX with NEW_VERSION at the start of the string
        local new_tag="${tag/${OLD_PREFIX}/${NEW_VERSION}}"
        
        echo "---------------------------------------------------"
        log_info "Processing: ${tag} -> ${new_tag}"
        
        # Standard docker workflow
        if ! docker pull "${REPO}:${tag}"; then
            log_error "Failed to pull ${REPO}:${tag}"
            continue
        fi

        if ! docker tag "${REPO}:${tag}" "${REPO}:${new_tag}"; then
            log_error "Failed to tag ${REPO}:${tag} as ${REPO}:${new_tag}"
            continue
        fi

        if ! docker push "${REPO}:${new_tag}"; then
            log_error "Failed to push ${REPO}:${new_tag}"
            continue
        fi
    done

    echo "---------------------------------------------------"
    log_info "Successfully processed all matching tags."
}

# Main execution
validate_dependencies
retag_images
