#!/usr/bin/env bash
# demo.sh — builds four plain local demo repos for the Segment 1 live demos
# Sourced by scenarios.sh; defines build_demo_<name> functions.
# Each repo is ~/demo-<name>; refused if the dir exists and was not created here.

DEMO_MARKER=".gs-demo"

_demo_init() {
    local dir="$2"
    if [ -d "$dir" ]; then
        if [ ! -f "$dir/$DEMO_MARKER" ]; then
            die "directory '$dir' already exists and was not created by this script"
        fi
        rm -rf "$dir"
    fi
    mkdir -p "$dir"
    cd "$dir" || die "cannot cd to $dir"
    git init --quiet
    # Try to rename to main; if already main (git 2.28+) this is a no-op
    git checkout --quiet -b main 2>/dev/null || true
    git config core.pager cat
    # Use the current time as root timestamp for demos (non-deterministic is fine)
    ROOT_TS=$(date +%s); export ROOT_TS
    # Use a local identity for demos
    local name_val email_val
    name_val=$(git config user.name 2>/dev/null) || name_val=""
    email_val=$(git config user.email 2>/dev/null) || email_val=""
    [ -z "$name_val" ] && git config user.name "Instructor"
    [ -z "$email_val" ] && git config user.email "instructor@example.com"
    touch "$DEMO_MARKER"
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

    # main: one commit
    commit_as "$ALICE_NAME" "$ALICE_EMAIL" 120 \
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

    # Identical history to demo-merge
    commit_as "$ALICE_NAME" "$ALICE_EMAIL" 60 \
        "Add cart page" "cart.txt" "cart page"
    local base
    base=$(git rev-parse HEAD)
    commit_as "$ALICE_NAME" "$ALICE_EMAIL" 120 \
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

    commit_as "$ALICE_NAME" "$ALICE_EMAIL" 60 \
        "Add cart page" "cart.txt" "shipping = 0"
    local base
    base=$(git rev-parse HEAD)

    # main: Carol sets shipping to 5
    commit_as "$CAROL_NAME" "$CAROL_EMAIL" 120 \
        "Set shipping to 5" "cart.txt" "shipping = 5"

    # feature: Bob sets shipping to 8 (same line, conflicts with Carol)
    git checkout -b feature "$base" --quiet 2>/dev/null
    commit_as "$BOB_NAME" "$BOB_EMAIL" 180 \
        "Set shipping to 8" "cart.txt" "shipping = 8"

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
