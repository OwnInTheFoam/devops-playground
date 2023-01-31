# Bash scripting

## Check required installs
```bash
REQUIRED_CMDS="pwgen kubectl kubeseal flux kustomize git yq"
for CMD in $REQUIRED_CMDS; do
  if ! command -v "$CMD" &> /dev/null; then
      echo "${ERROR}$CMD could not be found!${NORMAL}"
      exit
  fi
done
```