# SSH

## Install ssh service
```bash
sudo systemctl status ssh
apt sudo update
sudo apt install openssh-server
sudo systemctl start ssh
```

## Change ssh port
```bash
sudo nano /etc/ssh/sshd_config
sudo ufw allow ${sshPort}/tcp
sudo systemctl restart ssh
```

## Allow password login
```bash
sudo sed -i 's/^.*PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo sed -i 's/^.*PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config
sudo systemctl reload sshd
```

## Connecting to ssh server
```bash
ssh USER@IPADDRESS -p PORT
```

## Generate ssh keys
```bash
ssh-keygen
```

## Copy public keys to other nodes
On client machine:
```bash
cat ${HOME}/.ssh/id_rsa.pub
```
On server machine:
```bash
nano ${HOME}/.ssh/authorized_keys
```

## Install sshpass
```bash
sudo apt install -qq -y sshpass >>${logFile} 2>&1
sshpass -p "${userPassword}" scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -P ${sshPort} root@server-1.local:/${HOME}/k8s/joincluster.sh /${HOME}/k8s/joincluster.sh >>${logFile}
```

## SSH shutdown cluster
Using ssh script:
```bash
cat >${HOME}/shutdowncluster.sh<<EOF
ssh -p 22 user@IPAddress 'shutdown now'
ssh -p 22 user@IPAddress 'shutdown now'
shutdown now
EOF
```
Using ssh script without root:
Firstly, ensure remote servers allow user to run sudo shutdown command without password.
This is require as the password cannot securely be passed through ssh.
sudo sed -i 'username ALL=(ALL) NOPASSWD: /sbin/shutdown now' /etc/sudoers
```bash
sudo visudo
username ALL=(ALL) NOPASSWD: /sbin/shutdown now
```
```bash
cat >${HOME}/shutdowncluster.sh<<EOF
read -s -p "Enter your password for user1: " user1Password
ssh -A -p 22 user2@IPAddress 'sudo shutdown now'
ssh -A -p 22 user3@IPAddress 'sudo shutdown now'
sudo -S shutdown now <<< "$user1Password"
EOF
```

Using service on power down:
```bash
sudo cat >/etc/systemd/system/clustershutdown.service<<EOF
[Unit]
Description=Shutdown all cluster nodes with ssh

[Service]
Type=oneshot
RemainAfterExit=true
ExecStop=<your script/program>

[Install]
WantedBy=basic.target
EOF
```
Then reload `systemd`:
```bash
sudo systemctl daemon-reload
sudo systemctl enable clustershutdown.service --now
sudo systemctl status clustershutdown
```

