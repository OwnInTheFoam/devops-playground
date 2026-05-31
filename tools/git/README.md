# Git

## Installation
```bash
git --version
sudo apt update
sudo apt install git
```

## Configure git user
```bash
git config --global user.email "you@example.com"
git config --global user.name "Your Name"
```
Script to check for git user:
```bash
echo "[CHECK] Check git user configured"
if [[ -z "$(git config user.name)" ]]; then
  echo "  git user is not configured! Please configure with:"
  echo "  git config --global user.email "you@example.com""
  echo "  git config --global user.name "Your Name""
  echo "  Exiting..."
  exit
else
  echo "  git user.name is set. Value: $(git config user.name)"
fi
```

## Cloning
```bash
git clone https://github.com/OwnInTheFoam/devops-playground.git
```

## Checkout branch
```bash
git fetch
git branch -a -v
git switch name-of-branch
git switch -c name-of-new-branch
```

## Stage and snapshot
```bash
# show modified files in working directory, staged for your next commit
git status
# add a file as it looks now to your next commit (stage)
git add [file]
# unstage a file while retaining the changes in working directory
git reset [file]
# diff of what is changed but not staged
git diff
# diff of what is staged but not yet committed
git diff --staged
# commit your staged content as a new commit snapshot
git commit -m “[descriptive message]”
```

## Branch and merge
```bash
# list your branches. a * will appear next to the currently active branch
git branch
# create a new branch at the current commit
git branch [branch-name]
# switch to another branch and check it out into your working directory
#git checkout
git switch
# merge the specified branch’s history into the current one
git merge [branch]
# show all commits in the current branch’s history
git log
```

## Inspect and compare
```bash
# show the commit history for the currently active branch
git log
# show the commits on branchA that are not on branchB
git log branchB..branchA
# show the commits that changed file, even across renames
git log --follow [file]
# show the diff of what is in branchA that is not in branchB
git diff branchB...branchA
# show any object in Git in human-readable format
git show [SHA]
```

## Cherry Pick
```sh
git log <source-branch-name> --oneline
git cherry-pick abc1234
git status
git add <file-name>
git cherry-pick --continue
git cherry-pick --abort
```

## Tracking path changes
```bash
# delete the file from project and stage the removal for commit
git rm [file]
# change an existing file path and stage the move
git mv [existing-path] [new-path]
# show all commit logs with indication of any paths that moved
git log --stat -M
```

## Ignoring patterns
```bash
# Save a file with desired patterns as .gitignore with either direct string matches or wildcard globs.
logs/
*.notes
pattern*/
# system wide ignore pattern for all local repositories
git config --global core.excludesfile [file]
```

## Share and update
```bash
# add a git URL as an alias
git remote add [alias] [url]
# fetch down all the branches from that Git remote
git fetch [alias]
# merge a remote branch into your current branch to bring it up to date
git merge [alias]/[branch]
# Transmit local branch commits to the remote repository branch
git push [alias] [branch]
# fetch and merge any commits from the tracking remote branch
git pull
```

## Rewrite history
```bash
# apply any commits of current branch ahead of specified one
git rebase [branch]
# clear staging area, rewrite working tree from specified commit
git reset --hard [commit]
```

## Temporary commits
```bash
# Save modified and staged changes
git stash
# list stack-order of stashed file changes
git stash list
# write working from top of stash stack
git stash pop
# discard the changes from top of stash stack
git stash drop
# stash changes with untracked and specific files
git stash push -u -m "my-stash" README.md apps\\api\\README.md
```