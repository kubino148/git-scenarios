#!/usr/bin/env bash
# 04-replay.sh — scenario "replay": resolve a conflict in a rebase
# Sourced by scenarios.sh; defines build_scenario_replay.
# Designed resolution: keep the single line "Keep" (menu.txt: Open, Keep, Quit, Export).

build_scenario_replay() {
    # --- replay-main: Alice's base with a 3-line menu ---
    # shellcheck disable=SC2153  # BASE_SHA is set in lib.sh
    git checkout -b replay-main "$BASE_SHA" --quiet
    commit_multiline "$ALICE_NAME" "$ALICE_EMAIL" 1200 \
        "Add menu file" "menu.txt" "Open\nSave\nQuit"
    local base_sha
    base_sha=$(git rev-parse HEAD)

    # --- replay-feature: Bob renames Save→Keep, then adds Export ---
    git checkout -b replay-feature "$base_sha" --quiet 2>/dev/null
    commit_multiline "$BOB_NAME" "$BOB_EMAIL" 1260 \
        "Rename Save to Keep" "menu.txt" "Open\nKeep\nQuit"
    commit_multiline "$BOB_NAME" "$BOB_EMAIL" 1320 \
        "Add Export entry" "menu.txt" "Open\nKeep\nQuit\nExport"

    # --- replay-main moves: Carol renames Save→Store (conflicts with Bob's Keep) ---
    git checkout replay-main --quiet
    commit_multiline "$CAROL_NAME" "$CAROL_EMAIL" 1380 \
        "Rename Save to Store" "menu.txt" "Open\nStore\nQuit"

    git checkout "$DEFAULT_BRANCH" --quiet
}

push_scenario_replay() {
    push_branches replay-main replay-feature
}

create_prs_replay() {
    pr_create "replay-main" "replay-feature" \
        "replay: Rename Save to Keep" \
        "Renames the Save menu entry to Keep and adds an Export entry. Written by Bob."
}
