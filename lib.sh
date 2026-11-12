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
ROOT_TS=""        # Unix timestamp of the root (README) commit
GH_OWNER=""       # Parsed from origin URL
GH_REPO=""        # Parsed from origin URL
DEFAULT_BRANCH="" # Read from the repo
GH_AVAILABLE=0    # 1 if gh is on PATH
PR_FAILED=0       # 1 if any pr_create call failed
PR_LINKS_LIST=""  # Compare links accumulated when gh fails (buttons only)
# shellcheck disable=SC2034
PR_LINKS_COUNT=0  # Number of buttons links accumulated

# Marker file (untracked) placed in the practice repo after a successful setup
MARKER_FILE=".gs-built"

# Compare-link query parameter — smoke test verifies the actual form before class
# shellcheck disable=SC2034
COMPARE_LINK_PARAM="?quick_pull=1"

# --- Utility ---
die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
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

# --- Safety check ---
# Sets ALREADY_BUILT=1 when the marker exists (already-built repo).
# Sets ALREADY_BUILT=0 when this is a valid fresh one-commit repo.
# Dies on any other condition.
ALREADY_BUILT=0
safety_check() {
    # Is this a git repository at all?
    git rev-parse --git-dir >/dev/null 2>&1 || \
        die "not a git repository; create a repository and clone the script into it"

    # Zero commits?
    if ! git rev-parse HEAD >/dev/null 2>&1; then
        printf 'no commit yet: create the README on the repo page\n' >&2
        exit 1
    fi

    # Already built by this script?
    if [ -f "$MARKER_FILE" ]; then
        ALREADY_BUILT=1
        return 0
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

# --- Read root commit timestamp ---
# Must be called while on the branch that has the README commit.
init_root_ts() {
    ROOT_TS=$(git --no-pager log -1 --format=%at HEAD)
}

# --- Read default branch ---
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
push_branches() {
    git push --quiet -u origin "$@"
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

# --- Check if gh is on PATH ---
check_gh() {
    GH_AVAILABLE=0
    command -v gh >/dev/null 2>&1 && GH_AVAILABLE=1
}

# --- Create a pull request or accumulate a compare link ---
# pr_create BASE HEAD TITLE BODY
# Sleeps 2s before the gh call (> 1.5s spacing required by PLAN F11).
# Sets PR_FAILED=1 if gh is unavailable or the call fails.
# Accumulates compare links for buttons:* PRs when gh fails.
pr_create() {
    local base="$1" head="$2" title="$3" body="$4"
    sleep 2 2>/dev/null || true
    if [ "$GH_AVAILABLE" -eq 1 ]; then
        if GH_PROMPT_DISABLED=1 gh pr create \
              --base "$base" --head "$head" \
              --title "$title" --body "$body" \
              >/dev/null 2>&1; then
            return 0
        fi
    fi
    # gh unavailable or failed: accumulate compare link (buttons PRs only —
    # those are the three Step 1 needs; the rest are opened by list / README)
    PR_FAILED=1
    case "$head" in
        buttons-*)
            if [ -n "$GH_OWNER" ] && [ -n "$GH_REPO" ]; then
                local link="https://github.com/${GH_OWNER}/${GH_REPO}/compare/${base}...${head}${COMPARE_LINK_PARAM}"
                PR_LINKS_LIST="${PR_LINKS_LIST}  ${link}
"
                PR_LINKS_COUNT=$(( PR_LINKS_COUNT + 1 ))
            fi
            ;;
    esac
}

# --- Check if a scenario's main branch exists locally ---
scenario_is_built() {
    local id="$1"
    local branch
    case "$id" in
        buttons)  branch="buttons-main"  ;;
        behind)   branch="behind-main"   ;;
        clash)    branch="clash-main"    ;;
        replay)   branch="replay-main"   ;;
        hotfix)   branch="hotfix-main"   ;;
        diverge)  branch="diverge-main"  ;;
        oops)     branch="oops-main"     ;;
        stack)    branch="stack-main"    ;;
        lease)    branch="lease-main"    ;;
        backport) branch="backport-main" ;;
        *)        return 1               ;;
    esac
    git rev-parse --verify "$branch" >/dev/null 2>&1
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
# $1: n_built  $2: pr_count  $3: local_mode (1 = local bare origin, default 0)
print_ready() {
    local n_built="$1" pr_count="$2" local_mode="${3:-0}"
    local repo_name
    repo_name=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)") || repo_name="practice"

    printf '\n'
    printf '%sREADY%s  %s\n' "$_COLOUR_ON" "$_COLOUR_OFF" "$repo_name"
    printf 'scenarios built: %d of 10    (stack, lease, backport: add on demand)\n' "$n_built"
    if [ "${local_mode}" -eq 1 ]; then
        # Local mode: no GitHub remote, no pull requests, different next step
        printf 'pull requests: local mode (Step 1 follows the instructor screen)\n'
        printf 'next: cd ~/practice, then git switch buttons-main\n'
    elif [ "$PR_FAILED" -eq 0 ]; then
        printf 'pull requests opened: %d\n' "$pr_count"
        printf 'next: git switch buttons-main\n'
    else
        # gh failed: show only the three buttons links Step 1 needs
        if [ "$PR_LINKS_COUNT" -eq 1 ]; then
            printf 'pull requests not opened: 1 link to open by hand\n'
        else
            printf 'pull requests not opened: %d links to open by hand\n' "$PR_LINKS_COUNT"
        fi
        printf '%s' "$PR_LINKS_LIST"
        printf 'next: git switch buttons-main\n'
    fi
}

# --- Delete local and remote branches for a scenario ---
delete_scenario_branches() {
    local id="$1"
    local branches
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
        git --no-pager branch -D "$b" 2>/dev/null || true
        git push --quiet origin --delete "$b" 2>/dev/null || true
    done
}

# --- Close open pull requests for a scenario (best-effort) ---
close_scenario_prs() {
    local id="$1"
    [ "$GH_AVAILABLE" -eq 0 ] && return 0
    local heads=""
    case "$id" in
        buttons)  heads="buttons-login buttons-search buttons-help" ;;
        behind)   heads="behind-feature" ;;
        clash)    heads="clash-feature" ;;
        replay)   heads="replay-feature" ;;
        stack)    heads="stack-a stack-b" ;;
        *) return 0 ;;
    esac
    for h in $heads; do
        GH_PROMPT_DISABLED=1 gh pr list --head "$h" --json number 2>/dev/null | \
            grep -o '"number":[0-9]*' | grep -o '[0-9]*' | \
            while IFS= read -r num; do
                [ -n "$num" ] && GH_PROMPT_DISABLED=1 gh pr close "$num" 2>/dev/null || true
            done || true
    done
}
