#!/usr/bin/env bash
# Shared Functions Library
# Common functions and constants used across multiple scripts

# Colors for logging
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Logging functions
function log_info() {
    echo -e "${GREEN}[INFO]${NC} $*" >&2
}

function log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

function log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

function debug_log() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        log_info "[DEBUG] $*"
    fi
}

# Function to extract and display lines starting with '##' from the calling script
function usage() {
    # grep: finds lines starting with ##
    # sed: removes the leading ## and optional space
    grep '^##' "$0" | sed 's/^##\s\?//'
}

# Function to validate binary dependencies
function validate_dependencies() {
    local missing=()
    for cmd in "$@"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing[*]}"
        exit 1
    fi
}
