#!/usr/bin/env bash
# scenarios.sh — entry point for the git-scenarios practice script
#
# Usage:
#   bash scenarios.sh setup                 # build 7 scenarios in the current repo
#   bash scenarios.sh setup --local [dir]  # build in ~/practice with a bare origin
#   bash scenarios.sh add <stack|lease|backport>
#   bash scenarios.sh list
#   bash scenarios.sh reset <id|all>
#   bash scenarios.sh graph <id>
#   bash scenarios.sh demo <merge|rebase|conflict|pick|all>
#
# bash 3.2+ and bash 5 compatible. set -euo pipefail is used throughout.

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
    printf '  bash scenarios.sh setup                # build 7 scenarios\n'
    printf '  bash scenarios.sh setup --local [dir] # local mode (bare repo as origin)\n'
    printf '  bash scenarios.sh add <stack|lease|backport>\n'
    printf '  bash scenarios.sh list\n'
    printf '  bash scenarios.sh reset <id|all>\n'
    printf '  bash scenarios.sh graph <id>\n'
    printf '  bash scenarios.sh demo <merge|rebase|conflict|pick|all>\n'
    exit 1
}

# ---------------------------------------------------------------------------
# cmd_list
# ---------------------------------------------------------------------------
cmd_list() {
    local all_ids="buttons behind clash replay hotfix diverge oops stack lease backport"
    printf '%-12s %-42s %s\n' "id" "goal" "status"
    printf '%s\n' "-----------------------------------------------------------------------"
    for id in $all_ids; do
        local status
        if scenario_is_built "$id"; then
            status="built"
        else
            status="not built"
        fi
        printf '%-12s %-42s %s\n' "$id" "$(scenario_goal "$id")" "$status"
    done
}

# ---------------------------------------------------------------------------
# _do_setup: build all 7 default scenarios (called after safety checks pass)
# ---------------------------------------------------------------------------
_do_setup() {
    printf 'Setting up...\n'

    # Local config
    git config core.pager cat
    local cfg_name cfg_email
    cfg_name=$(git config user.name 2>/dev/null) || cfg_name=""
    cfg_email=$(git config user.email 2>/dev/null) || cfg_email=""
    if [ -z "$cfg_name" ] || [ -z "$cfg_email" ]; then
        [ -z "$cfg_name" ]  && git config user.name "Student"
        [ -z "$cfg_email" ] && git config user.email "student@example.com"
        printf 'Set local git identity (user.name / user.email).\n'
    fi
    printf 'Set core.pager=cat.\n'

    init_default_branch
    init_root_ts
    check_gh
    parse_origin || true

    # Reset PR tracking
    PR_FAILED=0
    PR_LINKS_LIST=""

    # Build all 7 scenarios
    build_scenario_buttons
    build_scenario_behind
    build_scenario_clash
    build_scenario_replay
    build_scenario_hotfix
    build_scenario_diverge
    build_scenario_oops

    # Push all standard branches at once (except diverge which needs special handling)
    printf 'Pushing branches...\n'
    push_branches \
        buttons-main buttons-login buttons-search buttons-help \
        behind-main behind-feature \
        clash-main clash-feature \
        replay-main replay-feature \
        hotfix-release hotfix-main \
        oops-main

    # Push diverge-main (all 3 commits), then set up the local diverge state
    push_branches diverge-main
    finalize_diverge

    # Create pull requests (6 total)
    printf 'Opening pull requests...\n'
    create_prs_buttons   # 3 PRs: buttons-login, search, help
    create_prs_behind    # 1 PR: behind-feature
    create_prs_clash     # 1 PR: clash-feature
    create_prs_replay    # 1 PR: replay-feature

    # Leave a marker with the default branch name so reset can find it
    printf '%s\n' "$DEFAULT_BRANCH" > "$MARKER_FILE"

    # Print the READY block (at most 8 lines)
    print_ready 7 6
}

# ---------------------------------------------------------------------------
# cmd_setup: normal mode (run in the student's existing repo)
# ---------------------------------------------------------------------------
cmd_setup() {
    safety_check

    if [ "$ALREADY_BUILT" -eq 1 ]; then
        printf 'Already set up. '
        cmd_list
        exit 0
    fi

    _do_setup
}

# ---------------------------------------------------------------------------
# cmd_setup_local: create a local bare repo as origin, then run setup
# ---------------------------------------------------------------------------
cmd_setup_local() {
    local base_dir="${1:-$HOME/practice}"
    local origin_dir="${base_dir}-origin.git"

    # Safety: refuse an existing dir not created by us
    if [ -d "$base_dir" ]; then
        if [ -f "$base_dir/$MARKER_FILE" ]; then
            printf 'Rebuilding %s...\n' "$base_dir"
            rm -rf "$base_dir" "$origin_dir"
        else
            die "directory '$base_dir' already exists and was not created by this script; remove it or choose a different path"
        fi
    fi

    printf 'Creating local practice repo at %s\n' "$base_dir"

    # Create bare origin
    mkdir -p "$origin_dir"
    git init --bare --quiet "$origin_dir"

    # Create practice repo
    mkdir -p "$base_dir"
    cd "$base_dir"

    git init --quiet
    # Try to rename default branch to main
    git checkout --quiet -b main 2>/dev/null || true

    # Point to the bare origin
    git remote add origin "$(cd "$origin_dir" && pwd)"

    # Set up local config
    git config core.pager cat
    local cfg_name cfg_email
    cfg_name=$(git config user.name 2>/dev/null) || cfg_name=""
    cfg_email=$(git config user.email 2>/dev/null) || cfg_email=""
    [ -z "$cfg_name" ]  && git config user.name "Student"
    [ -z "$cfg_email" ] && git config user.email "student@example.com"

    # Create the initial README commit
    printf '# git-practice\n\nPractice repository for git exercises.\n' > README.md
    git add README.md
    git --no-pager commit --quiet -m "Initial commit"
    git push --quiet -u origin main

    # Run setup
    ALREADY_BUILT=0
    init_default_branch
    init_root_ts
    check_gh
    # gh pr create won't work without a real GitHub origin; mark gh unavailable
    # shellcheck disable=SC2034
    GH_AVAILABLE=0
    PR_FAILED=0
    PR_LINKS_LIST=""

    printf 'Building scenarios...\n'
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
        oops-main

    push_branches diverge-main
    finalize_diverge

    # No pull requests in local mode (no real GitHub remote)
    PR_FAILED=1
    PR_LINKS_LIST=""

    printf '%s\n' "$DEFAULT_BRANCH" > "$MARKER_FILE"
    print_ready 7 0 1
}

# ---------------------------------------------------------------------------
# cmd_add: build one on-demand scenario
# ---------------------------------------------------------------------------
cmd_add() {
    local id="${1:-}"
    case "$id" in
        stack|lease|backport) ;;
        *) die "usage: scenarios.sh add <stack|lease|backport>" ;;
    esac

    safety_check
    if [ "$ALREADY_BUILT" -eq 0 ]; then
        die "run 'scenarios.sh setup' first"
    fi

    if scenario_is_built "$id"; then
        printf '%s is already built.\n' "$id"
        exit 0
    fi

    # Idempotence: re-read state
    init_default_branch
    init_root_ts
    check_gh
    parse_origin || true
    PR_FAILED=0
    PR_LINKS_LIST=""

    case "$id" in
        stack)
            build_scenario_stack
            push_scenario_stack
            create_prs_stack
            ;;
        lease)
            build_scenario_lease
            push_scenario_lease
            finalize_lease
            create_prs_lease
            ;;
        backport)
            build_scenario_backport
            push_scenario_backport
            create_prs_backport
            ;;
    esac

    printf '\n%s built.\n' "$id"
    printf 'next: git switch %s-main\n' "$id"
}

# ---------------------------------------------------------------------------
# cmd_reset: reset a scenario from any state (mid-rebase, mid-merge, dirty)
# ---------------------------------------------------------------------------
cmd_reset() {
    local id="${1:-}"
    [ -z "$id" ] && die "usage: scenarios.sh reset <id|all>"

    # Abort any in-progress operation (ignore errors)
    git rebase --abort 2>/dev/null || true
    git merge --abort 2>/dev/null || true
    git cherry-pick --abort 2>/dev/null || true
    git revert --abort 2>/dev/null || true

    # Discard uncommitted changes and untracked files (preserve the .gs-built marker)
    git reset --hard HEAD 2>/dev/null || true
    git clean -fd --exclude="$MARKER_FILE" 2>/dev/null || true

    # Return to default branch (read from marker so we know the real default
    # even when we are currently on a scenario branch)
    local db
    db=$(head -1 "$MARKER_FILE" 2>/dev/null) || db=""
    [ -z "$db" ] && db=$(git symbolic-ref --short HEAD 2>/dev/null) || true
    [ -z "$db" ] && db="main"
    git checkout "$db" --quiet 2>/dev/null || true

    init_root_ts
    init_default_branch
    check_gh
    parse_origin || true

    if [ "$id" = "all" ]; then
        for s in buttons behind clash replay hotfix diverge oops stack lease backport; do
            scenario_is_built "$s" && _reset_one "$s" || true
        done
        printf 'All scenarios reset.\n'
    else
        scenario_is_built "$id" || die "scenario '$id' is not built; nothing to reset"
        _reset_one "$id"
        printf '\nReset complete. next: git switch %s-main\n' "$id"
    fi
}

_reset_one() {
    local id="$1"
    printf 'Resetting %s...\n' "$id"
    close_scenario_prs "$id"
    delete_scenario_branches "$id"
    PR_FAILED=0
    PR_LINKS_LIST=""

    case "$id" in
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
            build_scenario_diverge
            push_branches diverge-main
            finalize_diverge
            ;;
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

    if [ "$PR_FAILED" -eq 0 ]; then
        printf '%s: rebuilt; pull requests opened with new numbers.\n' "$id"
    else
        printf '%s: rebuilt; pull requests not opened (gh unavailable or failed).\n' "$id"
        [ -n "$PR_LINKS_LIST" ] && printf '%s' "$PR_LINKS_LIST"
    fi
}

# ---------------------------------------------------------------------------
# cmd_graph: print the graph command and its output for a scenario
# ---------------------------------------------------------------------------
cmd_graph() {
    local id="${1:-}"
    [ -z "$id" ] && die "usage: scenarios.sh graph <id>"
    local branches=""
    case "$id" in
        buttons)
            branches="buttons-main buttons-login buttons-search buttons-help origin/buttons-main origin/buttons-login origin/buttons-search origin/buttons-help" ;;
        behind)
            branches="behind-main behind-feature origin/behind-main origin/behind-feature" ;;
        clash)
            branches="clash-main clash-feature origin/clash-main origin/clash-feature" ;;
        replay)
            branches="replay-main replay-feature origin/replay-main origin/replay-feature" ;;
        hotfix)
            branches="hotfix-release hotfix-main origin/hotfix-release origin/hotfix-main" ;;
        diverge)
            branches="diverge-main origin/diverge-main" ;;
        oops)
            branches="oops-main origin/oops-main" ;;
        stack)
            branches="stack-main stack-a stack-b origin/stack-main origin/stack-a origin/stack-b" ;;
        lease)
            branches="lease-main lease-feature origin/lease-main origin/lease-feature" ;;
        backport)
            branches="backport-main backport-release origin/backport-main origin/backport-release" ;;
        *)
            die "unknown scenario: $id" ;;
    esac
    # Filter out refs that don't exist to avoid git errors
    local existing=""
    for b in $branches; do
        git rev-parse --verify "$b" >/dev/null 2>&1 && existing="$existing $b"
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
        *) die "usage: scenarios.sh demo <merge|rebase|conflict|pick|all>" ;;
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
            cmd_setup_local "${1:-}"
        else
            cmd_setup
        fi
        ;;
    add)    cmd_add "${1:-}" ;;
    list)   cmd_list ;;
    reset)  cmd_reset "${1:-}" ;;
    graph)  cmd_graph "${1:-}" ;;
    demo)   cmd_demo "${1:-}" ;;
    "")     usage ;;
    *)      usage ;;
esac
