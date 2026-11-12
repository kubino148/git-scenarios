#!/usr/bin/env bash
# 05-hotfix.sh — scenario "hotfix": cherry-pick two fix commits
# Sourced by scenarios.sh; defines build_scenario_hotfix.
# hotfix-release stays at the base; student cherry-picks two fix commits from hotfix-main.

build_scenario_hotfix() {
    # --- shared base commit (Alice) ---
    # shellcheck disable=SC2153  # BASE_SHA is set in lib.sh
    git checkout -b hotfix-release "$BASE_SHA" --quiet
    commit_as "$ALICE_NAME" "$ALICE_EMAIL" 1440 \
        "Add settings file" \
        "title.txt" "title = Tasks" \
        "total.txt" "total = sum"
    local base_sha
    base_sha=$(git rev-parse HEAD)

    # --- hotfix-main: four commits beyond the base ---
    git checkout -b hotfix-main "$base_sha" --quiet 2>/dev/null
    commit_as "$ALICE_NAME" "$ALICE_EMAIL" 1500 \
        "Add dark mode toggle" "dark.txt" "dark mode toggle"
    commit_append "$BOB_NAME" "$BOB_EMAIL" 1560 \
        "Fix crash on empty title" "title.txt" "check empty"
    commit_as "$CAROL_NAME" "$CAROL_EMAIL" 1620 \
        "Add export button" "export.txt" "export button"
    commit_as "$BOB_NAME" "$BOB_EMAIL" 1680 \
        "Fix total rounding" "total.txt" "total = round(sum)"

    git checkout "$DEFAULT_BRANCH" --quiet
}

push_scenario_hotfix() {
    push_branches hotfix-release hotfix-main
}

# No pull requests for this scenario
create_prs_hotfix() { return 0; }
