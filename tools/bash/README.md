# Bash scripting

## Check environment variables set
```bash
echo "[CHECK] Required environment variables"
REQUIRED_VARS=("K8S_CONTEXT")
for VAR in "${REQUIRED_VARS[@]}"; do
  if [[ -z "${!VAR}" ]]; then
    echo "  - $VAR is not set! Exiting..."
    exit
  else
    echo "  - $VAR is set. Value: ${!VAR}"
  fi
done
```

## Check and install require packages
With command -v:
```bash
echo "[CHECK] Check requirements installed"
REQUIRED_CMDS="pwgen kubectl kubeseal flux kustomize git yq"
for CMD in $REQUIRED_CMDS; do
  if ! command -v "$CMD" &> /dev/null; then
      echo "  - $CMD could not be found! Exiting..."
      exit
  else
    # Get package version
    VERSION=$("$CMD" -v 2>/dev/null)
    if [ -n "$VERSION" ]; then
      echo "  - $CMD is installed. Version: $VERSION"
    else
      VERSION=$("$CMD" --version 2>/dev/null)
      if [ -n "$VERSION" ]; then
        echo "  - $CMD is installed. Version: $VERSION"
      else
        VERSION=$("$CMD" version 2>/dev/null)
        if [ -n "$VERSION" ]; then
          echo "  - $CMD is installed. Version: $VERSION"
        else
          echo "  - $CMD is installed but version could not be determined."
        fi
      fi
    fi
  fi
done
```

With dpkg-query:
```bash
REQUIRED_PKG=("curl" "sed" "wget" "tar")
for ((i = 0; i < ${#REQUIRED_PKG[@]}; ++i)); do
  PKG_OK=$(dpkg-query -W --showformat='${Status}\n' ${REQUIRED_PKG[$i]}|grep "install ok installed")
  echo "Checking for ${REQUIRED_PKG[$i]}: $PKG_OK"
  if [ "" = "$PKG_OK" ]; then
    echo "No ${REQUIRED_PKG[$i]}. Setting up ${REQUIRED_PKG[$i]}."
    sudo apt update
    sudo apt -qq -y install ${REQUIRED_PKG[$i]}
  fi
done
```

## Make script executable
```bash
chmod 755 script.sh
```
Or
```bash
chmod u+x script.sh
```
Add change to git commit
```bash
git add --chmod=+x install.sh
```

## Run script with sudo permissions
```bash
sudo bash script.sh
```

## Execute sudo commands without password saved to command history
```bash
read -s -p "Enter your password: " myPassword
echo $myPassword | sudo -S shutdown now
```

## Append to a file
```bash
cat >>/path/file.md<<EOF
This will appended
EOF
```
Note, `sudo cat` will not work, use `tee` for sudo priveledges
```bash
echo 'This will appended' | sudo tee -a /path/file.md
```

## Overwrite a file
```bash
cat >/path/file.md<<EOF
This will appended
EOF
```

## Save an environment variable
Current terminals:
```bash
export ENV_VARIABLE=exists
```
Global and User terminals:
```bash
/etc/environment
$HOME/.bash_profile
$HOME/.profile
$HOME/.bashrc
```
