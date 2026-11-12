#!/usr/bin/env bash
# scenarios.sh — entry point for the git-scenarios practice script
#
# Usage:
#   bash scenarios.sh setup                            # build 7 scenarios in the current repo
#   bash scenarios.sh setup --local [dir] [--rebuild]  # build in ~/practice with a bare origin
#   bash scenarios.sh add <stack|lease|backport>
#   bash scenarios.sh list
#   bash scenarios.sh reset <id|all>
#   bash scenarios.sh graph <id>
#   bash scenarios.sh demo <merge|rebase|conflict|pick|all>
#
# bash 3.2+ and bash 5 compatible. set -euo pipefail is used throughout.
# The script keeps its own state inside the repo's .git directory only.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

# Source all scenario files (0N-name.sh; demo.sh)
for _sf in "$SCRIPT_DIR/scenarios"/[0-9]*.sh "$SCRIPT_DIR/scenarios/demo.sh"; do
    # shellcheck disable=SC1090
    . "$_sf"
done
unset _sf

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

usage() {
    printf 'Usage:\n'
    printf '  bash ~/gs/scenarios.sh setup                 # build 7 scenarios in this repo\n'
    printf '  bash ~/gs/scenarios.sh setup --local [dir]   # local mode in ~/practice (no GitHub)\n'
    printf '  bash ~/gs/scenarios.sh add <stack|lease|backport>\n'
    printf '  bash ~/gs/scenarios.sh list\n'
    printf '  bash ~/gs/scenarios.sh reset <id|all>\n'
    printf '  bash ~/gs/scenarios.sh graph <id>\n'
    printf '  bash ~/gs/scenarios.sh demo <merge|rebase|conflict|pick|all>\n'
}

# ---------------------------------------------------------------------------
# cmd_list
# ---------------------------------------------------------------------------
cmd_list() {
    git rev-parse --git-dir >/dev/null 2>&1 || \
        die "not a git repository; cd to your practice repo first"
    local id status
    printf '%-9s %-53s %s\n' "id" "goal" "status"
    printf '%s\n' "------------------------------------------------------------------------"
    for id in $ALL_IDS; do
        if scenario_is_built "$id"; then
            status="built"
        else
            status="not built"
        fi
        printf '%-9s %-53s %s\n' "$id" "$(scenario_goal "$id")" "$status"
    done
}

# ---------------------------------------------------------------------------
# Build and push the seven default scenarios (setup and setup --local)
# ---------------------------------------------------------------------------
_build_default_scenarios() {
    build_scenario_buttons
    build_scenario_behind
    build_scenario_clash
    build_scenario_replay
    build_scenario_hotfix
    build_scenario_diverge
    build_scenario_oops

    printf 'Pushing branches...\n'
    push_branches \
        buttons-main buttons-login buttons-search buttons-help \
        behind-main behind-feature \
        clash-main clash-feature \
        replay-main replay-feature \
        hotfix-release hotfix-main \
        diverge-main \
        oops-main

    # diverge-main went up with all 3 commits; now set up the local diverge state
    finalize_diverge
}

# One note when the Codespace's git already decides how git pull reconciles
_pull_rebase_note() {
    local v
    v=$(git config --get pull.rebase 2>/dev/null) || v=""
    if [ -n "$v" ]; then
        printf 'Note: pull.rebase is set to %s in this git, so git pull in Step 6 does not stop to ask.\n' "$v"
    fi
    return 0
}

# Local identity only when none is configured
_ensure_identity() {
    local cfg_name cfg_email
    cfg_name=$(git config user.name 2>/dev/null) || cfg_name=""
    cfg_email=$(git config user.email 2>/dev/null) || cfg_email=""
    if [ -z "$cfg_name" ] || [ -z "$cfg_email" ]; then
        [ -n "$cfg_name" ]  || git config user.name "Student"
        [ -n "$cfg_email" ] || git config user.email "student@example.com"
        printf 'Set local git identity (user.name / user.email).\n'
    fi
    return 0
}

# ---------------------------------------------------------------------------
# _do_setup: build all 7 default scenarios (called after safety checks pass)
# ---------------------------------------------------------------------------
_do_setup() {
    printf 'Setting up...\n'

    git config core.pager cat
    _ensure_identity
    printf 'Set core.pager=cat.\n'

    init_default_branch
    # From here on an interruption leaves this file: the next setup cleans up
    printf '%s\n' "$DEFAULT_BRANCH" > "$(started_path)"
    # shellcheck disable=SC2034  # read in lib.sh
    LOCAL_MODE=0
    init_base
    check_gh
    parse_origin || true
    reset_pr_tracking

    _build_default_scenarios

    # Create pull requests (6 total)
    printf 'Opening pull requests...\n'
    create_prs_buttons   # 3 PRs: buttons-login, search, help
    create_prs_behind    # 1 PR: behind-feature
    create_prs_clash     # 1 PR: clash-feature
    create_prs_replay    # 1 PR: replay-feature

    # Marker (inside .git) with the default branch name so add/reset find it
    printf '%s\n' "$DEFAULT_BRANCH" > "$(marker_path)"
    rm -f "$(started_path)"

    _pull_rebase_note
    print_ready 7 0
}

# ---------------------------------------------------------------------------
# cmd_setup: normal mode (run in the student's existing repo)
# ---------------------------------------------------------------------------
cmd_setup() {
    if [ "$#" -gt 0 ]; then
        case "$1" in
            --rebuild) die "--rebuild works only with --local: bash ~/gs/scenarios.sh setup --local --rebuild" ;;
            *)         die "unknown option '$1'; run: bash ~/gs/scenarios.sh setup" ;;
        esac
    fi

    safety_check

    if [ "$ALREADY_BUILT" -eq 1 ]; then
        printf 'Already set up.\n'
        cmd_list
        exit 0
    fi

    _do_setup
}

# ---------------------------------------------------------------------------
# cmd_setup_local: create a local bare repo as origin, then run setup
# ---------------------------------------------------------------------------
cmd_setup_local() {
    local base_dir="" rebuild=0 a
    for a in "$@"; do
        case "$a" in
            --rebuild) rebuild=1 ;;
            -*)        die "unknown option '$a'" ;;
            *)
                [ -z "$base_dir" ] || die "only one folder can be given (got '$base_dir' and '$a')"
                base_dir="$a"
                ;;
        esac
    done
    [ -n "$base_dir" ] || base_dir="$HOME/practice"
    case "$base_dir" in
        /*) ;;
        *)  base_dir="$PWD/$base_dir" ;;
    esac
    base_dir="${base_dir%/}"
    local origin_dir="${base_dir}-origin.git"
    local shown dir_arg=""
    shown=$(display_path "$base_dir")
    [ "$base_dir" = "$HOME/practice" ] || dir_arg=" $shown"

    if [ -e "$base_dir" ]; then
        if [ -f "$base_dir/.git/gs-built" ] || [ -f "$base_dir/.gs-built" ]; then
            if [ "$rebuild" -eq 0 ]; then
                printf 'Already set up in %s: cd %s and go on.\n' "$shown" "$shown" >&2
                printf 'To delete that folder with everything in it and build it again: bash ~/gs/scenarios.sh setup --local%s --rebuild\n' "$dir_arg" >&2
                exit 1
            fi
            printf 'Deleting %s and building it again.\n' "$shown"
        elif [ -f "$base_dir/.git/gs-setup-started" ]; then
            printf 'Found an unfinished setup, cleaning it up.\n'
        else
            die "'$shown' already exists and was not made by this script; remove it or name another folder: bash ~/gs/scenarios.sh setup --local ~/practice2"
        fi
        cd "$HOME" 2>/dev/null || cd /
        rm -rf "$base_dir" "$origin_dir"
    fi
    if [ -e "$origin_dir" ]; then
        if [ -f "$origin_dir/gs-origin" ]; then
            rm -rf "$origin_dir"
        else
            die "'$(display_path "$origin_dir")' already exists and was not made by this script; remove it or name another folder"
        fi
    fi

    printf 'Creating local practice repo at %s\n' "$shown"

    # Create bare origin
    mkdir -p "$origin_dir"
    git init --bare --quiet "$origin_dir"
    : > "$origin_dir/gs-origin"

    # Create practice repo
    mkdir -p "$base_dir"
    cd "$base_dir"
    git init --quiet
    git symbolic-ref HEAD refs/heads/main
    printf 'main\n' > "$(started_path)"

    # Point to the bare origin
    git remote add origin "$(cd "$origin_dir" && pwd)"

    git config core.pager cat
    local cfg_name cfg_email
    cfg_name=$(git config user.name 2>/dev/null) || cfg_name=""
    cfg_email=$(git config user.email 2>/dev/null) || cfg_email=""
    [ -n "$cfg_name" ]  || git config user.name "Student"
    [ -n "$cfg_email" ] || git config user.email "student@example.com"

    # Create the initial README commit
    printf '# git-practice\n\nPractice repository for git exercises.\n' > README.md
    git add README.md
    git --no-pager commit --quiet -m "Initial commit"
    git push --quiet -u origin main

    ALREADY_BUILT=0
    # shellcheck disable=SC2034  # read in lib.sh
    LOCAL_MODE=1
    init_default_branch
    init_base
    check_gh
    reset_pr_tracking

    printf 'Building scenarios...\n'
    _build_default_scenarios
    # No pull requests in local mode (no real GitHub remote)

    printf '%s\nlocal\n' "$DEFAULT_BRANCH" > "$(marker_path)"
    rm -f "$(started_path)"
    _pull_rebase_note
    print_ready 7 1 "$shown"
}

# ---------------------------------------------------------------------------
# cmd_add: build one on-demand scenario
# ---------------------------------------------------------------------------
cmd_add() {
    local id="${1:-}"
    case "$id" in
        stack|lease|backport) ;;
        *) die "usage: bash ~/gs/scenarios.sh add <stack|lease|backport>" ;;
    esac

    require_built

    if scenario_is_built "$id" && [ ! -f "$(building_path "$id")" ]; then
        printf '%s is already built.\n' "$id"
        printf 'next: git switch %s\n' "$(scenario_start_branch "$id")"
        exit 0
    fi

    # Build from the default branch, never from the branch the student is on
    if operation_in_progress; then
        die "finish or abort what you started (git rebase --abort, git merge --abort, git cherry-pick --abort), then run add again"
    fi
    if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
        die "you have uncommitted changes in this folder; commit them or run git stash, then run add again"
    fi
    cd "$(git rev-parse --show-toplevel)"
    git checkout --quiet "$DEFAULT_BRANCH" || \
        die "cannot switch to '$DEFAULT_BRANCH'; run 'git switch $DEFAULT_BRANCH', then add again"

    init_base
    check_gh
    parse_origin || true
    reset_pr_tracking

    if [ -f "$(building_path "$id")" ]; then
        printf 'Found an unfinished add, cleaning it up.\n'
        close_scenario_prs "$id"
        delete_scenario_branches "$id"
    fi

    : > "$(building_path "$id")"
    _build_one "$id"
    rm -f "$(building_path "$id")"

    printf '\n%s built.\n' "$id"
    if scenario_has_prs "$id"; then
        print_pr_result
    fi
    printf 'next: git switch %s\n' "$(scenario_start_branch "$id")"
}

# Build, push and open the pull requests of one scenario
_build_one() {
    case "$1" in
        buttons)
            build_scenario_buttons; push_scenario_buttons; create_prs_buttons ;;
        behind)
            build_scenario_behind; push_scenario_behind; create_prs_behind ;;
        clash)
            build_scenario_clash; push_scenario_clash; create_prs_clash ;;
        replay)
            build_scenario_replay; push_scenario_replay; create_prs_replay ;;
        hotfix)
            build_scenario_hotfix; push_scenario_hotfix; create_prs_hotfix ;;
        diverge)
            build_scenario_diverge; push_scenario_diverge; finalize_diverge ;;
        oops)
            build_scenario_oops; push_scenario_oops; create_prs_oops ;;
        stack)
            build_scenario_stack; push_scenario_stack; create_prs_stack ;;
        lease)
            build_scenario_lease; push_scenario_lease
            finalize_lease; create_prs_lease ;;
        backport)
            build_scenario_backport; push_scenario_backport; create_prs_backport ;;
    esac
    return 0
}

# ---------------------------------------------------------------------------
# cmd_reset: reset a scenario from any state (mid-rebase, mid-merge, dirty)
# ---------------------------------------------------------------------------
cmd_reset() {
    local id="${1:-}" s
    [ -n "$id" ] || die "usage: bash ~/gs/scenarios.sh reset <id|all>"

    # Validate everything BEFORE anything is discarded
    if [ "$id" != "all" ] && ! is_known_id "$id"; then
        die "unknown scenario '$id'; the ids are: $ALL_IDS (or all)"
    fi
    require_built
    if [ "$id" != "all" ] && ! scenario_is_built "$id" && [ ! -f "$(building_path "$id")" ]; then
        case "$id" in
            stack|lease|backport)
                die "scenario '$id' is not built; nothing to reset (build it with: bash ~/gs/scenarios.sh add $id)" ;;
            *)
                die "scenario '$id' is not built; nothing to reset" ;;
        esac
    fi

    cd "$(git rev-parse --show-toplevel)"
    printf 'Discarding uncommitted changes and untracked files in this folder.\n'
    abort_operations
    git reset --hard --quiet HEAD 2>/dev/null || true
    git clean -fdq 2>/dev/null || true

    # Return to the default branch (from the marker)
    git checkout --quiet "$DEFAULT_BRANCH" 2>/dev/null || \
        die "cannot switch to '$DEFAULT_BRANCH'; run 'git switch $DEFAULT_BRANCH', then reset again"

    init_base
    check_gh
    parse_origin || true

    if [ "$id" = "all" ]; then
        for s in $ALL_IDS; do
            if scenario_is_built "$s" || [ -f "$(building_path "$s")" ]; then
                _reset_one "$s"
            fi
        done
        printf '\nAll scenarios reset.\n'
        printf 'Reset complete. next: git switch buttons-main\n'
    else
        _reset_one "$id"
        printf '\nReset complete. next: git switch %s\n' "$(scenario_start_branch "$id")"
    fi
    return 0
}

_reset_one() {
    local id="$1"
    printf 'Resetting %s...\n' "$id"
    : > "$(building_path "$id")"
    reset_pr_tracking
    close_scenario_prs "$id"
    delete_scenario_branches "$id"
    _build_one "$id"
    rm -f "$(building_path "$id")"
    printf '%s: rebuilt.\n' "$id"
    if scenario_has_prs "$id"; then
        print_pr_result
    fi
    return 0
}

# ---------------------------------------------------------------------------
# cmd_graph: print the graph command and its output for a scenario
# ---------------------------------------------------------------------------
cmd_graph() {
    local id="${1:-}"
    [ -n "$id" ] || die "usage: bash ~/gs/scenarios.sh graph <id>"
    is_known_id "$id" || die "unknown scenario '$id'; the ids are: $ALL_IDS"
    git rev-parse --git-dir >/dev/null 2>&1 || \
        die "not a git repository; cd to your practice repo first"
    if ! scenario_is_built "$id"; then
        case "$id" in
            stack|lease|backport)
                die "scenario '$id' is not built (build it with: bash ~/gs/scenarios.sh add $id)" ;;
            *)
                die "scenario '$id' is not built (run: bash ~/gs/scenarios.sh setup)" ;;
        esac
    fi
    local branches="" b existing=""
    case "$id" in
        buttons)  branches="buttons-main buttons-login buttons-search buttons-help" ;;
        behind)   branches="behind-main behind-feature" ;;
        clash)    branches="clash-main clash-feature" ;;
        replay)   branches="replay-main replay-feature" ;;
        hotfix)   branches="hotfix-release hotfix-main" ;;
        diverge)  branches="diverge-main" ;;
        oops)     branches="oops-main" ;;
        stack)    branches="stack-main stack-a stack-b" ;;
        lease)    branches="lease-main lease-feature" ;;
        backport) branches="backport-main backport-release" ;;
    esac
    # Each local branch and its origin copy; skip refs that do not exist
    for b in $branches; do
        git rev-parse --verify --quiet "refs/heads/$b" >/dev/null 2>&1 && existing="$existing $b"
    done
    for b in $branches; do
        git rev-parse --verify --quiet "refs/remotes/origin/$b" >/dev/null 2>&1 && existing="$existing origin/$b"
    done
    printf 'git --no-pager log --graph --oneline --decorate%s\n' "$existing"
    # shellcheck disable=SC2086
    git --no-pager log --graph --oneline --decorate $existing
}

# ---------------------------------------------------------------------------
# cmd_demo: build one or all instructor demo repos
# ---------------------------------------------------------------------------
cmd_demo() {
    local name="${1:-}"
    case "$name" in
        merge)    build_demo_merge ;;
        rebase)   build_demo_rebase ;;
        conflict) build_demo_conflict ;;
        pick)     build_demo_pick ;;
        all)
            build_demo_merge
            build_demo_rebase
            build_demo_conflict
            build_demo_pick
            ;;
        *) die "usage: bash ~/gs/scenarios.sh demo <merge|rebase|conflict|pick|all>" ;;
    esac
}

# ---------------------------------------------------------------------------
# Main dispatcher
# ---------------------------------------------------------------------------
CMD="${1:-}"
shift 2>/dev/null || true

case "$CMD" in
    setup)
        if [ "${1:-}" = "--local" ]; then
            shift
            cmd_setup_local "$@"
        else
            cmd_setup "$@"
        fi
        ;;
    add)    cmd_add "${1:-}" ;;
    list)   cmd_list ;;
    reset)  cmd_reset "${1:-}" ;;
    graph)  cmd_graph "${1:-}" ;;
    demo)   cmd_demo "${1:-}" ;;
    help|-h|--help) usage; exit 0 ;;
    *)      usage; exit 1 ;;
esac
