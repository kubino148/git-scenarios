# git-scenarios

Ten git practice scenarios. Each has its own branches and pull requests in your repo.

## Before you start

1. On GitHub, create a new repository named `git-practice` with Add README turned on. The Codespace needs at least one commit.
2. Open a Codespace on that repository: on the repository page choose Code, then Codespaces, then create a codespace on main.
3. In the terminal of that Codespace run the two lines below.

The clone goes to `~/gs`, outside your repository, so the script never lands in your repo. `setup` builds the branches and pull requests in the repository the terminal is open on.

## Setup

```
git clone https://github.com/kubino148/git-scenarios ~/gs
bash ~/gs/scenarios.sh setup
```

The script ends with a short block: scenarios built, pull requests opened, the next step.
If `gh` did not open the pull requests, links appear at the end: open each one and create the pull request from that page.

**If the script says `no commit yet`**
Create a new file named README.md on the repo page, then commit it. Then open the Codespace and run the two lines.

**If you cannot open a Codespace on your repo**
Check that your repo has at least one commit with a README. Create the README as above, then come back to the main page and try again.

**If the script prints an error and stops**
Check that you are running the script in your fresh practice repo (`git-practice`, created with a README), not in another repo. Fix what the error says and run `bash ~/gs/scenarios.sh setup` again. After a stop in the middle (Ctrl+C, a stopped Codespace) it cleans up what the first run left and builds again.

## Scenarios

Every scenario has its own branches. Switch to the start branch, do the task, then look at the graph with `bash ~/gs/scenarios.sh graph <id>` or `git log --graph --oneline`.

| id | start on | you practise | pull requests on GitHub |
|---|---|---|---|
| `buttons` | `buttons-main` | the three merge buttons: merge commit, squash, rebase; reading the graph each leaves | yes, three |
| `behind` | `behind-feature` | rebase a branch that is behind; push with a lease | yes |
| `clash` | `clash-feature` | a conflict in a merge: read the markers, finish the merge | yes |
| `replay` | `replay-feature` | a conflict in a rebase: resolve, continue, replayed commits get new ids | yes |
| `hotfix` | `hotfix-release` | cherry-pick: copy two fix commits to a release branch | no |
| `diverge` | `diverge-main` | `git pull` on a diverged branch: read the message, then choose | no |
| `oops` | `oops-main` | revert a pushed commit; reset a branch; find lost commits with the reflog | no |
| `stack` | `stack-b` | a branch built on another branch whose pull request was squashed | yes, two |
| `lease` | `lease-feature` | a push refused with a lease because a teammate pushed first | no |
| `backport` | `backport-release` | cherry-pick a commit that conflicts | no |

## Where to practise what

| If you want to understand | Use |
|---|---|
| merge versus rebase versus squash, and what a linear history is | `buttons`, then `replay` |
| why a rebased branch needs a force push, and how to do it safely | `behind`, then `lease` |
| conflicts: where the markers are and what each side is | `clash` (merge), then `replay` (rebase), then `backport` (cherry-pick) |
| cherry-pick: when to copy a commit instead of merging a branch | `hotfix`, then `backport` |
| the "divergent branches" message of `git pull` | `diverge` |
| undoing things: revert, reset and getting commits back | `oops` |
| pull requests that depend on each other | `stack` |

If you only have a few minutes, take them in this order: `buttons`, `behind`, `clash`, `replay`, `hotfix`. Repeat any scenario as often as you like with `reset <id>`.

The first seven scenarios are built by `setup`. The last three are on demand:

```
bash ~/gs/scenarios.sh add stack
bash ~/gs/scenarios.sh add lease
bash ~/gs/scenarios.sh add backport
```

`add` switches to your default branch first and ends with the branch to switch to. It refuses while a rebase, merge or cherry-pick is in progress or while you have uncommitted changes.

## Commands

```
bash ~/gs/scenarios.sh list              # see which scenarios are built
bash ~/gs/scenarios.sh graph <id>        # print the branch graph for one scenario
bash ~/gs/scenarios.sh reset <id>        # rebuild one scenario from scratch
bash ~/gs/scenarios.sh reset all         # rebuild all scenarios
```

`reset` checks the id first (a mistyped id changes nothing). Then it says that it discards uncommitted changes and untracked files in the folder, aborts any rebase, merge or cherry-pick in progress, rebuilds the scenario, prints the new pull request numbers where the scenario has pull requests, and ends with the branch to switch to. Cards use pull request titles, so a reset never breaks a card.

The script keeps its own notes inside `.git`, so `git status` shows only your changes.

## Tasks

Each task names the scenario and the branch to start on. The last line says what you should see when it is done.

1. Create a new repository with a README, open a Codespace on it and run the scenario script. Done when the script ends with a block that says what was built.
2. Scenario `buttons`: predict, then merge three pull requests with the three merge buttons, and read the graph each leaves. Done when `git log --graph --oneline` on `buttons-main` shows what each button did.
3. Scenario `behind`, branch `behind-feature`: rebase a branch that is behind and push it with `--force-with-lease`. Done when the log is one straight line and the push went through.
4. Scenario `clash`, branch `clash-feature`: resolve a conflict in a merge. Done when the merge commit is on top, the file has no markers left and `git status` is clean.
5. Scenario `replay`, branch `replay-feature`: resolve a conflict in a rebase. Done when no rebase is in progress and the log is one straight line.
6. Scenario `hotfix`, branch `hotfix-release`: cherry-pick two commits from `hotfix-main`. Done when `bash ~/gs/scenarios.sh graph hotfix` shows two copies on the release line and `hotfix-main` unchanged.
7. Scenario `diverge`, branch `diverge-main`: run `git pull` on a diverged branch, read what git says, and put your commit on top of the remote. Done when `git status -sb` shows one commit ahead and none behind.
8. Scenario `oops`, branch `oops-main`: revert a bad commit that is already pushed, then bring lost commits back with the reflog. Done when you can name the commit you went back to.
9. Scenario `backport` (add it with the script), branch `backport-release`: cherry-pick a commit that conflicts and resolve the conflict. Done when the pick is finished and the file has no markers left.
10. Scenario `stack` (add it with the script): squash-merge a pull request that another pull request is built on, then repair the second branch. Done when `git log --oneline origin/stack-main..stack-b` lists only the commits of the second branch.
11. Scenario `lease` (add it with the script), branch `lease-feature`: push a rebase with `--force-with-lease` after a teammate pushed first. Done when your push went through and the teammate's commit is still on the branch.

## Local mode (no GitHub account needed)

If `gh pr create` fails, or if you have no GitHub remote, run setup in local mode. It creates a bare repo on disk as origin and the practice repo in `~/practice`:

```
bash ~/gs/scenarios.sh setup --local
cd ~/practice
```

Everything works (push, rejected push, divergent pull, `--force-with-lease`) except the pull-request clicks. For Step 1 follow the instructor's screen.

Run it once. A second `setup --local` refuses, so your work stays. To delete the folder with everything in it and build it again, add `--rebuild`.

You can also run local mode in an existing tasks-app Codespace — it writes nothing inside the app repo:

```
bash ~/gs/scenarios.sh setup --local ~/practice
```

## If gh did not open the pull requests

The script ends with links of the form:

```
https://github.com/<owner>/<repo>/compare/buttons-main...buttons-login?quick_pull=1
```

Open each link in a browser and create the pull request from that page. Only the three `buttons` links are needed during class. The other scenarios work without pull requests on GitHub.
