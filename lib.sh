#!/usr/bin/env bash
# lib.sh — shared helpers; sourced by scenarios.sh
# bash 3.2+ and bash 5 compatible. Never run directly.

# --- Fixed fake authors (no GitHub account) ---
# shellcheck disable=SC2034  # used in sourced scenario files
ALICE_NAME="Alice"; ALICE_EMAIL="alice@example.com"
# shellcheck disable=SC2034
BOB_NAME="Bob";     BOB_EMAIL="bob@example.com"
# shellcheck disable=SC2034
CAROL_NAME="Carol"; CAROL_EMAIL="carol@example.com"
# shellcheck disable=SC2034
DANA_NAME="Dana";   DANA_EMAIL="dana@example.com"

# --- Globals set by setup functions ---
# shellcheck disable=SC2034  # all globals below are set/read by sourced files
ROOT_TS=""        # Unix timestamp the scenario commits are dated from
BASE_SHA=""       # The README commit every scenario starts from
GH_OWNER=""       # Parsed from origin URL
GH_REPO=""        # Parsed from origin URL
DEFAULT_BRANCH="" # The repo's default branch (from the marker after setup)
LOCAL_MODE=0      # 1 when the repo was made by setup --local (no pull requests)
GH_AVAILABLE=0    # 1 if gh is on PATH
PR_FAILED=0       # 1 if any pr_create call failed
PR_OPENED=0       # Number of pull requests that opened (or already existed)
PR_NUMBERS=""     # " #7 #8" — numbers parsed from the URLs gh printed
PR_LINKS_LIST=""  # Compare links accumulated when gh fails (buttons only)
# shellcheck disable=SC2034
PR_LINKS_COUNT=0  # Number of buttons links accumulated
PR_BUTTONS_FAILED=0 # Number of buttons pull requests that did not open

# Branches built by setup (the seven default scenarios)
SETUP_BRANCHES="buttons-main buttons-login buttons-search buttons-help behind-main behind-feature clash-main clash-feature replay-main replay-feature hotfix-release hotfix-main diverge-main oops-main"
ALL_IDS="buttons behind clash replay hotfix diverge oops stack lease backport"

# Compare-link query parameter — smoke test verifies the actual form before class
# shellcheck disable=SC2034
COMPARE_LINK_PARAM="?quick_pull=1"

# --- Utility ---
die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

# Absolute path of the .git directory of the current repo.
# All script state lives in there, never in the work tree, so `git status`
# shows only the student's own changes and `git add .` never picks it up.
git_dir() {
    local d
    d=$(git rev-parse --absolute-git-dir 2>/dev/null) && { printf '%s' "$d"; return 0; }
    d=$(git rev-parse --git-dir 2>/dev/null) || return 1
    (cd "$d" && pwd)
}

# Marker of a finished setup; first line = default branch, second line
# "local" for a repo made by setup --local.
marker_path()   { printf '%s/gs-built' "$(git_dir)"; }
# Written when setup starts, removed when it ends: its presence means an
# unfinished setup (broken push, Ctrl+C, a stopped Codespace).
started_path()  { printf '%s/gs-setup-started' "$(git_dir)"; }
# Same for one scenario during add or reset.
building_path() { printf '%s/gs-building-%s' "$(git_dir)" "$1"; }

# Show a path with $HOME written as ~ (for next: lines).
display_path() {
    case "$1" in
        "$HOME")   printf '%s' "~" ;;
        "$HOME"/*) printf '%s/%s' "~" "${1#"$HOME"/}" ;;
        *)         printf '%s' "$1" ;;
    esac
}

# Is a rebase, merge, cherry-pick or revert in progress?
operation_in_progress() {
    local gd
    gd=$(git_dir) || return 1
    [ -d "$gd/rebase-merge" ] || [ -d "$gd/rebase-apply" ] || \
        [ -f "$gd/MERGE_HEAD" ] || [ -f "$gd/CHERRY_PICK_HEAD" ] || [ -f "$gd/REVERT_HEAD" ]
}

abort_operations() {
    git rebase --abort >/dev/null 2>&1 || true
    git merge --abort >/dev/null 2>&1 || true
    git cherry-pick --abort >/dev/null 2>&1 || true
    git revert --abort >/dev/null 2>&1 || true
}

# --- Colour helpers (READY header) ---
_COLOUR_ON=""
_COLOUR_OFF=""
if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
    _nc=$(tput colors 2>/dev/null) || _nc=0
    if [ "${_nc:-0}" -ge 8 ]; then
        _COLOUR_ON="$(tput bold)$(tput setaf 2)"
        _COLOUR_OFF="$(tput sgr0)"
    fi
fi

# --- Marker helpers ---
# An earlier version kept the marker as .gs-built in the work tree: move it.
migrate_legacy_marker() {
    local top
    top=$(git rev-parse --show-toplevel 2>/dev/null) || return 0
    if [ -f "$top/.gs-built" ] && [ ! -f "$(marker_path)" ]; then
        mv "$top/.gs-built" "$(marker_path)"
    fi
    return 0
}

# Read the marker into DEFAULT_BRANCH and LOCAL_MODE.
read_marker() {
    local m
    m=$(marker_path)
    DEFAULT_BRANCH=$(sed -n 1p "$m" 2>/dev/null) || DEFAULT_BRANCH=""
    [ -z "$DEFAULT_BRANCH" ] && DEFAULT_BRANCH="main"
    if [ "$(sed -n 2p "$m" 2>/dev/null)" = "local" ]; then
        LOCAL_MODE=1
    else
        LOCAL_MODE=0
    fi
}

# For add, reset, graph: a finished setup must exist.
require_built() {
    git rev-parse --git-dir >/dev/null 2>&1 || \
        die "not a git repository; cd to your practice repo first"
    migrate_legacy_marker
    [ -f "$(marker_path)" ] || die "run 'bash ~/gs/scenarios.sh setup' first"
    read_marker
}

# --- Safety check ---
# Sets ALREADY_BUILT=1 when the marker exists (already-built repo).
# Sets ALREADY_BUILT=0 when this is a valid fresh one-commit repo.
# Cleans up an unfinished earlier setup first. Dies on any other condition.
ALREADY_BUILT=0
safety_check() {
    # Is this a git repository at all?
    git rev-parse --git-dir >/dev/null 2>&1 || \
        die "not a git repository; create a repository and clone the script into it"

    # Zero commits?
    if ! git rev-parse --verify --quiet HEAD >/dev/null 2>&1; then
        printf 'no commit yet: create the README on the repo page\n' >&2
        exit 1
    fi

    # Already built by this script?
    migrate_legacy_marker
    if [ -f "$(marker_path)" ]; then
        ALREADY_BUILT=1
        return 0
    fi

    # An earlier setup stopped half way: drop what it left
    if [ -f "$(started_path)" ]; then
        clean_partial_setup
    fi

    # Must have an origin remote
    git remote get-url origin >/dev/null 2>&1 || \
        die "no remote named 'origin'"

    # Working tree must be clean (no tracked changes)
    git diff --quiet 2>/dev/null || \
        die "working tree has unstaged changes; commit or stash them first"
    git diff --cached --quiet 2>/dev/null || \
        die "index has staged changes; commit or stash them first"

    # Must have exactly one commit on the current branch
    local n
    n=$(git --no-pager rev-list --count HEAD 2>/dev/null) || n=0
    if [ "$n" -ne 1 ]; then
        die "expected exactly one commit on the current branch (found $n); this does not look like a fresh practice repository"
    fi

    # That one commit must have only README.md (optionally .gitignore or LICENSE)
    local extra
    extra=$(git --no-pager ls-files | \
        grep -Ev '^(README\.md|\.gitignore|LICENSE(\.txt|\.md)?)$') || true
    if [ -n "$extra" ]; then
        die "the repository has unexpected files; run setup in a fresh repository that has only a README"
    fi

    # shellcheck disable=SC2034
    ALREADY_BUILT=0
}

# Remove what an interrupted setup left behind: the local scenario branches
# and any half-made commit. The default branch was never touched. Remote
# leftovers are overwritten by the forced push of the new build.
clean_partial_setup() {
    local db b
    printf 'Found an unfinished setup, cleaning it up.\n'
    db=$(sed -n 1p "$(started_path)" 2>/dev/null) || db=""
    [ -z "$db" ] && db="main"
    abort_operations
    git reset --hard --quiet 2>/dev/null || true
    git checkout --quiet "$db" 2>/dev/null || die "cannot switch to '$db'; run 'git switch $db', then setup again"
    for b in $SETUP_BRANCHES; do
        if git rev-parse --verify --quiet "refs/heads/$b" >/dev/null 2>&1; then
            git --no-pager branch -D "$b" >/dev/null 2>&1 || true
        fi
    done
    rm -f "$(started_path)"
}

# --- Base commit and timestamps ---
# Every scenario starts from the README commit (the root of the default
# branch), even if commits were added to the default branch later.
# Commit dates: one hour before the README commit plus fixed minutes, so no
# scenario commit is ever dated in the future and builds stay deterministic.
init_base() {
    BASE_SHA=$(git --no-pager rev-list --max-parents=0 "$DEFAULT_BRANCH" 2>/dev/null | tail -1) || BASE_SHA=""
    [ -z "$BASE_SHA" ] && BASE_SHA=$(git rev-parse HEAD)
    ROOT_TS=$(( $(git --no-pager log -1 --format=%at "$BASE_SHA") - 3600 ))
}

# --- Read default branch from HEAD (setup only; later commands use the marker) ---
init_default_branch() {
    # shellcheck disable=SC2034
    DEFAULT_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null) || DEFAULT_BRANCH="main"
}

# --- Commit helper ---
# commit_as NAME EMAIL OFFSET_SECS MESSAGE [FILE CONTENT ...]
# Writes each FILE with CONTENT (adds a trailing newline), stages it, and commits.
# Multiple FILE CONTENT pairs are allowed.
commit_as() {
    local name="$1" email="$2" offset="$3" msg="$4"
    shift 4
    local ts
    ts=$(( ROOT_TS + offset ))
    while [ "$#" -ge 2 ]; do
        printf '%s\n' "$2" > "$1"
        git add "$1"
        shift 2
    done
    GIT_AUTHOR_NAME="$name"    GIT_AUTHOR_EMAIL="$email" \
    GIT_COMMITTER_NAME="$name" GIT_COMMITTER_EMAIL="$email" \
    GIT_AUTHOR_DATE="@${ts}"   GIT_COMMITTER_DATE="@${ts}" \
    git --no-pager commit --quiet -m "$msg"
}

# commit_multiline NAME EMAIL OFFSET_SECS MESSAGE FILE CONTENT
# CONTENT is passed through printf '%b\n' so \n becomes a newline.
commit_multiline() {
    local name="$1" email="$2" offset="$3" msg="$4" f="$5" content="$6"
    local ts
    ts=$(( ROOT_TS + offset ))
    printf '%b\n' "$content" > "$f"
    git add "$f"
    GIT_AUTHOR_NAME="$name"    GIT_AUTHOR_EMAIL="$email" \
    GIT_COMMITTER_NAME="$name" GIT_COMMITTER_EMAIL="$email" \
    GIT_AUTHOR_DATE="@${ts}"   GIT_COMMITTER_DATE="@${ts}" \
    git --no-pager commit --quiet -m "$msg"
}

# commit_append NAME EMAIL OFFSET_SECS MESSAGE FILE LINE
# Appends LINE to FILE and commits.
commit_append() {
    local name="$1" email="$2" offset="$3" msg="$4" f="$5" line="$6"
    local ts
    ts=$(( ROOT_TS + offset ))
    printf '%s\n' "$line" >> "$f"
    git add "$f"
    GIT_AUTHOR_NAME="$name"    GIT_AUTHOR_EMAIL="$email" \
    GIT_COMMITTER_NAME="$name" GIT_COMMITTER_EMAIL="$email" \
    GIT_AUTHOR_DATE="@${ts}"   GIT_COMMITTER_DATE="@${ts}" \
    git --no-pager commit --quiet -m "$msg"
}

# --- Push helper ---
# push_branches BRANCH [BRANCH ...]
# Forced: these branches belong to the script; a rerun after an interrupted
# setup must replace whatever an earlier run left on origin.
push_branches() {
    git push --quiet --force -u origin "$@"
}

# --- Parse GitHub owner/repo from origin URL ---
parse_origin() {
    local url
    url=$(git remote get-url origin 2>/dev/null) || { GH_OWNER=""; GH_REPO=""; return 1; }
    case "$url" in
        https://github.com/*)
            url="${url#https://github.com/}"
            GH_OWNER="${url%%/*}"
            GH_REPO="${url#*/}"; GH_REPO="${GH_REPO%.git}"
            ;;
        git@github.com:*)
            url="${url#git@github.com:}"
            GH_OWNER="${url%%/*}"
            GH_REPO="${url#*/}"; GH_REPO="${GH_REPO%.git}"
            ;;
        *)
            GH_OWNER=""; GH_REPO=""
            return 1
            ;;
    esac
}

# --- Check if gh is on PATH (never in local mode: there is no GitHub repo) ---
check_gh() {
    GH_AVAILABLE=0
    [ "$LOCAL_MODE" -eq 1 ] && return 0
    command -v gh >/dev/null 2>&1 && GH_AVAILABLE=1
    return 0
}

reset_pr_tracking() {
    PR_FAILED=0
    PR_OPENED=0
    PR_NUMBERS=""
    PR_LINKS_LIST=""
    PR_LINKS_COUNT=0
    PR_BUTTONS_FAILED=0
}

# --- Create a pull request or accumulate a compare link ---
# pr_create BASE HEAD TITLE BODY
# Sleeps 2s before the gh call (> 1.5s spacing required by PLAN F11).
# A pull request counts as opened when gh succeeds, or when gh says it
# already exists (a rerun after an interrupted setup); its number is read
# from the URL gh prints. Otherwise PR_FAILED=1 and, for the buttons pull
# requests, a compare link is kept for the READY block. Always returns 0.
pr_create() {
    local base="$1" head="$2" title="$3" body="$4"
    local out rc num
    [ "$LOCAL_MODE" -eq 1 ] && return 0
    sleep 2 2>/dev/null || true
    if [ "$GH_AVAILABLE" -eq 1 ]; then
        rc=0
        out=$(GH_PROMPT_DISABLED=1 gh pr create \
              --base "$base" --head "$head" \
              --title "$title" --body "$body" 2>&1) || rc=$?
        num=$(printf '%s\n' "$out" | sed -n 's#.*/pull/\([0-9][0-9]*\).*#\1#p' | tail -1) || num=""
        if [ "$rc" -eq 0 ] || [ -n "$num" ]; then
            PR_OPENED=$(( PR_OPENED + 1 ))
            [ -n "$num" ] && PR_NUMBERS="${PR_NUMBERS} #${num}"
            return 0
        fi
    fi
    # gh unavailable or failed: accumulate compare link (buttons PRs only —
    # those are the three Step 1 needs; the rest work without pull requests)
    PR_FAILED=1
    case "$head" in
        buttons-*)
            PR_BUTTONS_FAILED=$(( PR_BUTTONS_FAILED + 1 ))
            if [ -n "$GH_OWNER" ] && [ -n "$GH_REPO" ]; then
                local link="https://github.com/${GH_OWNER}/${GH_REPO}/compare/${base}...${head}${COMPARE_LINK_PARAM}"
                PR_LINKS_LIST="${PR_LINKS_LIST}  ${link}
"
                PR_LINKS_COUNT=$(( PR_LINKS_COUNT + 1 ))
            fi
            ;;
    esac
    return 0
}

# Print one line about the pull requests just created (add, reset).
# Only called for ids that have pull requests.
print_pr_result() {
    local n_numbers
    [ "$LOCAL_MODE" -eq 1 ] && return 0
    n_numbers=$(printf '%s' "$PR_NUMBERS" | wc -w | tr -d ' ')
    if [ "$PR_FAILED" -eq 0 ]; then
        if [ "$n_numbers" -eq "$PR_OPENED" ] && [ "$PR_OPENED" -gt 0 ]; then
            printf 'pull requests opened:%s\n' "$PR_NUMBERS"
        else
            printf 'pull requests opened: %d\n' "$PR_OPENED"
        fi
    else
        if [ "$PR_OPENED" -gt 0 ]; then
            printf 'pull requests opened: %d (%s), the others not opened (gh unavailable or failed)\n' \
                "$PR_OPENED" "${PR_NUMBERS# }"
        else
            printf 'pull requests not opened (gh unavailable or failed)\n'
        fi
        [ -z "$PR_LINKS_LIST" ] || printf '%s' "$PR_LINKS_LIST"
    fi
    return 0
}

# --- Scenario facts ---
# The branch whose name is <id>-main (used to tell if a scenario is built)
scenario_is_built() {
    case " $ALL_IDS " in
        *" $1 "*) ;;
        *) return 1 ;;
    esac
    git rev-parse --verify --quiet "refs/heads/${1}-main" >/dev/null 2>&1
}

is_known_id() {
    case " $ALL_IDS " in
        *" $1 "*) return 0 ;;
        *) return 1 ;;
    esac
}

# Does this id open pull requests?
scenario_has_prs() {
    case "$1" in
        buttons|behind|clash|replay|stack) return 0 ;;
        *) return 1 ;;
    esac
}

# The branch the task card starts on
scenario_start_branch() {
    case "$1" in
        buttons)  printf '%s' "buttons-main" ;;
        behind)   printf '%s' "behind-feature" ;;
        clash)    printf '%s' "clash-feature" ;;
        replay)   printf '%s' "replay-feature" ;;
        hotfix)   printf '%s' "hotfix-release" ;;
        diverge)  printf '%s' "diverge-main" ;;
        oops)     printf '%s' "oops-main" ;;
        stack)    printf '%s' "stack-b" ;;
        lease)    printf '%s' "lease-feature" ;;
        backport) printf '%s' "backport-release" ;;
        *)        printf '%s' "main" ;;
    esac
}

# --- Delete local and remote branches for a scenario ---
delete_scenario_branches() {
    local id="$1"
    local branches b
    case "$id" in
        buttons)  branches="buttons-main buttons-login buttons-search buttons-help" ;;
        behind)   branches="behind-main behind-feature" ;;
        clash)    branches="clash-main clash-feature" ;;
        replay)   branches="replay-main replay-feature" ;;
        hotfix)   branches="hotfix-main hotfix-release" ;;
        diverge)  branches="diverge-main" ;;
        oops)     branches="oops-main" ;;
        stack)    branches="stack-main stack-a stack-b" ;;
        lease)    branches="lease-main lease-feature" ;;
        backport) branches="backport-main backport-release" ;;
        *) return 1 ;;
    esac
    for b in $branches; do
        git --no-pager branch -D "$b" >/dev/null 2>&1 || true
        git push --quiet origin --delete "$b" >/dev/null 2>&1 || true
    done
    return 0
}

# --- Close open pull requests for a scenario (best-effort) ---
close_scenario_prs() {
    local id="$1"
    [ "$GH_AVAILABLE" -eq 0 ] && return 0
    local heads="" h
    case "$id" in
        buttons)  heads="buttons-login buttons-search buttons-help" ;;
        behind)   heads="behind-feature" ;;
        clash)    heads="clash-feature" ;;
        replay)   heads="replay-feature" ;;
        stack)    heads="stack-a stack-b" ;;
        *) return 0 ;;
    esac
    for h in $heads; do
        { GH_PROMPT_DISABLED=1 gh pr list --head "$h" --json number 2>/dev/null || true; } | \
            { grep -o '"number":[0-9]*' || true; } | { grep -o '[0-9][0-9]*' || true; } | \
            while IFS= read -r num; do
                [ -z "$num" ] || GH_PROMPT_DISABLED=1 gh pr close "$num" >/dev/null 2>&1 || true
            done
    done
    return 0
}

# --- One-line goal for each scenario ---
scenario_goal() {
    case "$1" in
        buttons)  printf '%s' "predict and merge three pull requests" ;;
        behind)   printf '%s' "rebase a branch that is behind and push with a lease" ;;
        clash)    printf '%s' "resolve a conflict in a merge" ;;
        replay)   printf '%s' "resolve a conflict in a rebase" ;;
        hotfix)   printf '%s' "cherry-pick two fix commits" ;;
        diverge)  printf '%s' "handle a diverged git pull" ;;
        oops)     printf '%s' "revert and restore commits with git reflog" ;;
        stack)    printf '%s' "repair a stacked branch after a squash merge" ;;
        lease)    printf '%s' "push after a teammate pushed first" ;;
        backport) printf '%s' "cherry-pick a commit that conflicts" ;;
        *)        printf '%s' "unknown" ;;
    esac
}

# --- Print the READY block (at most 8 lines) ---
# $1: n_built  $2: local_mode (1 = local bare origin, default 0)
# $3: the practice folder as shown in the next: line (local mode only)
print_ready() {
    local n_built="$1" local_mode="${2:-0}" shown_dir="${3:-}"
    local repo_name
    repo_name=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)") || repo_name="practice"

    printf '\n'
    printf '%sREADY%s  %s\n' "$_COLOUR_ON" "$_COLOUR_OFF" "$repo_name"
    printf 'scenarios built: %d of 10    (stack, lease, backport: add on demand)\n' "$n_built"
    if [ "${local_mode}" -eq 1 ]; then
        # Local mode: no GitHub remote, no pull requests, different next step
        printf 'pull requests: local mode (Step 1 follows the instructor screen)\n'
        printf 'next: cd %s, then git switch buttons-main\n' "$shown_dir"
    elif [ "$PR_FAILED" -eq 0 ]; then
        printf 'pull requests opened: %d\n' "$PR_OPENED"
        printf 'next: git switch buttons-main\n'
    else
        # gh failed for some or all: show only the buttons links Step 1 needs
        local what=""
        if [ "$PR_LINKS_COUNT" -eq 1 ]; then
            what="1 link to open by hand"
        elif [ "$PR_LINKS_COUNT" -gt 1 ]; then
            what="$PR_LINKS_COUNT links to open by hand"
        fi
        if [ "$PR_OPENED" -eq 0 ]; then
            if [ "$PR_LINKS_COUNT" -gt 0 ]; then
                printf 'pull requests not opened: %s\n' "$what"
            else
                printf 'pull requests not opened (gh unavailable or failed)\n'
            fi
        elif [ "$PR_LINKS_COUNT" -gt 0 ]; then
            printf 'pull requests opened: %d of 6, not opened: %s\n' "$PR_OPENED" "$what"
        elif [ "$PR_BUTTONS_FAILED" -eq 0 ]; then
            printf 'pull requests opened: %d of 6 (the three buttons pull requests are open)\n' "$PR_OPENED"
        else
            printf 'pull requests opened: %d of 6 (gh failed for the others)\n' "$PR_OPENED"
        fi
        [ -z "$PR_LINKS_LIST" ] || printf '%s' "$PR_LINKS_LIST"
        printf 'next: git switch buttons-main\n'
    fi
    return 0
}
