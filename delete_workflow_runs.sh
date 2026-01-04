#!/bin/bash

# Deletes all workflow runs for a given workflow file in the current repository.
#
# Usage: ./delete_workflow_runs.sh <workflow_file_name> [parallel_procs]
# Example: ./delete_workflow_runs.sh '.github/workflows/checks.yml' 4

set -euo pipefail

check_dependencies() {
    if ! command -v jq &> /dev/null; then
        echo "Error: 'jq' is not installed. Please install it to continue." >&2
        exit 1
    fi
}

get_target_repo() {
    local push_url
    push_url=$(git remote -v | grep '(push)' | awk 'NR==1 {print $2}')

    if [[ -z "$push_url" ]]; then
        echo "Error: Could not find a git remote with a push URL." >&2
        exit 1
    fi

    local repo
    repo=$(echo "$push_url" | sed -n -e 's/.*github\.com[:/]\(.*\)\.git/\1/p')

    if [[ -z "$repo" ]]; then
        echo "Error: Could not parse repository name from push URL: $push_url" >&2
        exit 1
    fi
    echo "$repo"
}

delete_runs() {
    local workflow_name="$1"
    local parallel_procs="$2"
    local target_repo="$3"

    echo "Fetching workflow runs for: $workflow_name"
    local run_ids
    run_ids=$(gh run list --workflow "$workflow_name" --repo "$target_repo" --json databaseId --jq '.[].databaseId')

    if [[ -z "$run_ids" ]]; then
        echo "No workflow runs found to delete."
        return 0
    fi

    echo "Found runs. Deleting with $parallel_procs parallel process(es)..."
    echo "$run_ids" | xargs -I {} -P "$parallel_procs" gh run delete {} --repo "$target_repo"
}

main() {
    local workflow_name="${1:-}"
    local parallel_procs="${2:-1}"

    if [[ -z "$workflow_name" ]]; then
        echo "Error: Workflow name is required." >&2
        echo "Usage: $0 <workflow_file_name> [parallel_procs]" >&2
        exit 1
    fi

    check_dependencies

    local target_repo
    target_repo=$(get_target_repo)
    echo "Targeting repository: $target_repo"

    delete_runs "$workflow_name" "$parallel_procs" "$target_repo"
    echo "All deletion requests have been submitted."
}

main "$@"
