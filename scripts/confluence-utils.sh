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
##   get-space-id <domain> <api_key> <space_key> [username]
##   get-homepage-id <domain> <api_key> <space_id> [username]
##   create-page <domain> <api_key> <space_id> <parent_id> <title> [content] [username]
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

# Helper to perform authenticated curl
run_curl() {
    local method="$1"
    local url="$2"
    local api_key="$3"
    local username="${4:-}"
    shift 4
    local -a extra_args=("$@")

    local auth="${username}:${api_key}"
    [[ -z "${username}" ]] && auth=":${api_key}"

    debug_log "Request: ${method} ${url}"
    
    local response
    local http_code
    local temp_file
    temp_file=$(mktemp)

    http_code=$(curl -s -w "%{http_code}" -X "${method}" -u "${auth}" \
        -H "Accept: application/json" \
        "${extra_args[@]}" \
        "${url}" -o "${temp_file}")

    response=$(cat "${temp_file}")
    rm -f "${temp_file}"

    if [[ "${http_code}" -lt 200 || "${http_code}" -ge 300 ]]; then
        log_error "API request failed (HTTP ${http_code})"
        log_error "Response: ${response}"
        return 1
    fi

    echo "${response}"
}

# Function to get space ID from space key
get_space_id() {
    local domain="$1"
    local api_key="$2"
    local space_key="$3"
    local username="${4:-}"

    debug_log "Getting space ID for key: ${space_key}"

    local url="https://${domain}/wiki/api/v2/spaces?keys=${space_key}&status=current"
    local response
    response=$(run_curl GET "${url}" "${api_key}" "${username}") || return 1

    local space_id
    space_id=$(echo "${response}" | jq -r '.results[0].id // empty')

    if [[ -z "${space_id}" || "${space_id}" == "null" ]]; then
        log_error "Space not found: ${space_key}"
        debug_log "Response: ${response}"
        return 1
    fi

    echo "${space_id}"
}

# Function to get space home page ID
get_homepage_id() {
    local domain="$1"
    local api_key="$2"
    local space_id="$3"
    local username="${4:-}"

    debug_log "Getting homepage ID for space ID: ${space_id}"

    local url="https://${domain}/wiki/api/v2/spaces/${space_id}"
    local response
    response=$(run_curl GET "${url}" "${api_key}" "${username}") || return 1

    local homepage_id
    homepage_id=$(echo "${response}" | jq -r '.homepageId // empty')

    if [[ -z "${homepage_id}" || "${homepage_id}" == "null" ]]; then
        log_error "Homepage ID not found for space: ${space_id}"
        debug_log "Response: ${response}"
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
    local username="${7:-}"

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

    local url="https://${domain}/wiki/api/v2/pages"
    local response
    response=$(run_curl POST "${url}" "${api_key}" "${username}" -H "Content-Type: application/json" -d "${payload}") || return 1

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

