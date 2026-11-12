#!/usr/bin/env bash
# 07-oops.sh — scenario "oops": revert and restore commits with git reflog
# Sourced by scenarios.sh; defines build_scenario_oops.

build_scenario_oops() {
    git checkout -b oops-main "$BASE_SHA" --quiet
    commit_as "$ALICE_NAME" "$ALICE_EMAIL" 2100 \
        "Add database config" "db.txt" "database = production"
    commit_as "$BOB_NAME" "$BOB_EMAIL" 2160 \
        "Add health check" "health.txt" "health check"
    commit_as "$BOB_NAME" "$BOB_EMAIL" 2220 \
        "Point database at test server" "db.txt" "database = test"
    commit_as "$CAROL_NAME" "$CAROL_EMAIL" 2280 \
        "Add logging" "logging.txt" "logging"
    commit_as "$CAROL_NAME" "$CAROL_EMAIL" 2340 \
        "Add metrics" "metrics.txt" "metrics"

    git checkout "$DEFAULT_BRANCH" --quiet
}

push_scenario_oops() {
    push_branches oops-main
}

# No pull requests for this scenario
create_prs_oops() { return 0; }
