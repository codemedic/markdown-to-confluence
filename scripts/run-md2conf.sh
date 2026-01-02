#!/bin/bash
set -euo pipefail

# md2conf Docker Execution Script
# Handles execution of md2conf via Docker with proper argument building,
# path handling, and security measures.

# Constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || exit 1
readonly SCRIPT_DIR
readonly CONFIG_FILE="${SCRIPT_DIR}/image-config.sh"

# Source shared functions
# shellcheck source=scripts/functions.sh
source "${SCRIPT_DIR}/functions.sh"

# Global variables
ARGS=()
MOUNT_DIR=""
CONTENT_NAME=""
IMAGE_TO_USE=""
ENV_FILE=""

# Cleanup function
function cleanup() {
    if [[ -n "${ENV_FILE}" && -f "${ENV_FILE}" ]]; then
        debug_log "Removing temporary environment file"
        rm -f "${ENV_FILE}"
    fi
}

trap cleanup EXIT INT TERM

# Validate required inputs
function validate_inputs() {
    local errors=()

    if [[ -z "${INPUT_PATH:-}" ]]; then
        errors+=("INPUT_PATH is required")
    fi

    if [[ -z "${INPUT_SPACE:-}" ]]; then
        errors+=("INPUT_SPACE is required")
    fi

    if [[ -z "${INPUT_API_KEY:-}" ]]; then
        errors+=("INPUT_API_KEY is required")
    fi

    if [[ ${#errors[@]} -gt 0 ]]; then
        log_error "Input validation failed:"
        for error in "${errors[@]}"; do
            log_error "  - ${error}"
        done
        return 1
    fi

    return 0
}

# Load image configuration
function load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Image configuration not found: ${CONFIG_FILE}"
        return 1
    fi

    debug_log "Loading configuration from ${CONFIG_FILE}"

    # shellcheck source=scripts/image-config.sh
    source "$CONFIG_FILE"

    debug_log "Configuration loaded successfully"
    return 0
}

# Build md2conf arguments array
function build_args() {
    ARGS=()

    debug_log "Building md2conf arguments"

    # Publishing options
    if [[ -n "${INPUT_ROOT_PAGE_ID:-}" ]]; then
        ARGS+=(-r "${INPUT_ROOT_PAGE_ID}")
    fi

    if [[ "${INPUT_KEEP_HIERARCHY:-false}" == "true" ]]; then
        ARGS+=(--keep-hierarchy)
    fi

    if [[ -n "${INPUT_TITLE_PREFIX:-}" ]]; then
        ARGS+=(--title-prefix "${INPUT_TITLE_PREFIX}")
    fi

    if [[ "${INPUT_SKIP_TITLE_HEADING:-true}" == "true" ]]; then
        ARGS+=(--skip-title-heading)
    fi

    if [[ "${INPUT_GENERATED_BY:-}" == "none" ]]; then
        ARGS+=(--no-generated-by)
    elif [[ -n "${INPUT_GENERATED_BY:-}" ]]; then
        ARGS+=(--generated-by "${INPUT_GENERATED_BY}")
    fi

    # Rendering options
    if [[ "${INPUT_RENDER_DRAWIO:-false}" == "false" ]]; then
        ARGS+=(--no-render-drawio)
    fi

    if [[ "${INPUT_RENDER_MERMAID:-true}" == "false" ]]; then
        ARGS+=(--no-render-mermaid)
    fi

    if [[ "${INPUT_RENDER_PLANTUML:-true}" == "false" ]]; then
        ARGS+=(--no-render-plantuml)
    fi

    if [[ "${INPUT_RENDER_LATEX:-false}" == "false" ]]; then
        ARGS+=(--no-render-latex)
    fi

    if [[ "${INPUT_DIAGRAM_FORMAT:-png}" != "png" ]]; then
        ARGS+=(--diagram-output-format "${INPUT_DIAGRAM_FORMAT}")
    fi

    if [[ "${INPUT_ALIGNMENT:-center}" != "center" ]]; then
        ARGS+=(--alignment "${INPUT_ALIGNMENT}")
    fi

    if [[ -n "${INPUT_MAX_IMAGE_WIDTH:-}" ]]; then
        ARGS+=(--max-image-width "${INPUT_MAX_IMAGE_WIDTH}")
    fi

    # Confluence connection arguments
    if [[ -n "${INPUT_DOMAIN:-}" ]]; then
        ARGS+=(--domain "${INPUT_DOMAIN}")
    fi

    if [[ -n "${INPUT_API_URL:-}" ]]; then
        ARGS+=(--api-url "${INPUT_API_URL}")
    fi

    if [[ -n "${INPUT_USERNAME:-}" ]]; then
        ARGS+=(--username "${INPUT_USERNAME}")
    fi

    if [[ -n "${INPUT_SPACE:-}" ]]; then
        ARGS+=(--space "${INPUT_SPACE}")
    fi

    debug_log "Built ${#ARGS[@]} arguments"
}

# Determine which Docker image to use
function determine_image() {
    debug_log "Determining Docker image to use"

    # Priority: user custom > user tag override > default config
    if [[ -n "${INPUT_IMAGE_REPOSITORY:-}" && "${INPUT_IMAGE_REPOSITORY}" != "${DEFAULT_IMAGE_REPOSITORY}" ]]; then
        # User specified a custom repository
        local image_repo="${INPUT_IMAGE_REPOSITORY}"
        local image_tag="${INPUT_IMAGE_TAG:-latest}"

        # Custom repositories don't have SHA pinning
        IMAGE_TO_USE="${image_repo}:${image_tag}"
        log_info "Using custom Docker image: ${IMAGE_TO_USE}"

    elif [[ -n "${INPUT_IMAGE_TAG:-}" ]]; then
        # User wants a specific tag from the default repository
        local image_tag="${INPUT_IMAGE_TAG}"

        # Try to find SHA for this tag in our config
        case "${image_tag}" in
            latest|*-minimal|*-mermaid|*-plantuml)
                # Extract variant name
                local variant_name="${image_tag//latest/all}"
                variant_name="${variant_name#*-}"
                [[ "$variant_name" == "all" ]] && variant_name="all"

                # Build SHA variable name
                local sha_var="DEFAULT_IMAGE_SHA_${variant_name^^}"
                sha_var="${sha_var//-/_}"
                local image_sha="${!sha_var:-}"

                if [[ -n "$image_sha" ]]; then
                    IMAGE_TO_USE="${DEFAULT_IMAGE_REPOSITORY}:${image_tag}@sha256:${image_sha}"
                    log_info "Using SHA-pinned image: ${IMAGE_TO_USE}"
                else
                    IMAGE_TO_USE="${DEFAULT_IMAGE_REPOSITORY}:${image_tag}"
                    log_warn "No SHA pin available for ${image_tag}, using tag only"
                fi
                ;;
            *)
                # Specific version tag, use without SHA
                IMAGE_TO_USE="${DEFAULT_IMAGE_REPOSITORY}:${image_tag}"
                log_info "Using specific version: ${IMAGE_TO_USE}"
                ;;
        esac
    else
        # Use default from config (with SHA pinning)
        IMAGE_TO_USE="${DEFAULT_IMAGE}"
        log_info "Using default SHA-pinned image: ${IMAGE_TO_USE}"
    fi
}

# Resolve and validate content path
function resolve_content_path() {
    local content_path="${GITHUB_WORKSPACE}/${INPUT_PATH}"

    debug_log "Resolving content path: ${content_path}"

    if [[ -f "$content_path" ]]; then
        MOUNT_DIR=$(dirname "$content_path")
        CONTENT_NAME=$(basename "$content_path")
        log_info "Mounting file's parent directory: ${MOUNT_DIR}"
    elif [[ -d "$content_path" ]]; then
        MOUNT_DIR="$content_path"
        CONTENT_NAME="."
        log_info "Mounting directory: ${MOUNT_DIR}"
    else
        log_error "Path '${INPUT_PATH}' does not exist in workspace"
        return 1
    fi

    # Ensure the mounted directory is writable
    # Container runs as md2conf user (UID 1000)
    debug_log "Making directory writable for container user"
    chmod -R a+w "$MOUNT_DIR"

    return 0
}

# Execute md2conf via Docker
function execute_md2conf() {
    log_info "Executing md2conf"
    echo "::group::Executing md2conf"

    # Create temporary environment file for secrets
    ENV_FILE=$(mktemp)
    debug_log "Created temporary environment file: ${ENV_FILE}"

    echo "CONFLUENCE_API_KEY=${INPUT_API_KEY}" >> "$ENV_FILE"

    # Build Docker run arguments
    local -a docker_args=(
        --rm
        -v "${MOUNT_DIR}:/data"
        --workdir /data
        --env-file "${ENV_FILE}"
        "${IMAGE_TO_USE}"
        "${CONTENT_NAME}"
    )

    # Append md2conf arguments
    docker_args+=("${ARGS[@]}")

    debug_log "Executing: docker run [${#docker_args[@]} args]"

    # Execute Docker
    docker run "${docker_args[@]}"

    echo "::endgroup::"
    log_info "md2conf execution completed successfully"
}

# Main execution
function main() {
    debug_log "Starting md2conf execution script"

    # Validate inputs
    if ! validate_inputs; then
        exit 1
    fi

    # Load configuration
    if ! load_config; then
        exit 1
    fi

    # Build arguments
    build_args

    # Determine Docker image
    determine_image

    # Resolve content path
    if ! resolve_content_path; then
        exit 1
    fi

    # Execute md2conf
    execute_md2conf
}

# Run main function
main
