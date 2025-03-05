# bitcoin-core

## FluxCD Helm Chart
- [Bitcoin-core](https://github.com/hirosystems/charts/tree/main/hirosystems/bitcoin-core)

```sh
export BT_VER=2.1.6
export K8S_CONTEXT=kubernetes
export CLUSTER_REPO=gitops

mkdir -p /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/apps/sources
mkdir -p /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/apps/bitcoin-core

sudo flux create source helm bitcoin-core \
 --url="https://charts.hiro.so/hirosystems" \
 --interval=2h \
 --export > "/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/apps/sources/bitcoin-core.yaml"

cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/apps/sources
rm -f kustomization.yaml
kustomize create --namespace="flux-system" --autodetect --recursive
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/apps
rm -f kustomization.yaml
kustomize create --namespace="flux-system" --autodetect --recursive

cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "bitcoin-core create source helm"
git push

sudo flux reconcile source git "flux-system"
sleep 10
while sudo flux get all -A | grep -q "Unknown" ; do
  echo "System not ready yet, waiting anoher 10 seconds"
  sleep 10
done

mkdir -p /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/bitcoin-core/

helm repo add bitcoin-core https://charts.hiro.so/hirosystems
helm repo update
#helm search hub --max-col-width 80 bitcoin-core | grep "bitcoin-core"
#helm search repo bitcoin-core/bitcoin-core --versions
helm show values bitcoin-core/bitcoin-core --version ${BT_VER} > /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/bitcoin-core/bitcoin-core-values.yaml
#helm upgrade --install bitcoin-core bitcoin-core/bitcoin-core -n bitcoin-core --create-namespace
#helm install bitcoin-core bitcoin-core/bitcoin-core --version 2.1.6 --values ~/bitcoin-core-values.yaml --namespace bitcoin-core --create-namespace
helm repo remove bitcoin-core

cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "bitcoin-core helm default values"
git push

#yq -i '.enabled=false' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/bitcoin-core/bitcoin-core-values.yaml

mkdir -p /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/apps/bitcoin-core/bitcoin-core
mkdir -p /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/apps/bitcoin-core/bitcoin-core/bitcoin-core

cat>"${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/apps/bitcoin-core/namespace.yaml"<<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: bitcoin-core
EOF

sudo flux create helmrelease bitcoin-core \
	--interval=2h \
	--release-name=bitcoin-core \
	--source=HelmRepository/bitcoin-core \
	--chart-version=${BT_VER} \
	--chart=bitcoin-core \
	--namespace=flux-system \
	--target-namespace=bitcoin-core \
  --values=/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/bitcoin-core/bitcoin-core-values.yaml \
  --create-target-namespace \
  --crds=CreateReplace \
  --export > /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/apps/bitcoin-core/bitcoin-core/bitcoin-core.yaml

cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/apps/bitcoin-core/bitcoin-core

yq e -i '.spec.chart.spec.sourceRef.namespace = "flux-system"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/apps/bitcoin-core/bitcoin-core/bitcoin-core.yaml

cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/apps/bitcoin-core/bitcoin-core/
rm -f kustomization.yaml
kustomize create --autodetect --recursive
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/apps/bitcoin-core/
rm -f kustomization.yaml
kustomize create  --autodetect --recursive
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/apps/
rm -f kustomization.yaml
kustomize create --autodetect --recursive

cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "bitcoin-core deployment"
git push

sudo flux reconcile source git "flux-system"
sleep 10
while sudo flux get all -A | grep -q "Unknown" ; do
  echo "System not ready yet, waiting anoher 10 seconds"
  sleep 10
done

```

## bitcoin-qt setup

### Testnet
Launching
```sh
# GUI
/usr/local/bin/bitcoin-qt -testnet
# Daemon
bitcoind -testnet -daemon
```

Create desktop shortcut
```sh
cd ~/Downloads
wget https://github.com/bitcoin/bitcoin/raw/master/share/pixmaps/bitcoin64.png
sudo mkdir -p /usr/local/share/icons/
sudo mv bitcoin64.png /usr/local/share/icons/

cat >> ~/Desktop/bitcoind-testnet.desktop <<EOF
[Desktop Entry]
Version=1.0
Name=Bitcoin Core Testnet
Comment=Launch Bitcoin Core in Testnet mode
Exec=/usr/local/bin/bitcoind -testnet -daemon
Icon=/usr/local/share/icons/bitcoin64.png
Terminal=false
Type=Application
Categories=Finance;Network;
EOF

chmod +x ~/Desktop/bitcoind-testnet.desktop

cp ~/Desktop/bitcoind-testnet.desktop ~/.local/share/applications/
```

Auto launch on startup
 ```sh
# Following is for graphical applications like Bitcoin Core Qt
#mkdir -p ~/.config/autostart/
#cp ~/.local/share/applications/bitcoind-testnet.desktop ~/.config/autostart/
```
Alternatively, Launch `Startup Applications` and Add:
```sh
#Name: BitcoinCoreTestnet
#Command: /usr/local/bin/bitcoind -testnet -daemon
```
Or for daemon, 
```sh
#sudo chown -R server6:server6 /home/server6/.bitcoin/testnet3
#sudo chmod -R 700 /home/server6/.bitcoin/testnet3

sudo nano /etc/systemd/system/bitcoind-testnet.service
cat >> /etc/systemd/system/bitcoind-testnet.service <<EOF
[Unit]
Description=Bitcoin Core Testnet Daemon
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/bin/bitcoind -testnet -daemon -rpcbind=127.0.0.1 -rpcbind=0.0.0.0 -rpcport=18332 -rpcallowip=127.0.0.1 -rpcallowip=192.168.0.0/24
ExecStop=/usr/local/bin/bitcoin-cli -testnet stop
Restart=on-failure
User=server6
Group=server6
StandardOutput=journal
StandardError=journal
TimeoutStartSec=300
TimeoutStopSec=300

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable bitcoind-testnet.service
sudo systemctl start bitcoind-testnet.service
sudo systemctl status bitcoind-testnet.service
```

In `~/.bashrc` add following
```sh
# Increase open file descriptors
ulimit -n 4096
```

Then restart the machine and check RPC is running:
```sh
# Gracefully shutdown bitcoin core
bitcoin-cli -testnet stop
# Wait for log
tail -f ~/.bitcoin/testnet3/debug.log
# Restart
sudo shutdown now -r

# Look for "Binding RPC on address 127.0.0.1 port 18332"
grep -i rpc ~/.bitcoin/testnet3/debug.log

bitcoin-cli -testnet getblockchaininfo
```

#### RPC communications

Within `~/.bitcoin/bitcoin.conf` apply following:
```conf
server=1
[test]
debug=rpc
rpcbind=0.0.0.0  # Bind all network interfaces
rpcallowip=192.168.0.0/24  # Allow connections from the local network
rpcport=18332
#rpcbind=127.0.0.1  # Bind to localhost
#rpcallowip=127.0.0.1  # Allow connections from localhost
rpcuser=rpc_username
rpcpassword=rpc_password
fallbackfee=0.00001
paytxfee=0.00001
mintxfee=0.000005
maxtxfee=0.1
```

Restart node:
```sh
# Gracefully shutdown bitcoin core
bitcoin-cli -testnet stop
# Wait for log
tail -f ~/.bitcoin/testnet3/debug.log
# Start bitcoin core
bitcoind -daemon -testnet
```

#### Security
##### Firwall
```sh
# Allow all localhost connections that will be used to communicate server
sudo ufw allow from 192.168.0.215 to any port 18332
sudo ufw allow from 192.168.0.223 to any port 18332
sudo ufw allow from 192.168.0.224 to any port 18332
sudo ufw allow from 192.168.0.225 to any port 18332
sudo ufw allow from 192.168.0.226 to any port 18332
sudo ufw allow from 192.168.0.227 to any port 18332
# Deny all others
sudo ufw deny 18332
# Status
sudo ufw reload
sudo ufw status
```

### Mainnet
Launching
```sh
# GUI
/usr/local/bin/bitcoin-qt
# Daemon
bitcoind -daemon
```

Create desktop shortcut
```sh
cd ~/Downloads
wget https://github.com/bitcoin/bitcoin/raw/master/share/pixmaps/bitcoin64.png
sudo mkdir -p /usr/local/share/icons/
sudo mv bitcoin64.png /usr/local/share/icons/

cat >> ~/Desktop/bitcoin-qt.desktop <<EOF
[Desktop Entry]
Version=1.0
Name=Bitcoin Core Mainnet
Comment=Launch Bitcoin Core in Mainnet mode
Exec=/usr/local/bin/bitcoin-qt
Icon=/usr/local/share/icons/bitcoin64.png
Terminal=false
Type=Application
Categories=Finance;Network;
EOF

chmod +x ~/Desktop/bitcoin-qt.desktop

cp ~/Desktop/bitcoin-qt.desktop ~/.local/share/applications/
```

Auto launch on startup
```sh
#mkdir -p ~/.config/autostart/
#cp ~/.local/share/applications/bitcoin-qt.desktop ~/.config/autostart/
```
Alternatively, Launch `Startup Applications` and Add:
```sh
#Name: BitcoinCoreTestnet
#Command: /usr/local/bin/bitcoin-qt
```
Or for daemon, 
```sh
sudo nano /etc/systemd/system/bitcoind.service
cat >> /etc/systemd/system/bitcoind.service <<EOF
[Unit]
Description=Bitcoin Core Daemon
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/bin/bitcoind -daemon
ExecStop=/usr/local/bin/bitcoin-cli stop
Restart=on-failure
User=server5
Group=server5
StandardOutput=journal
StandardError=journal
TimeoutStartSec=300
TimeoutStopSec=300

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable bitcoind.service
sudo systemctl start bitcoind.service
sudo systemctl status bitcoind.service
```

In `~/.bashrc` add following
```sh
# Increase open file descriptors
ulimit -n 4096
```

Then restart the machine and check RPC is running:
```sh
# Gracefully shutdown bitcoin core
bitcoin-cli stop
# Wait for log
tail -f ~/.bitcoin/debug.log
# Restart
sudo shutdown now -r

# Look for "Binding RPC on address 127.0.0.1 port 8332"
grep -i rpc ~/.bitcoin/debug.log

bitcoin-cli getblockchaininfo
```

#### RPC communications

Within `~/.bitcoin/bitcoin.conf` apply following:
```conf
server=1
rpcport=8332
rpcbind=0.0.0.0
rpcallowip=192.168.0.0/24
rpcuser=your_rpc_username
rpcpassword=your_rpc_password
fallbackfee=0.00001
paytxfee=0.00001
mintxfee=0.000005
maxtxfee=0.1
```
Restart node:
```sh
# Gracefully shutdown bitcoin core
bitcoin-cli stop
#bitcoin-cli -rpcconnect=192.168.0.224 -rpcport=8332 -rpcuser=Professor -rpcpassword=bitcoin$ stop
# Wait for log
tail -f ~/.bitcoin/debug.log
# Relaunch
bitcoind -daemon
```

#### Security
##### Firwall
```sh
# Allow all localhost connections that will be used to communicate server
sudo ufw allow from 192.168.0.215 to any port 8332
sudo ufw allow from 192.168.0.225 to any port 8332
sudo ufw allow from 192.168.0.226 to any port 8332
sudo ufw allow from 192.168.0.227 to any port 8332
# Deny all others
sudo ufw deny 8332
# Status
sudo ufw reload
sudo ufw status
```

##### Encryption
Enable SSL Encryption for RPC

## Connecting to bitcoin core

### Development

Use a ssh tunnel
```sh
ssh -L 18332:local_ip:18332 user@public_ip -p port
ssh -f -N -L 18332:localhost:18332 -p 22006 server6@110.151.44.98
ps aux grep ssh

bitcoin-cli -rpcconnect=$BITCOINCORE_HOST -rpcport=$BITCOINCORE_PORT -rpcuser=$BITCOINCORE_RPCUSER -rpcpassword=$BITCOINCORE_RPCPASSWORD getblockchaininfo

bitcoin-cli -testnet -rpcconnect=192.168.0.223 -rpcport=18332 -rpcuser=Professor -rpcpassword=bitcoin$ getblockchaininfo
```

## Usage

```sh
# Wallet creation
bitcoin-cli -testnet createwallet "mywallet"
bitcoin-cli -testnet -rpcwallet="mywallet" getwalletinfo
bitcoin-cli -testnet listwallets
bitcoin-cli -testnet createwallet "watchonly" true

# Check wallet
ls ~/.bitcoin/testnet3/wallets

# Export wallet
bitcoin-cli -testnet -rpcwallet="mywallet" backupwallet "/home/user/wallet-backups/mywallet.dat"
bitcoin-cli -testnet -rpcwallet="mywallet" dumpwallet "/home/user/wallet-backups/mywallet-keys.txt"

```

### HD wallets

Add following to your bitcoin.conf
```sh
wallet=hdwallet.dat
```
