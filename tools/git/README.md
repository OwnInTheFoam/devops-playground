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
git branch -a
git checkout origin/name-of-branch
```

