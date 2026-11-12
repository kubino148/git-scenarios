# git-scenarios

Ten git practice scenarios. Each has its own branches and pull requests in your repo.

## Setup

```
git clone https://github.com/kubino148/git-scenarios ~/gs
bash ~/gs/scenarios.sh setup
```

The script ends with a short block: scenarios built, pull requests opened, the next step.
If `gh` did not open the pull requests, links appear at the end — open each and press "Create pull request".

**If the script says `no commit yet`**
Create the README on the repo page (Add file → Create new file → name it `README.md` → Commit changes), then open a Codespace.

**If you cannot open a Codespace on your repo**
Check that your repo has at least one commit with a README. Create the README as above, then come back to the main page and try again.

**If the script prints an error and stops**
Check that you are running the script in your fresh practice repo (name it `git-practice`, created with a README), not in another repo. The two lines above work in any Codespace terminal open on that repo.

## Scenarios

| id | goal |
|---|---|
| `buttons` | predict and merge three pull requests |
| `behind` | rebase a branch that is behind and push with a lease |
| `clash` | resolve a conflict in a merge |
| `replay` | resolve a conflict in a rebase |
| `hotfix` | cherry-pick two fix commits |
| `diverge` | handle a diverged git pull |
| `oops` | revert and restore commits with git reflog |
| `stack` | repair a stacked branch after a squash merge |
| `lease` | push after a teammate pushed first |
| `backport` | cherry-pick a commit that conflicts |

The first seven are built by `setup`. The last three are on demand:

```
bash ~/gs/scenarios.sh add stack
bash ~/gs/scenarios.sh add lease
bash ~/gs/scenarios.sh add backport
```

## Commands

```
bash ~/gs/scenarios.sh list              # see which scenarios are built
bash ~/gs/scenarios.sh graph <id>        # print the branch graph for one scenario
bash ~/gs/scenarios.sh reset <id>        # rebuild one scenario from scratch
bash ~/gs/scenarios.sh reset all         # rebuild all scenarios
```

`reset` aborts any rebase, merge or cherry-pick in progress, discards uncommitted changes, and rebuilds the scenario with new pull request numbers. Cards use pull request titles, so a reset never breaks a card.

## Tasks

1. Create a new repository with a README, open a Codespace on it and run the scenario script.
2. Predict, then merge three pull requests with the three merge buttons, and read the graph each leaves.
3. Rebase a branch that is behind and push it with --force-with-lease.
4. Resolve a conflict in a merge.
5. Resolve a conflict in a rebase.
6. Cherry-pick two commits from hotfix-main onto hotfix-release.
7. Run git pull on a diverged branch, read what git says, and put your commit on top of the remote.
8. Revert a bad commit that is already pushed; bring lost commits back with git reflog.
9. Cherry-pick a commit that conflicts (add the scenario with the script) and resolve the conflict.
10. Squash-merge a pull request that another pull request is built on (add the scenario with the script), then repair the second branch with `git rebase --onto origin/stack-main stack-a stack-b`.
11. Push a rebase with --force-with-lease after a teammate pushed first (add the scenario with the script).

## Local mode (no GitHub account needed)

If `gh pr create` fails, or if you have no GitHub remote, run setup in local mode. It creates a bare repo on disk as origin:

```
bash ~/gs/scenarios.sh setup --local
```

Everything works (push, rejected push, divergent pull, `--force-with-lease`) except the pull-request clicks. For Step 1 follow the instructor's screen.

You can also run local mode in an existing tasks-app Codespace — it writes nothing inside the app repo:

```
bash ~/gs/scenarios.sh setup --local ~/practice
```

## If gh did not open the pull requests

The script ends with links of the form:

```
https://github.com/<owner>/<repo>/compare/buttons-main...buttons-login?quick_pull=1
```

Open each link in a browser and press "Create pull request". Only the three `buttons` links are needed during class. The other scenarios work without pull requests on GitHub.
