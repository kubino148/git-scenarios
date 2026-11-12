#!/usr/bin/env bash
# demo.sh — builds four plain local demo repos for the Segment 1 live demos
# Sourced by scenarios.sh; defines build_demo_<name> functions.
# Each repo is ~/demo-<name>; refused if the dir exists and was not created here.

# Marker inside the demo repo's .git directory, so `git status` stays clean.
# (An earlier version kept .gs-demo in the work tree; such folders are
# recognised too and rebuilt.)
DEMO_MARKER_NAME="gs-demo"

_demo_init() {
    local dir="$2"
    if [ -d "$dir" ]; then
        if [ ! -f "$dir/.git/$DEMO_MARKER_NAME" ] && [ ! -f "$dir/.gs-demo" ]; then
            die "directory '$dir' already exists and was not created by this script"
        fi
        cd "$HOME" 2>/dev/null || cd /
        rm -rf "$dir"
    fi
    mkdir -p "$dir"
    cd "$dir" || die "cannot cd to $dir"
    git init --quiet
    git symbolic-ref HEAD refs/heads/main
    git config core.pager cat
    # Dated one hour back from now: no commit lies in the future, so the
    # graph after a live rebase or cherry-pick has the same shape at once
    ROOT_TS=$(( $(date +%s) - 3600 )); export ROOT_TS
    # Use a local identity for demos
    local name_val email_val
    name_val=$(git config user.name 2>/dev/null) || name_val=""
    email_val=$(git config user.email 2>/dev/null) || email_val=""
    [ -n "$name_val" ] || git config user.name "Instructor"
    [ -n "$email_val" ] || git config user.email "instructor@example.com"
    : > "$(git_dir)/$DEMO_MARKER_NAME"
}

# demo-merge: shows the diamond shape of a merge commit
build_demo_merge() {
    local dir="$HOME/demo-merge"
    _demo_init "merge" "$dir"

    # Base commit
    commit_as "$ALICE_NAME" "$ALICE_EMAIL" 60 \
        "Add cart page" "cart.txt" "cart page"
    local base
    base=$(git rev-parse HEAD)

    # main: one commit, dated after the feature commits so it is drawn on top
    commit_as "$ALICE_NAME" "$ALICE_EMAIL" 300 \
        "Add price list" "prices.txt" "price list"

    # feature: two Bob commits from base
    git checkout -b feature "$base" --quiet 2>/dev/null
    commit_as "$BOB_NAME" "$BOB_EMAIL" 180 \
        "Add coupon field" "coupon.txt" "coupon field"
    commit_as "$BOB_NAME" "$BOB_EMAIL" 240 \
        "Check coupon length" "coupon.txt" "coupon validation"

    git checkout main --quiet
    printf '\ndemo-merge ready in %s\n' "$dir"
    printf 'next: git merge --no-edit feature\n'
    cd - >/dev/null || true
}

# demo-rebase: same history, shows the line and new ids (backup branch shows old ids)
build_demo_rebase() {
    local dir="$HOME/demo-rebase"
    _demo_init "rebase" "$dir"

    # Identical history to demo-merge (price list dated after the feature commits)
    commit_as "$ALICE_NAME" "$ALICE_EMAIL" 60 \
        "Add cart page" "cart.txt" "cart page"
    local base
    base=$(git rev-parse HEAD)
    commit_as "$ALICE_NAME" "$ALICE_EMAIL" 300 \
        "Add price list" "prices.txt" "price list"
    git checkout -b feature "$base" --quiet 2>/dev/null
    commit_as "$BOB_NAME" "$BOB_EMAIL" 180 \
        "Add coupon field" "coupon.txt" "coupon field"
    commit_as "$BOB_NAME" "$BOB_EMAIL" 240 \
        "Check coupon length" "coupon.txt" "coupon validation"

    git checkout main --quiet
    printf '\ndemo-rebase ready in %s\n' "$dir"
    printf 'next: git branch backup feature && git switch feature && git rebase main\n'
    cd - >/dev/null || true
}

# demo-conflict: same line in cart.txt edited on both branches (shipping value)
build_demo_conflict() {
    local dir="$HOME/demo-conflict"
    _demo_init "conflict" "$dir"

    # Three lines; both branches change only the middle one
    commit_multiline "$ALICE_NAME" "$ALICE_EMAIL" 60 \
        "Add cart page" "cart.txt" "cart page\nshipping = 0\ntotal = sum"
    local base
    base=$(git rev-parse HEAD)

    # main: Carol sets shipping to 5
    commit_multiline "$CAROL_NAME" "$CAROL_EMAIL" 120 \
        "Set shipping to 5" "cart.txt" "cart page\nshipping = 5\ntotal = sum"

    # feature: Bob sets shipping to 8 (same line, conflicts with Carol)
    git checkout -b feature "$base" --quiet 2>/dev/null
    commit_multiline "$BOB_NAME" "$BOB_EMAIL" 180 \
        "Set shipping to 8" "cart.txt" "cart page\nshipping = 8\ntotal = sum"

    git checkout main --quiet
    printf '\ndemo-conflict ready in %s\n' "$dir"
    printf 'next (on feature): git merge main\n'
    cd - >/dev/null || true
}

# demo-pick: main has five commits; release has only the base.
# Picking "Fix total rounding" is clean; picking "Check coupon length" stops
# (the file it modifies does not exist on release).
build_demo_pick() {
    local dir="$HOME/demo-pick"
    _demo_init "pick" "$dir"

    commit_as "$ALICE_NAME" "$ALICE_EMAIL" 60 \
        "Add cart page" "cart.txt" "cart page"
    local base
    base=$(git rev-parse HEAD)

    # main: five commits; coupon.txt is added after the base
    commit_as "$BOB_NAME" "$BOB_EMAIL" 120 \
        "Add coupon field" "coupon.txt" "coupon field"
    commit_as "$BOB_NAME" "$BOB_EMAIL" 180 \
        "Fix total rounding" "totals.txt" "total = round(sum)"
    commit_as "$ALICE_NAME" "$ALICE_EMAIL" 240 \
        "Add gift wrap" "giftwrap.txt" "gift wrap option"
    commit_as "$BOB_NAME" "$BOB_EMAIL" 300 \
        "Check coupon length" "coupon.txt" "coupon validation"

    # release: only the base commit
    git checkout -b release "$base" --quiet 2>/dev/null

    git checkout main --quiet
    printf '\ndemo-pick ready in %s\n' "$dir"
    printf 'next (on release): git cherry-pick <id of Fix total rounding>\n'
    cd - >/dev/null || true
}
