#!/usr/bin/env bash
# 02-behind.sh — scenario "behind": rebase a branch that is behind and push with a lease
# Sourced by scenarios.sh; defines build_scenario_behind.

build_scenario_behind() {
    # --- behind-main: first commit ---
    git checkout -b behind-main "$BASE_SHA" --quiet
    commit_as "$ALICE_NAME" "$ALICE_EMAIL" 540 \
        "Add header" "header.txt" "header"
    local main_v1
    main_v1=$(git rev-parse HEAD)

    # --- behind-feature: three Bob commits from first main commit ---
    git checkout -b behind-feature "$main_v1" --quiet 2>/dev/null
    commit_as "$BOB_NAME" "$BOB_EMAIL" 600 \
        "Add price filter" "price.txt" "price filter"
    commit_as "$BOB_NAME" "$BOB_EMAIL" 660 \
        "Style price filter" "price-style.txt" "price filter style"
    commit_as "$BOB_NAME" "$BOB_EMAIL" 720 \
        "Add price filter tests" "price-tests.txt" "price filter tests"

    # --- behind-main moves on (two more Alice/Carol commits) ---
    git checkout behind-main --quiet
    commit_as "$ALICE_NAME" "$ALICE_EMAIL" 780 \
        "Add footer" "footer.txt" "footer"
    commit_as "$CAROL_NAME" "$CAROL_EMAIL" 840 \
        "Add contact page" "contact.txt" "contact"

    git checkout "$DEFAULT_BRANCH" --quiet
}

push_scenario_behind() {
    push_branches behind-main behind-feature
}

create_prs_behind() {
    pr_create "behind-main" "behind-feature" \
        "behind: Add price filter" \
        "Adds a price filter, its styles and tests. Written by Bob."
}
