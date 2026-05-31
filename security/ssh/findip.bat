@echo off
setlocal enabledelayedexpansion

for /L %%i in (1,1,254) do (
    set "ip=192.168.0.%%i"
    echo Trying !ip! ...
    
    ssh -p 22006 -o ConnectTimeout=1 -o BatchMode=yes -o StrictHostKeyChecking=no server6@!ip! exit
    if !errorlevel! equ 0 (
        echo ✅ Successful SSH connection to !ip!
        ssh -p 22006 server6@!ip!
        goto :eof
    ) else (
        echo ❌ Failed to connect to !ip!
    )
)

echo 🔍 Scan complete – no successful SSH connections found.
