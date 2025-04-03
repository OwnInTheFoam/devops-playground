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

### Installing
```bash
# Download the binary
wget https://bitcoincore.org/bin/bitcoin-core-28.1/bitcoin-28.1-x86_64-linux-gnu.tar.gz
# Verify download
wget https://bitcoincore.org/bin/bitcoin-core-28.1/SHA256SUMS
wget https://bitcoincore.org/bin/bitcoin-core-28.1/SHA256SUMS.asc
sha256sum --check SHA256SUMS --ignore-missing
mkdir builder-keys && cd builder-keys
for key in 0xb10c CoinForensics Emzy Sjors TheCharlatan achow101 benthecarman cfields darosior davidgumberg dunxen fanquake glozow guggero hebasto ismaelsadeeq jackielove4u josibake kvaciral laanwj luke-jr m3dwards pinheadmz satsie sipa sipsorcery svanstaa theStack vertiond willcl-ark willyko; do wget "https://raw.githubusercontent.com/bitcoin-core/guix.sigs/main/builder-keys/$key.gpg"; done
gpg --import *
cd ../
gpg --verify SHA256SUMS.asc
# Extract binary
tar -xzf bitcoin-28.1-x86_64-linux-gnu.tar.gz
sudo cp bitcoin-28.0/bin/* /usr/local/bin/
# Check
bitcoind --version
bitcoind -chain=main -daemon
tail -f ~/.bitcoin/debug.log
bitcoin-cli -chain=main getblockchaininfo
bitcoin-cli -chain=main stop
```

### Testnet3
Launching
```sh
# GUI
/usr/local/bin/bitcoin-qt -chain=testnet3
# Daemon
bitcoind -chain=testnet3 -daemon
```

Create desktop shortcut
```sh
cd ~/Downloads
wget https://github.com/bitcoin/bitcoin/raw/master/share/pixmaps/bitcoin64.png
sudo mkdir -p /usr/local/share/icons/
sudo mv bitcoin64.png /usr/local/share/icons/

cat >> ~/Desktop/bitcoind-testnet3.desktop <<EOF
[Desktop Entry]
Version=1.0
Name=Bitcoin Core Testnet3
Comment=Launch Bitcoin Core in Testnet3 mode
Exec=/usr/local/bin/bitcoin-qt -chain=testnet3 -daemon
Icon=/usr/local/share/icons/bitcoin64.png
Terminal=false
Type=Application
Categories=Finance;Network;
EOF

chmod +x ~/Desktop/bitcoind-testnet3.desktop

cp ~/Desktop/bitcoind-testnet3.desktop ~/.local/share/applications/
```

Auto launch on startup
 ```sh
# Following is for graphical applications like Bitcoin Core Qt
#mkdir -p ~/.config/autostart/
#cp ~/.local/share/applications/bitcoind-testnet3.desktop ~/.config/autostart/
```
Alternatively, Launch `Startup Applications` and Add:
```sh
#Name: BitcoinCoreTestnet
#Command: /usr/local/bin/bitcoind -chain=testnet3 -daemon
```
Or for daemon, 
```sh
#sudo chown -R server6:server6 /home/server6/.bitcoin/testnet3
#sudo chmod -R 700 /home/server6/.bitcoin/testnet3

sudo nano /etc/systemd/system/bitcoind-testnet3.service
cat >> /etc/systemd/system/bitcoind-testnet3.service <<EOF
[Unit]
Description=Bitcoin Core Testnet3 Daemon
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/bin/bitcoind -chain=testnet3 -daemon -rpcbind=0.0.0.0 -rpcport=18332 -rpcallowip=192.168.0.0/24
ExecStop=/usr/local/bin/bitcoin-cli -chain=testnet3 stop
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
sudo systemctl enable bitcoind-testnet3.service
sudo systemctl start bitcoind-testnet3.service
sudo systemctl status bitcoind-testnet3.service
```

In `~/.bashrc` add following
```sh
# Increase open file descriptors
ulimit -n 4096
```

Then restart the machine and check RPC is running:
```sh
# Gracefully shutdown bitcoin core
bitcoin-cli -chain=testnet3 stop
# Wait for log
tail -f ~/.bitcoin/testnet3/debug.log
# Restart
sudo shutdown now -r

# Look for "Binding RPC on address 127.0.0.1 port 18332"
grep -i rpc ~/.bitcoin/testnet3/debug.log

bitcoin-cli -chain=testnet3 getblockchaininfo
```

#### RPC communications

Within `~/.bitcoin/bitcoin.conf` apply following:
```conf
server=1
chain=testnet3
[testnet3]
debug=rpc
rpcbind=0.0.0.0
rpcallowip=192.168.0.0/24
rpcport=18332
rpcuser=rpc_username
rpcpassword=rpc_password
wallet=watchonly
fallbackfee=0.00001
paytxfee=0.00001
mintxfee=0.000005
maxtxfee=0.1
```

Restart node:
```sh
# Gracefully shutdown bitcoin core
bitcoin-cli -chain=testnet3 stop
# Wait for log
tail -f ~/.bitcoin/testnet3/debug.log
# Start bitcoin core
bitcoind -daemon -chain=testnet3
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

### Testnet4
Launching
```sh
# GUI
/usr/local/bin/bitcoin-qt -chain=testnet4
# Daemon
bitcoind -chain=testnet4 -daemon
```

Create desktop shortcut
```sh
cd ~/Downloads
wget https://github.com/bitcoin/bitcoin/raw/master/share/pixmaps/bitcoin64.png
sudo mkdir -p /usr/local/share/icons/
sudo mv bitcoin64.png /usr/local/share/icons/

cat >> ~/Desktop/bitcoin-qt-testnet4.desktop <<EOF
[Desktop Entry]
Version=1.0
Name=Bitcoin Core Testnet4
Comment=Launch Bitcoin Core in Testnet4 mode
Exec=/usr/local/bin/bitcoin-qt -chain=testnet4
Icon=/usr/local/share/icons/bitcoin64.png
Terminal=false
Type=Application
Categories=Finance;Network;
EOF

chmod +x ~/Desktop/bitcoin-qt-testnet4.desktop

cp ~/Desktop/bitcoin-qt-testnet4.desktop ~/.local/share/applications/
```

Auto launch on startup
 ```sh
# Following is for graphical applications like Bitcoin Core Qt
#mkdir -p ~/.config/autostart/
#cp ~/.local/share/applications/bitcoind-testnet4.desktop ~/.config/autostart/
```
Alternatively, Launch `Startup Applications` and Add:
```sh
#Name: BitcoinCoreTestnet4
#Command: /usr/local/bin/bitcoind -chain=testnet4 -daemon
```
Or for daemon, 
```sh
#sudo chown -R server5:server5 /home/server5/.bitcoin/testnet4
#sudo chmod -R 700 /home/server5/.bitcoin/testnet4

sudo nano /etc/systemd/system/bitcoind-testnet4.service
cat >> /etc/systemd/system/bitcoind-testnet4.service <<EOF
[Unit]
Description=Bitcoin Core Testnet4 Daemon
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/bin/bitcoind -chain=testnet4 -daemon -rpcbind=0.0.0.0 -rpcport=48332 -rpcallowip=192.168.0.0/24
ExecStop=/usr/local/bin/bitcoin-cli -chain=testnet4 stop
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
sudo systemctl enable bitcoind-testnet4.service
sudo systemctl start bitcoind-testnet4.service
sudo systemctl status bitcoind-testnet4.service
```

In `~/.bashrc` add following
```sh
# Increase open file descriptors
ulimit -n 4096
```

Then restart the machine and check RPC is running:
```sh
# Gracefully shutdown bitcoin core
bitcoin-cli -chain=testnet4 stop
# Wait for log
tail -f ~/.bitcoin/testnet4/debug.log
# Restart
sudo shutdown now -r

# Look for "Binding RPC on address 127.0.0.1 port 48332"
grep -i rpc ~/.bitcoin/testnet4/debug.log

bitcoin-cli -chain=testnet4 getblockchaininfo
```

#### RPC communications

Within `~/.bitcoin/bitcoin.conf` apply following:
```conf
server=1
chain=testnet4
[testnet4]
debug=rpc
rpcbind=0.0.0.0
rpcallowip=192.168.0.0/24
rpcport=48332
rpcuser=rpc_username
rpcpassword=rpc_password
wallet=watchonly
fallbackfee=0.00001
paytxfee=0.00001
mintxfee=0.000005
maxtxfee=0.1
```

Restart node:
```sh
# Gracefully shutdown bitcoin core
bitcoin-cli -chain=testnet4 stop
# Wait for log
tail -f ~/.bitcoin/testnet4/debug.log
# Start bitcoin core
bitcoind -daemon -chain=testnet4
```

#### Security
##### Firwall
```sh
# Allow all localhost connections that will be used to communicate server
#sudo ufw allow from 192.168.0.215 to any port 48332
#sudo ufw allow from 192.168.0.223 to any port 48332
#sudo ufw allow from 192.168.0.224 to any port 48332
#sudo ufw allow from 192.168.0.225 to any port 48332
#sudo ufw allow from 192.168.0.226 to any port 48332
#sudo ufw allow from 192.168.0.227 to any port 48332
sudo ufw allow from 192.168.0.0/24 to any port 48332
# Deny all others
#sudo ufw deny 48332
sudo ufw default deny incoming
sudo ufw default allow outgoing
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
ExecStart=/usr/local/bin/bitcoind -daemon -rpcbind=0.0.0.0 -rpcport=8332 -rpcallowip=192.168.0.0/24
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
wallet=watchonly
fallbackfee=0.00001
paytxfee=0.00001
mintxfee=0.000005
maxtxfee=0.1
```
Restart node:
```sh
# Gracefully shutdown bitcoin core
bitcoin-cli stop
#bitcoin-cli -rpcconnect=192.168.0.224 -rpcport=8332 -rpcuser=add -rpcpassword=add stop
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
ssh -L 48332:local_ip:48332 user@public_ip -p port
ssh -f -N -L 48332:localhost:48332 -p 22006 server6@110.151.44.98
ps aux grep ssh

bitcoin-cli -rpcconnect=$BITCOINCORE_HOST -rpcport=$BITCOINCORE_PORT -rpcuser=$BITCOINCORE_RPCUSER -rpcpassword=$BITCOINCORE_RPCPASSWORD getblockchaininfo

bitcoin-cli -chain=testnet4 -rpcconnect=192.168.0.223 -rpcport=18332 -rpcuser=add -rpcpassword=add getblockchaininfo
```

## Usage

```sh
# Wallet creation
bitcoin-cli -chain=testnet4 -rpcwallet="watchonly" getwalletinfo
bitcoin-cli -chain=testnet4 listwallets
bitcoin-cli -chain=testnet4 createwallet "watchonly" true true "" true
# true (2nd arg) → Descriptor wallet
# true (3rd arg) → Watch-only
# "" (4th arg) → No passphrase
# true (5th arg) → Avoid private keys
bitcoin-cli -chain=testnet4 loadwallet "watchonly"

# Update .bitcoin/bitcoin.conf with
wallet=watchonly

# Check wallet
ls ~/.bitcoin/testnet3/wallets

# Export wallet
bitcoin-cli -chain=testnet4 -rpcwallet="watchonly" backupwallet "/home/user/wallet-backups/watchonly.dat"
bitcoin-cli -chain=testnet4 -rpcwallet="watchonly" dumpwallet "/home/user/wallet-backups/watchonly-keys.txt"

```

### HD wallets

Add following to your bitcoin.conf
```sh
wallet=hdwallet.dat
```
