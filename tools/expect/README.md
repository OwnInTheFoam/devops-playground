# [Expect](https://phoenixnap.com/kb/linux-expect)

If you need to run a remote script containing `sudo` commands through SSH and securely provide the user password for `sudo`, you can use `expect` as discussed earlier. `Expect` is a scripting language that can automate interactive programs, such as providing passwords in response to prompts.

## Installation
```bash
expect -v
sudo apt update
sudo apt install expect
```

## Scripting
```bash
#!/usr/bin/expect

# By default expect has a timeout for 10s
set timeout 180

# Unset the environment variable when the script exits
expect_before {
    exit {
        set password {}
    }
}

# Read the remote sudo password securely
send_user "Enter remote sudo password: "
stty -echo
expect_user {
    -re "(.*)\n" {
        set password $expect_out(1,string)
        send_user "\n"
    }
}
stty echo

spawn ssh -t -p $sshPort -o "BatchMode yes" $sshUser@$sshIP "sudo -S ~/k8s/$script <<< $password"
expect {
    "password:" {
        send "$password\r"
    }
}
interact
```

The script will use `expect` to interact with the password prompt and securely provide the password to `sudo` during the remote script execution. Note that using `expect` to automate passwords can be less secure, as the password may be logged or visible in process lists. Always 
ensure that the script is run in a secure environment and that the script file is properly protected.

