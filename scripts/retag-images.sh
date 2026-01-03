#!/usr/bin/env bash
set -euo pipefail

## Script to re-tag and push Docker images from a forked repository.
## Useful for testing builds with different version tags.
##
## Usage:
##   ./retag-images.sh [options] <old-prefix-hash> <new-version>
##
## Options:
##   -h, --help    Show this help message
##   -d, --debug   Enable debug logging
##
## Example:
##   ./retag-images.sh cd4d8cf 1.2.3

# Source shared functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || exit 1
readonly SCRIPT_DIR
# shellcheck source=functions.sh
source "${SCRIPT_DIR}/functions.sh"

# Constants
readonly REPO="codemedic/md2conf"

function retag_images() {
    local old_prefix="$1"
    local new_version="$2"

    log_info "Fetching tags for ${REPO} matching '${old_prefix}*'..."

    # Fetch tags and filter locally
    # page_size=100 ensures we get up to 100 tags in one call
    local tags
    tags=$(curl -s "https://hub.docker.com/v2/repositories/${REPO}/tags/?page_size=100" | \
        jq -r '.results[].name' | grep "^${old_prefix}" || true)

    if [[ -z "${tags}" ]]; then
        log_error "No tags found starting with: ${old_prefix}"
        exit 1
    fi

    # Iterate, re-tag, and push
    for tag in ${tags}; do
        # Replace the old_prefix with new_version at the start of the string
        local new_tag="${tag/${old_prefix}/${new_version}}"
        
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
main() {
    local old_prefix=""
    local new_version=""

    # Argument parsing loop
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -d|--debug)
                export DEBUG=1
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -*)
                echo "Unknown option: $1" >&2
                usage
                exit 1
                ;;
            *)
                if [[ -z "$old_prefix" ]]; then
                    old_prefix="$1"
                elif [[ -z "$new_version" ]]; then
                    new_version="$1"
                else
                    echo "Too many arguments: $1" >&2
                    usage
                    exit 1
                fi
                ;;
        esac
        shift
    done

    if [[ -z "$old_prefix" || -z "$new_version" ]]; then
        usage
        exit 1
    fi

    validate_dependencies
    retag_images "$old_prefix" "$new_version"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
