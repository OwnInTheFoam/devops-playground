# SSH

## Install ssh service
```
systemctl status ssh
apt update
apt install openssh-server
systemctl start ssh
```

## Change ssh port
```
nano /etc/ssh/sshd_config
ufw allow ${sshPort}/tcp
systemctl restart ssh
```

## Allow password login
```
sed -i 's/^.*PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^.*PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config
systemctl reload sshd
```

## Connecting to ssh server
```
ssh USER@IPADDRESS -p PORT
```

## Generate ssh keys
```
ssh-keygen
```

## Copy public keys to other nodes
On client machine:
```
cat ${HOME}/.ssh/id_rsa.pub
```
On server machine:
```
nano ${HOME}/.ssh/authorized_keys
```

## Install sshpass
apt install -qq -y sshpass >>${logFile} 2>&1
sshpass -p "${userPassword}" scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -P ${sshPort} root@server-1.local:/${HOME}/k8s/joincluster.sh /${HOME}/k8s/joincluster.sh >>${logFile}

## SSH shutdown cluster
```
cat >/etc/systemd/system/clustershutdown.service<<EOF
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
```
systemctl daemon-reload
systemctl enable clustershutdown.service --now
systemctl status clustershutdown
```

