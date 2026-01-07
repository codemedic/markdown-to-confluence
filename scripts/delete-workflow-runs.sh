#!/bin/bash
set -euo pipefail

## Delete Workflow Runs - Deletes workflow runs for a specific workflow or all workflows
##
## Usage:
##   ./delete-workflow-runs.sh [options]
##
## Options:
##   -w, --workflow <name>  Workflow file name or ID (e.g., '.github/workflows/checks.yml')
##                          If omitted, all workflows in the repository will be processed.
##   -k, --keep <num>       Number of recent runs to keep for each workflow (default: 1)
##   -p, --parallel <num>   Number of parallel processes (default: 1)
##   -r, --repo <owner/repo> Target repository (default: discovered from git remote)
##   -h, --help             Show this help message

# Source shared functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || exit 1
source "${SCRIPT_DIR}/functions.sh"

get_target_repo() {
    local repo
    repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true)

    if [[ -z "$repo" ]]; then
        local push_url
        push_url=$(git remote -v | grep '(push)' | awk 'NR==1 {print $2}' || true)

        if [[ -n "$push_url" ]]; then
            repo=$(echo "$push_url" | sed -n -e 's/.*github\.com[:/]\(.*\)\.git/\1/p')
        fi
    fi

    if [[ -z "$repo" ]]; then
        log_error "Could not determine repository name. Please use -r or --repo."
        exit 1
    fi
    echo "$repo"
}

delete_runs_for_workflow() {
    local workflow="$1"
    local keep="$2"
    local parallel_procs="$3"
    local target_repo="$4"

    log_info "Processing workflow: $workflow (keeping last $keep runs)"

    local run_ids
    # gh run list returns newest first
    run_ids=$(gh run list --workflow "$workflow" --repo "$target_repo" --limit 1000 --json databaseId --jq '.[].databaseId')

    if [[ -z "$run_ids" ]]; then
        log_info "No workflow runs found for: $workflow"
        return 0
    fi

    local total_count
    total_count=$(echo "$run_ids" | wc -l | tr -d ' ')

    # Extract IDs to delete: skip the first 'keep' lines
    local to_delete
    to_delete=$(echo "$run_ids" | tail -n +"$((keep + 1))")

    if [[ -z "$to_delete" ]]; then
        log_info "No runs to delete for $workflow (Total: $total_count, Keeping: $keep)"
        return 0
    fi

    local delete_count
    delete_count=$(echo "$to_delete" | wc -l | tr -d ' ')
    log_info "Found $total_count run(s). Deleting $delete_count run(s) with $parallel_procs parallel process(es)..."
    echo "$to_delete" | xargs -I {} -P "$parallel_procs" gh run delete {} --repo "$target_repo"
}

main() {
    local workflow=""
    local keep=1
    local parallel="1"
    local repo=""

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -w|--workflow) workflow="$2"; shift ;;
            -k|--keep)     keep="$2";     shift ;;
            -p|--parallel) parallel="$2"; shift ;;
            -r|--repo)     repo="$2";     shift ;;
            -h|--help)    usage; exit 0 ;;
            *)            log_error "Unknown option: $1"; usage; exit 1 ;;
        esac
        shift
    done

    validate_dependencies "gh" "jq"

    if [[ -z "$repo" ]]; then
        repo=$(get_target_repo)
    fi
    log_info "Targeting repository: $repo"

    if [[ -n "$workflow" ]]; then
        delete_runs_for_workflow "$workflow" "$keep" "$parallel" "$repo"
    else
        log_info "No workflow specified. Discovering all workflows..."
        local workflows
        workflows=$(gh workflow list --repo "$repo" --json path --jq '.[].path')

        if [[ -z "$workflows" ]]; then
            log_warn "No workflows found in $repo"
            return 0
        fi

        while read -r wf; do
            delete_runs_for_workflow "$wf" "$keep" "$parallel" "$repo"
        done <<< "$workflows"
    fi

    log_info "All deletion requests have been submitted."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
