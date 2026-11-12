#!/usr/bin/env bash
# 06-diverge.sh — scenario "diverge": handle a diverged git pull
# Sourced by scenarios.sh; defines build_scenario_diverge.
# After build: origin/diverge-main has 3 commits (install, usage, license).
# Local diverge-main is at usage + local "Add example" (Dana) → 1 ahead, 1 behind.

build_scenario_diverge() {
    # --- diverge-main: three pushed commits ---
    git checkout -b diverge-main --quiet
    commit_as "$ALICE_NAME" "$ALICE_EMAIL" 1800 \
        "Add install notes" "install.txt" "install notes"
    commit_as "$ALICE_NAME" "$ALICE_EMAIL" 1860 \
        "Add usage section" "usage.txt" "usage section"
    local usage_sha
    usage_sha=$(git rev-parse HEAD)
    commit_as "$BOB_NAME" "$BOB_EMAIL" 1920 \
        "Add license note" "license.txt" "license note"

    git checkout "$DEFAULT_BRANCH" --quiet
}

push_scenario_diverge() {
    push_branches diverge-main
}

# Called after all branches are pushed; sets up the local diverge state.
finalize_diverge() {
    local usage_sha
    usage_sha=$(git --no-pager log diverge-main --oneline | \
        grep "Add usage section" | head -1 | cut -d' ' -f1)
    if [ -z "$usage_sha" ]; then
        return 0  # bail gracefully; test will catch the wrong state
    fi
    git checkout diverge-main --quiet
    git reset --hard "$usage_sha" --quiet 2>/dev/null || true
    commit_as "$DANA_NAME" "$DANA_EMAIL" 1980 \
        "Add example" "example.txt" "example usage"
    git checkout "$DEFAULT_BRANCH" --quiet
    # Note: origin/diverge-main tracking ref still points to license-note commit.
    # Local diverge-main is at usage + example → 1 ahead, 1 behind.
}

# No pull requests for this scenario
create_prs_diverge() { return 0; }
