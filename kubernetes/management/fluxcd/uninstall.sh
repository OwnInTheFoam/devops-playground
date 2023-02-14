#!/bin/bash
# chmod u+x install.sh
# git add --chmod=+x install.sh

# DEFINES
DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
logFile="${DIR}/uninstall.log"
#logFile="/dev/null"

echo "[TASK 1] "

flux uninstall

echo "COMPLETE"
