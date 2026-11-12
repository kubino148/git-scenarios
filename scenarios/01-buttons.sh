#!/usr/bin/env bash
# 01-buttons.sh — scenario "buttons": predict and merge three pull requests
# Sourced by scenarios.sh; defines build_scenario_buttons.

build_scenario_buttons() {
    # --- buttons-main: two Alice commits ---
    git checkout -b buttons-main --quiet
    commit_as "$ALICE_NAME" "$ALICE_EMAIL" 60 \
        "Add project notes" "notes.txt" "project notes"
    commit_as "$ALICE_NAME" "$ALICE_EMAIL" 120 \
        "Add team list" "team.txt" "team list"
    local main_tip
    main_tip=$(git rev-parse HEAD)

    # --- buttons-login: two Bob commits from main tip ---
    git checkout -b buttons-login "$main_tip" --quiet 2>/dev/null
    commit_as "$BOB_NAME" "$BOB_EMAIL" 180 \
        "Add login form" "login.txt" "login form"
    commit_append "$BOB_NAME" "$BOB_EMAIL" 240 \
        "Validate login form" "login.txt" "validation"

    # --- buttons-search: two Bob commits from main tip ---
    git checkout -b buttons-search "$main_tip" --quiet 2>/dev/null
    commit_as "$BOB_NAME" "$BOB_EMAIL" 300 \
        "Add search box" "search.txt" "search box"
    commit_append "$BOB_NAME" "$BOB_EMAIL" 360 \
        "Style search box" "search.txt" "style"

    # --- buttons-help: two Bob commits from main tip ---
    git checkout -b buttons-help "$main_tip" --quiet 2>/dev/null
    commit_as "$BOB_NAME" "$BOB_EMAIL" 420 \
        "Add help page" "help.txt" "help page"
    commit_append "$BOB_NAME" "$BOB_EMAIL" 480 \
        "Link help page" "help.txt" "link"

    git checkout "$DEFAULT_BRANCH" --quiet
}

push_scenario_buttons() {
    push_branches buttons-main buttons-login buttons-search buttons-help
}

create_prs_buttons() {
    pr_create "buttons-main" "buttons-login" \
        "buttons: Add login form" \
        "Adds the login form and input validation. Written by Bob."

    pr_create "buttons-main" "buttons-search" \
        "buttons: Add search box" \
        "Adds a search box and its styles. Written by Bob."

    pr_create "buttons-main" "buttons-help" \
        "buttons: Add help page" \
        "Adds the help page and links it from the navigation. Written by Bob."
}
