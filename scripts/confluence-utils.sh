#!/usr/bin/env bash
set -euo pipefail

## Confluence Utility Script
##
## Provides functions to interact with Confluence Cloud REST API (v2).
## Primarily used for managing integration test pages.
##
## Usage:
##   ./confluence-utils.sh [command] [args]
##
## Commands:
##   get-space-id <domain> <api_key> <space_key>
##   get-homepage-id <domain> <api_key> <space_id>
##   create-page <domain> <api_key> <space_id> <parent_id> <title> [content]
##
## Options:
##   -h, --help    Show this help message
##   -d, --debug   Enable debug logging

# Constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || exit 1
readonly SCRIPT_DIR

# Source shared functions
# shellcheck source=scripts/functions.sh
source "${SCRIPT_DIR}/functions.sh"

# Validate dependencies
validate_dependencies curl jq

# Function to get space ID from space key
get_space_id() {
    local domain="$1"
    local api_key="$2"
    local space_key="$3"

    debug_log "Getting space ID for key: ${space_key}"

    local response
    response=$(curl -s -u ":${api_key}" \
        "https://${domain}/wiki/api/v2/spaces?keys=${space_key}&status=current")

    local space_id
    space_id=$(echo "${response}" | jq -r '.results[0].id // empty')

    if [[ -z "${space_id}" || "${space_id}" == "null" ]]; then
        log_error "Space not found: ${space_key}"
        return 1
    fi

    echo "${space_id}"
}

# Function to get space home page ID
get_homepage_id() {
    local domain="$1"
    local api_key="$2"
    local space_id="$3"

    debug_log "Getting homepage ID for space ID: ${space_id}"

    local response
    response=$(curl -s -u ":${api_key}" \
        "https://${domain}/wiki/api/v2/spaces/${space_id}")

    local homepage_id
    homepage_id=$(echo "${response}" | jq -r '.homepageId // empty')

    if [[ -z "${homepage_id}" || "${homepage_id}" == "null" ]]; then
        log_error "Homepage ID not found for space: ${space_id}"
        return 1
    fi

    echo "${homepage_id}"
}

# Function to create a page
create_page() {
    local domain="$1"
    local api_key="$2"
    local space_id="$3"
    local parent_id="$4"
    local title="$5"
    local content="${6:-"<p>This page was created by an automated test.</p>"}"

    debug_log "Creating page: ${title} (Parent: ${parent_id})"

    local payload
    payload=$(jq -n \
        --arg spaceId "${space_id}" \
        --arg parentId "${parent_id}" \
        --arg title "${title}" \
        --arg content "${content}" \
        '{
            spaceId: $spaceId,
            status: "current",
            title: $title,
            parentId: $parentId,
            body: {
                storage: {
                    representation: "storage",
                    value: $content
                }
            }
        }')

    local response
    response=$(curl -s -X POST -u ":${api_key}" \
        -H "Content-Type: application/json" \
        -d "${payload}" \
        "https://${domain}/wiki/api/v2/pages")

    local page_id
    page_id=$(echo "${response}" | jq -r '.id // empty')

    if [[ -z "${page_id}" || "${page_id}" == "null" ]]; then
        log_error "Failed to create page: ${title}"
        debug_log "Response: ${response}"
        return 1
    fi

    echo "${page_id}"
}

main() {
    local cmd="${1:-}"
    shift || true

    case "${cmd}" in
        get-space-id)
            get_space_id "$@"
            ;;
        get-homepage-id)
            get_homepage_id "$@"
            ;;
        create-page)
            create_page "$@"
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            if [[ -n "${cmd}" ]]; then
                log_error "Unknown command: ${cmd}"
            fi
            usage
            exit 1
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
