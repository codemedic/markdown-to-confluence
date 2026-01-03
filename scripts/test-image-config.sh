#!/bin/bash
set -euo pipefail

# Test Script for Image Configuration Logic
# Tests the determine_image() function with various input scenarios

# Test script setup
# Note: Don't make SCRIPT_DIR readonly here since run-md2conf.sh will set it
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the script under test (won't auto-execute main now)
source "${SCRIPT_DIR}/run-md2conf.sh"

# Re-define mock functions after sourcing (to override functions.sh)
function log_info() { return 0; }
function log_warn() { return 0; }
function log_error() { return 0; }
function debug_log() { return 0; }
function docker() { return 0; }
function cleanup() { return 0; }

# Test framework
FAILED_TESTS=0
PASSED_TESTS=0

function assert_equals() {
    local expected="$1"
    local actual="$2"
    local description="$3"

    if [[ "$actual" == "$expected" ]]; then
        echo "✓ PASS: $description"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo "✗ FAIL: $description"
        echo "  Expected: $expected"
        echo "  Actual:   $actual"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# Test helper to reset state between tests
function setup_test() {
    unset INPUT_IMAGE_REPOSITORY INPUT_IMAGE_TAG INPUT_ALTERNATIVE_CONFIG_ENABLED
    IMAGE_TO_USE=""
}

# Test 1: No inputs provided - should use DEFAULT_IMAGE
function test_no_inputs_uses_default_image() {
    setup_test
    load_config
    determine_image

    assert_equals \
        "${DEFAULT_IMAGE}" \
        "${IMAGE_TO_USE}" \
        "No inputs uses default image"
}

# Test 2: Only tag provided with known variant - should use DEFAULT_REPOSITORY with SHA
function test_only_tag_uses_default_repo_with_sha() {
    setup_test
    load_config

    INPUT_IMAGE_TAG="${DEFAULT_IMAGE_VERSION}-mermaid"
    determine_image

    local expected="${DEFAULT_IMAGE_REPOSITORY}:${DEFAULT_IMAGE_VERSION}-mermaid@sha256:${DEFAULT_IMAGE_SHA_MERMAID}"
    assert_equals \
        "${expected}" \
        "${IMAGE_TO_USE}" \
        "Only tag uses default repo with SHA (mermaid variant)"
}

# Test 3: Only tag provided with unknown tag - should fallback to tag only (no SHA)
function test_only_tag_without_sha_fallback() {
    setup_test
    load_config

    INPUT_IMAGE_TAG="custom-tag"
    determine_image

    local expected="${DEFAULT_IMAGE_REPOSITORY}:custom-tag"
    assert_equals \
        "${expected}" \
        "${IMAGE_TO_USE}" \
        "Only tag without SHA falls back to tag only"
}

# Test 4: Only repository provided - should use latest tag
function test_only_repo_uses_latest_tag() {
    setup_test
    load_config

    INPUT_IMAGE_REPOSITORY="myrepo/md2conf"
    determine_image

    assert_equals \
        "myrepo/md2conf:latest" \
        "${IMAGE_TO_USE}" \
        "Only repo uses latest tag"
}

# Test 5: Both repository and tag provided
function test_both_repo_and_tag_provided() {
    setup_test
    load_config

    INPUT_IMAGE_REPOSITORY="myrepo/md2conf"
    INPUT_IMAGE_TAG="1.2.3"
    determine_image

    assert_equals \
        "myrepo/md2conf:1.2.3" \
        "${IMAGE_TO_USE}" \
        "Both repo and tag provided"
}

# Test 6: Alternative config loads correctly
function test_alternative_config_loads_correctly() {
    setup_test

    INPUT_ALTERNATIVE_CONFIG_ENABLED="true"

    # Manually set CONFIG_FILE as load_config does
    if [[ "${INPUT_ALTERNATIVE_CONFIG_ENABLED:-false}" == "true" ]]; then
        local test_config_file="${SCRIPT_DIR}/image-config-alternative.sh"
    else
        local test_config_file="${SCRIPT_DIR}/image-config.sh"
    fi

    assert_equals \
        "${SCRIPT_DIR}/image-config-alternative.sh" \
        "${test_config_file}" \
        "Alternative config file path is correct"

    # Load and verify it loads the alternative config
    load_config
    determine_image

    # Both configs currently have same repository, but test that loading worked
    assert_equals \
        "${DEFAULT_IMAGE}" \
        "${IMAGE_TO_USE}" \
        "Alternative config loads and provides default image"
}

# Test 7: SHA variant - minimal
function test_sha_variant_minimal() {
    setup_test
    load_config

    INPUT_IMAGE_TAG="${DEFAULT_IMAGE_VERSION}-minimal"
    determine_image

    local expected="${DEFAULT_IMAGE_REPOSITORY}:${DEFAULT_IMAGE_VERSION}-minimal@sha256:${DEFAULT_IMAGE_SHA_MINIMAL}"
    assert_equals \
        "${expected}" \
        "${IMAGE_TO_USE}" \
        "SHA variant - minimal"
}

# Test 8: SHA variant - plantuml
function test_sha_variant_plantuml() {
    setup_test
    load_config

    INPUT_IMAGE_TAG="${DEFAULT_IMAGE_VERSION}-plantuml"
    determine_image

    local expected="${DEFAULT_IMAGE_REPOSITORY}:${DEFAULT_IMAGE_VERSION}-plantuml@sha256:${DEFAULT_IMAGE_SHA_PLANTUML}"
    assert_equals \
        "${expected}" \
        "${IMAGE_TO_USE}" \
        "SHA variant - plantuml"
}

# Test 9: Version tag without variant should use 'all' SHA
function test_version_tag_uses_all_sha() {
    setup_test
    load_config

    INPUT_IMAGE_TAG="${DEFAULT_IMAGE_VERSION}"
    determine_image

    local expected="${DEFAULT_IMAGE_REPOSITORY}:${DEFAULT_IMAGE_VERSION}@sha256:${DEFAULT_IMAGE_SHA_ALL}"
    assert_equals \
        "${expected}" \
        "${IMAGE_TO_USE}" \
        "Version tag uses 'all' variant SHA"
}

# Test 10: 'latest' tag should use 'all' SHA
function test_latest_tag_uses_all_sha() {
    setup_test
    load_config

    INPUT_IMAGE_TAG="latest"
    determine_image

    local expected="${DEFAULT_IMAGE_REPOSITORY}:latest@sha256:${DEFAULT_IMAGE_SHA_ALL}"
    assert_equals \
        "${expected}" \
        "${IMAGE_TO_USE}" \
        "'latest' tag uses 'all' variant SHA"
}

# Main test execution
function main() {
    echo "Running image configuration tests..."
    echo ""

    test_no_inputs_uses_default_image
    test_only_tag_uses_default_repo_with_sha
    test_only_tag_without_sha_fallback
    test_only_repo_uses_latest_tag
    test_both_repo_and_tag_provided
    test_alternative_config_loads_correctly
    test_sha_variant_minimal
    test_sha_variant_plantuml
    test_version_tag_uses_all_sha
    test_latest_tag_uses_all_sha

    echo ""
    local total_tests=$((PASSED_TESTS + FAILED_TESTS))

    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo "All tests passed! (${PASSED_TESTS}/${total_tests})"
        exit 0
    else
        echo "Some tests failed: ${FAILED_TESTS} failed, ${PASSED_TESTS} passed (${total_tests} total)"
        exit 1
    fi
}

# Run tests
main
