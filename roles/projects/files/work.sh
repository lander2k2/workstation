#!/bin/bash

set -e

# Default values
BASE_BRANCH="main"
WORKSPACE_FILE_ONLY=false
FORCE=false

# Function to display help information
show_help() {
    cat << EOF
Usage: work.sh [OPTIONS] COMMAND PROJECT_ABBREV REPO_PATH

Manage project setup and teardown toil when working on source code.
Manages a workspace file for Cursor and git branches in a git worktree format.

COMMANDS:
    add       Create a new git worktree and workspace file
    remove    Remove git worktree and workspace file

ARGUMENTS:
    PROJECT_ABBREV  Arbitrary string for project abbreviation
    REPO_PATH       Repository path in format: service/org/repo/branch
                    Example: github.com/lander2k2/threeport/feature-x

OPTIONS:
    -b, --base-branch BRANCH       Base branch name (default: main)
    -w, --workspace-file-only      Only create the workspace file, skip git worktree creation
    -f, --force                    Pass --force to 'git worktree remove' (remove command only)
    -h, --help                     Show this help message

EXAMPLES:
    work.sh add tpt github.com/lander2k2/threeport/feature-y
    work.sh remove tpt github.com/lander2k2/threeport/feature-y
    work.sh add tpt github.com/lander2k2/threeport/feature-y --base-branch develop
    work.sh add tpt github.com/lander2k2/threeport/feature-y --workspace-file-only
    work.sh remove tpt github.com/lander2k2/threeport/feature-y --force

EXIT CODES:
    0    Success
    1    Error occurred
EOF
}

# Function to log errors and exit
error_exit() {
    echo "Error: $1" >&2
    exit 1
}

# Function to validate repo path format
validate_repo_path() {
    local repo_path="$1"
    local path_parts
    IFS='/' read -ra path_parts <<< "$repo_path"

    if [ ${#path_parts[@]} -lt 4 ]; then
        error_exit "Repository path must have at least 4 elements separated by '/'. Got: $repo_path"
    fi
}

# Function to extract components from repo path
extract_repo_components() {
    local repo_path="$1"
    local path_parts
    local branch_parts
    IFS='/' read -ra path_parts <<< "$repo_path"

    SERVICE="${path_parts[0]}"
    ORG="${path_parts[1]}"
    REPO="${path_parts[2]}"
    branch_parts=("${path_parts[@]:3}")
    BRANCH=$(IFS='/'; echo "${branch_parts[*]}")
    BRANCH_FS_SAFE="${BRANCH//\//_}"

    # Build paths
    BASE_BRANCH_DIR="src/$SERVICE/$ORG/$REPO/$BASE_BRANCH"
    BRANCH_DIR="src/$SERVICE/$ORG/$REPO/$BRANCH_FS_SAFE"
    LEGACY_BRANCH_DIR="src/$SERVICE/$ORG/$REPO/$BRANCH"
    BRANCH_WORKTREE_PATH="../$BRANCH_FS_SAFE"
}

# Resolve filesystem path of the worktree for BRANCH (refs/heads/$BRANCH).
# Uses git's registration so paths stay correct when branch names contain '/'
# but on-disk folders use BRANCH_FS_SAFE or legacy nested paths.
resolve_worktree_path_for_branch() {
    local target_ref="refs/heads/$BRANCH"
    local wt_path=""
    local candidate_path=""
    while IFS= read -r line; do
        if [[ $line == worktree\ * ]]; then
            candidate_path="${line#worktree }"
        elif [[ $line == branch\ * ]]; then
            local ref="${line#branch }"
            if [[ "$ref" == "$target_ref" ]]; then
                wt_path="$candidate_path"
                break
            fi
        fi
    done < <(git -C "$BASE_BRANCH_DIR" worktree list --porcelain 2>/dev/null)

    if [[ -z "$wt_path" ]]; then
        if [[ -d "$BRANCH_DIR" ]]; then
            wt_path="$(cd "$BRANCH_DIR" && pwd)"
        elif [[ -d "$LEGACY_BRANCH_DIR" ]]; then
            wt_path="$(cd "$LEGACY_BRANCH_DIR" && pwd)"
        fi
    fi

    printf '%s' "$wt_path"
}

# Function to create workspace file content
create_workspace_content() {
    local branch_directory="$1"
    cat << EOF
{
    "folders": [
        {
            "path": "$branch_directory"
        }
    ],
    "settings": {
        "files.associations": {
            "dockerfile.go": "go",
            "*.go.bak": "go"
        }
    }
}
EOF
}

# Function to handle 'add' command
cmd_add() {
    local project_abbrev="$1"
    local repo_path="$2"

    validate_repo_path "$repo_path"
    extract_repo_components "$repo_path"

    if [ "$WORKSPACE_FILE_ONLY" = false ]; then
        # Check if base branch directory exists
        if [ ! -d "$BASE_BRANCH_DIR" ]; then
            error_exit "Base branch directory does not exist: $BASE_BRANCH_DIR"
        fi

        # Create branch directory if it doesn't exist
        if [ ! -d "$BRANCH_DIR" ]; then
            mkdir -p "$BRANCH_DIR"
        fi

        # Change to base branch directory and create branch + worktree
        cd "$BASE_BRANCH_DIR"

        # Create branch (ignore error if it already exists)
        git branch "$BRANCH" 2>/dev/null || true

        # Create worktree
        if ! git worktree add "$BRANCH_WORKTREE_PATH" "$BRANCH"; then
            error_exit "Failed to create git worktree for branch: $BRANCH"
        fi

        # Return to original directory
        cd - > /dev/null
    else
        # In workspace-file-only mode, just check if branch directory exists
        if [ ! -d "$BRANCH_DIR" ]; then
            error_exit "Branch directory does not exist: $BRANCH_DIR (use without --workspace-file-only to create it)"
        fi
    fi

    # Create workspace file
    local workspace_content
    workspace_content=$(create_workspace_content "$BRANCH_DIR")

    local x_workspace="x-$project_abbrev-$BRANCH_FS_SAFE.code-workspace"

    echo "$workspace_content" > "$x_workspace"

    if [ "$WORKSPACE_FILE_ONLY" = false ]; then
        echo "Successfully created worktree and workspace file for branch: $BRANCH"
    else
        echo "Successfully created workspace file for existing branch: $BRANCH"
    fi
    echo "Created workspace file: $x_workspace"
}

# Function to handle 'remove' command
cmd_remove() {
    local project_abbrev="$1"
    local repo_path="$2"

    validate_repo_path "$repo_path"
    extract_repo_components "$repo_path"

    # Check if base branch directory exists
    if [ ! -d "$BASE_BRANCH_DIR" ]; then
        error_exit "Base branch directory does not exist: $BASE_BRANCH_DIR"
    fi

    local worktree_path
    worktree_path=$(resolve_worktree_path_for_branch)
    if [ -z "$worktree_path" ]; then
        error_exit "No worktree found for branch: $BRANCH (not registered in git and no directory at $BRANCH_DIR or $LEGACY_BRANCH_DIR)"
    fi

    local force_args=()
    if [ "$FORCE" = true ]; then
        force_args+=("--force")
    fi

    if ! git -C "$BASE_BRANCH_DIR" worktree remove "${force_args[@]}" "$worktree_path"; then
        error_exit "Failed to remove git worktree for branch: $BRANCH (path: $worktree_path)"
    fi

    # Delete the branch (use actual branch name, including any '/' characters)
    if ! git -C "$BASE_BRANCH_DIR" branch -D "$BRANCH"; then
        error_exit "Failed to delete branch: $BRANCH"
    fi

    # Remove workspace file
    local x_workspace="x-$project_abbrev-$BRANCH_FS_SAFE.code-workspace"

    if [ -f "$x_workspace" ]; then
        rm "$x_workspace"
    fi

    echo "Successfully removed worktree and workspace file for branch: $BRANCH"
    echo "Removed workspace file: $x_workspace"
}

# Parse command line arguments - collect positional args separately
POSITIONAL_ARGS=()
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -b|--base-branch)
            if [ -z "$2" ]; then
                error_exit "Option --base-branch requires a value"
            fi
            BASE_BRANCH="$2"
            shift 2
            ;;
        -w|--workspace-file-only)
            WORKSPACE_FILE_ONLY=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -*)
            error_exit "Unknown option: $1"
            ;;
        *)
            # Collect positional arguments
            POSITIONAL_ARGS+=("$1")
            shift
            ;;
    esac
done

# Parse positional arguments
if [ ${#POSITIONAL_ARGS[@]} -ge 1 ]; then
    COMMAND="${POSITIONAL_ARGS[0]}"
fi

if [ ${#POSITIONAL_ARGS[@]} -ge 2 ]; then
    PROJECT_ABBREV="${POSITIONAL_ARGS[1]}"
fi

if [ ${#POSITIONAL_ARGS[@]} -ge 3 ]; then
    REPO_PATH="${POSITIONAL_ARGS[2]}"
fi

# Validate required arguments
if [ -z "$COMMAND" ]; then
    error_exit "Command (add or remove) is required. Use --help for usage information."
fi

if [ ${#POSITIONAL_ARGS[@]} -lt 3 ]; then
    error_exit "PROJECT_ABBREV and REPO_PATH arguments are required. Use --help for usage information."
fi

# Validate command
if [ "$COMMAND" != "add" ] && [ "$COMMAND" != "remove" ]; then
    error_exit "Command must be either 'add' or 'remove'"
fi

# Execute command
case $COMMAND in
    add)
        cmd_add "$PROJECT_ABBREV" "$REPO_PATH"
        ;;
    remove)
        cmd_remove "$PROJECT_ABBREV" "$REPO_PATH"
        ;;
esac

exit 0

