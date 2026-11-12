#!/usr/bin/env bash
# 09-lease.sh — scenario "lease" (on demand): push after a teammate pushed first
# Sourced by scenarios.sh; defines build_scenario_lease.
#
# After build:
#   origin/lease-feature  = Bob's 3 commits + Carol's "Add notes tags"
#   local lease-feature   = Bob's 3 commits (tracking ref set back to 3-Bob state)
# When student pushes with --force-with-lease after rebase:
#   git says "(stale info)" because tracking ref != origin HEAD.

build_scenario_lease() {
    # --- lease-main: two Alice commits ---
    git checkout -b lease-main "$BASE_SHA" --quiet
    commit_as "$ALICE_NAME" "$ALICE_EMAIL" 2700 \
        "Add notes" "notes.txt" "notes"
    local notes_sha
    notes_sha=$(git rev-parse HEAD)
    commit_as "$ALICE_NAME" "$ALICE_EMAIL" 2760 \
        "Add archive" "archive.txt" "archive"

    # --- lease-feature: Bob's three commits from "Add notes" (before archive) ---
    git checkout -b lease-feature "$notes_sha" --quiet 2>/dev/null
    commit_as "$BOB_NAME" "$BOB_EMAIL" 2820 \
        "Add notes index" "index.txt" "notes index"
    commit_as "$BOB_NAME" "$BOB_EMAIL" 2880 \
        "Add notes search" "search.txt" "notes search"
    commit_as "$BOB_NAME" "$BOB_EMAIL" 2940 \
        "Add notes export" "export.txt" "notes export"

    git checkout "$DEFAULT_BRANCH" --quiet
}

push_scenario_lease() {
    push_branches lease-main lease-feature
}

# Called after push to inject Carol's commit on origin without the student's tracking ref knowing.
finalize_lease() {
    local three_bob_sha
    three_bob_sha=$(git rev-parse lease-feature)

    git checkout lease-feature --quiet

    # Create Carol's commit on top of Bob's three
    commit_as "$CAROL_NAME" "$CAROL_EMAIL" 3000 \
        "Add notes tags" "tags.txt" "notes tags"

    # Force-push Carol's commit to origin
    git push --quiet --force origin lease-feature 2>/dev/null

    # Reset local to Bob's three commits
    git reset --hard "$three_bob_sha" --quiet 2>/dev/null || true

    # Set the local tracking ref back to Bob's three commits
    # (so the student's lease will be refused as stale)
    git update-ref refs/remotes/origin/lease-feature "$three_bob_sha" 2>/dev/null || true

    git checkout "$DEFAULT_BRANCH" --quiet
}

# No pull requests for this scenario (the stale-push exercise stands alone)
create_prs_lease() { return 0; }
