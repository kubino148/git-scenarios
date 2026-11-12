#!/usr/bin/env bash
# 10-backport.sh — scenario "backport" (on demand): cherry-pick a commit that conflicts
# Sourced by scenarios.sh; defines build_scenario_backport.
#
# Conflict: picking "Read timeout from environment" (parent: "timeout = 10")
# onto backport-release (which has "timeout = 5") conflicts on line 1.
# Designed resolution: "timeout = $TIMEOUT"

build_scenario_backport() {
    # --- shared base commit ---
    # shellcheck disable=SC2153  # BASE_SHA is set in lib.sh
    git checkout -b backport-release "$BASE_SHA" --quiet
    commit_as "$ALICE_NAME" "$ALICE_EMAIL" 3060 \
        "Add settings" "settings.txt" "timeout = 5"
    local base_sha
    base_sha=$(git rev-parse HEAD)

    # --- backport-main: two commits beyond the base ---
    git checkout -b backport-main "$base_sha" --quiet 2>/dev/null
    commit_as "$CAROL_NAME" "$CAROL_EMAIL" 3120 \
        "Raise timeout to 10" "settings.txt" "timeout = 10"
    commit_as "$BOB_NAME" "$BOB_EMAIL" 3180 \
        "Read timeout from environment" "settings.txt" "timeout = \$TIMEOUT"

    git checkout "$DEFAULT_BRANCH" --quiet
}

push_scenario_backport() {
    push_branches backport-main backport-release
}

# No pull requests for this scenario
create_prs_backport() { return 0; }
