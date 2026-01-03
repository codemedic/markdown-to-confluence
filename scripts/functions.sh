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
