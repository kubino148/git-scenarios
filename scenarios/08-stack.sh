#!/usr/bin/env bash
# 08-stack.sh — scenario "stack" (on demand): repair a stacked branch after a squash merge
# Sourced by scenarios.sh; defines build_scenario_stack.
# After squash-merge of stack-a into stack-main, student runs:
#   git rebase --onto origin/stack-main stack-a stack-b

build_scenario_stack() {
    # --- stack-main: Alice's task list ---
    git checkout -b stack-main --quiet
    commit_as "$ALICE_NAME" "$ALICE_EMAIL" 2400 \
        "Add task list" "tasks.txt" "task list"
    local main_tip
    main_tip=$(git rev-parse HEAD)

    # --- stack-a: two Bob commits modifying tasks.txt ---
    git checkout -b stack-a "$main_tip" --quiet 2>/dev/null
    commit_append "$BOB_NAME" "$BOB_EMAIL" 2460 \
        "Add priority column" "tasks.txt" "priority column"
    commit_append "$BOB_NAME" "$BOB_EMAIL" 2520 \
        "Show priority in list" "tasks.txt" "priority in list"
    local stack_a_tip
    stack_a_tip=$(git rev-parse HEAD)

    # --- stack-b: Carol sorts the tasks (from stack-a tip) ---
    git checkout -b stack-b "$stack_a_tip" --quiet 2>/dev/null
    # Carol reorders tasks.txt: sort the three lines alphabetically
    {
        printf 'priority column\n'
        printf 'priority in list\n'
        printf 'task list\n'
    } > tasks.txt
    local ts
    ts=$(( ROOT_TS + 2580 ))
    git add tasks.txt
    GIT_AUTHOR_NAME="$CAROL_NAME"    GIT_AUTHOR_EMAIL="$CAROL_EMAIL" \
    GIT_COMMITTER_NAME="$CAROL_NAME" GIT_COMMITTER_EMAIL="$CAROL_EMAIL" \
    GIT_AUTHOR_DATE="@${ts}"         GIT_COMMITTER_DATE="@${ts}" \
    git --no-pager commit --quiet -m "Sort tasks by priority"

    git checkout "$DEFAULT_BRANCH" --quiet
}

push_scenario_stack() {
    push_branches stack-main stack-a stack-b
}

create_prs_stack() {
    pr_create "stack-main" "stack-a" \
        "stack: Add priority column" \
        "Adds a priority column and shows it in the task list. Written by Bob."

    pr_create "stack-a" "stack-b" \
        "stack: Sort tasks by priority" \
        "Sorts the task list by priority. Written by Carol."
}
