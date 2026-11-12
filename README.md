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

1. Create a new repository with a README, open a Codespace on it and run the scenario script.
2. Predict, then merge three pull requests with the three merge buttons, and read the graph each leaves.
3. Rebase a branch that is behind and push it with --force-with-lease.
4. Resolve a conflict in a merge.
5. Resolve a conflict in a rebase.
6. Cherry-pick two commits from hotfix-main onto hotfix-release.
7. Run git pull on a diverged branch, read what git says, and put your commit on top of the remote.
8. Revert a bad commit that is already pushed; bring lost commits back with git reflog.
9. Cherry-pick a commit that conflicts (add the scenario with the script) and resolve the conflict.
10. Squash-merge a pull request that another pull request is built on (add the scenario with the script), then repair the second branch.
11. Push a rebase with --force-with-lease after a teammate pushed first (add the scenario with the script).

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
