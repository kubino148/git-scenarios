#!/usr/bin/env bash
# 03-clash.sh — scenario "clash": resolve a conflict in a merge
# Sourced by scenarios.sh; defines build_scenario_clash.

build_scenario_clash() {
    # --- clash-main: Alice's base commit ---
    # shellcheck disable=SC2153  # BASE_SHA is set in lib.sh
    git checkout -b clash-main "$BASE_SHA" --quiet
    commit_as "$ALICE_NAME" "$ALICE_EMAIL" 960 \
        "Add server file" "server.txt" "timeout = 10"
    local base_sha
    base_sha=$(git rev-parse HEAD)

    # --- clash-feature: two Bob commits from the base ---
    git checkout -b clash-feature "$base_sha" --quiet 2>/dev/null
    commit_as "$BOB_NAME" "$BOB_EMAIL" 1020 \
        "Raise timeout to 30" "server.txt" "timeout = 30"
    commit_as "$BOB_NAME" "$BOB_EMAIL" 1080 \
        "Add retry setting" "retry.txt" "retries = 3"

    # --- clash-main moves: Carol lowers timeout (conflicts with Bob's raise) ---
    git checkout clash-main --quiet
    commit_as "$CAROL_NAME" "$CAROL_EMAIL" 1140 \
        "Lower timeout to 5" "server.txt" "timeout = 5"

    git checkout "$DEFAULT_BRANCH" --quiet
}

push_scenario_clash() {
    push_branches clash-main clash-feature
}

create_prs_clash() {
    pr_create "clash-main" "clash-feature" \
        "clash: Raise timeout to 30" \
        "Raises the server timeout and adds a retry setting. Written by Bob."
}
