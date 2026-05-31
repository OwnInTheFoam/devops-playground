# LND

# Prerequisites

Ensure bitcoin core is running:
```sh
bitcoin-cli -getinfo
bitcoin-cli getblockchaininfo
bitcoin-cli getzmqnotifications
```

## ZMQ

```sh
cat > ~/.bitcoin/bitcoin.conf<EOF
server=1
chain=testnet4
txindex=1
[testnet4]
debug=rpc
rpcbind=0.0.0.0
rpcallowip=192.168.0.0/24
rpcport=48332
rpcuser=<your-user>
rpcpassword=<your-pass>
# ZMQ (loopback is fine)
zmqpubrawblock=tcp://127.0.0.1:28332
zmqpubrawtx=tcp://127.0.0.1:28333
EOF
```

Firewall:
```sh
sudo ufw status
sudo ufw allow 9735/tcp
```

## Installation

```sh
cd ~/Downloads
# Download the Linux amd64 tarball (set the version you want)
LND_VERSION=v0.19.3-beta
wget -O lnd.tar.gz "https://github.com/lightningnetwork/lnd/releases/download/${LND_VERSION}/lnd-linux-amd64-${LND_VERSION}.tar.gz"
tar -xzf lnd.tar.gz
# Folder name varies by version; detect it:
LND_DIR=$(tar -tzf lnd.tar.gz | head -n1 | cut -f1 -d"/")
echo $LND_DIR
sudo install -m 0755 "$LND_DIR"/lnd "$LND_DIR"/lncli /usr/local/bin/
lnd --version
```

## Configure LND
```sh
mkdir -p ~/.lnd

cat <<'EOF' > ~/.lnd/lnd.conf
[Application Options]
listen=0.0.0.0:9735
rpclisten=0.0.0.0:10009
restlisten=0.0.0.0:8080
tlsextraip=127.0.0.1
tlsextraip=<your-LAN-ip>
[Bitcoin]
bitcoin.testnet4=1
#bitcoin.mainnet=1
bitcoin.node=bitcoind
[Bitcoind]
bitcoind.rpchost=127.0.0.1:43324
bitcoind.rpcuser=<your-user>
bitcoind.rpcpass=<your-pass>
bitcoind.zmqpubrawblock=tcp://127.0.0.1:28332
bitcoind.zmqpubrawtx=tcp://127.0.0.1:28333
EOF

# Ensure lnd runs
lnd --configfile=~/.lnd/lnd.conf

```

## Run LND as a desktop application
**DO NOT DO THIS - LND does NOT have a graphical interface**
Create desktop shortcut
```sh
cd ~/Downloads
wget -O lnd.png https://raw.githubusercontent.com/lightningnetwork/lnd/841a29118a0c2b452187a08ee9854e147a6ce025/logo.png
sudo mkdir -p /usr/local/share/icons/
sudo mv lnd.png /usr/local/share/icons/

cat >> ~/Desktop/lnd-testnet4.desktop <<EOF
[Desktop Entry]
Version=1.0
Name=Lightning Network Daemond Testnet4
Comment=Launch Lightning Network in Testnet4 mode
Exec=/usr/local/bin/lnd -chain=testnet4
Icon=/usr/local/share/icons/lnd.png
Terminal=false
Type=Application
Categories=Finance;Network;
EOF

chmod +x ~/Desktop/lnd-testnet4.desktop
cp ~/Desktop/lnd-testnet4.desktop ~/.local/share/applications/
```

## Run LND as a service
Auto launch on startup as a daemon
```sh
# Create the service
sudo nano /etc/systemd/system/lnd-testnet.service
cat >> /etc/systemd/system/lnd-testnet.service <<EOF
[Unit]
Description=Lightning Network Daemon Testnet
After=network.target network-online.target bitcoind.service

[Service]
ExecStart=/usr/local/bin/lnd --configfile=/home/server6/.lnd/lnd.conf
ExecStop=/usr/bin/env sh -c 'lncli --network=testnet4 stop'
Restart=on-failure
User=server6
Group=server6
StandardOutput=journal
StandardError=journal
TimeoutStartSec=300
TimeoutStopSec=300

[Install]
WantedBy=default.target

EOF

# Enable the service
sudo systemctl daemon-reload
sudo systemctl enable lnd-testnet.service
sudo systemctl start lnd-testnet.service
sudo systemctl status lnd-testnet.service

# Ensure service is running
tail -f ~/.lnd/logs/bitcoin/testnet/lnd.log
```

## Setup bash
```sh
cat <<'EOF' >> ~/.bashrc

# LND defaults
export LNCLI_LNDDIR=/home/server6/.lnd
export LNCLI_NETWORK=testnet4
export LNCLI_RPCSERVER=127.0.0.1:10009

EOF
```

Then restart the machine and check RPC is running:
```sh
# Gracefully shutdown bitcoin core
sudo systemctl stop lnd-testnet.service
# Wait for log
tail -f ~/.lnd/logs/bitcoin/testnet4/lnd.log
# Restart
sudo shutdown now -r
```

## Fund the wallet and open channels
```sh
lncli --network=testnet4 create
# DO NOT PUSH:
# abstract leader always design hockey enhance shoe bus muffin click fetch stage below lonely lyrics poem busy confirm reject grain economy cost banner bladelayer
lncli unlock
lncli state
lncli getinfo
lncli walletbalance
```

## Secure access
Expose `9735/10009/8080` only if needed, copy TLS certificate and macaroon files to trusted clients, and keep them backed up alongside the seed.

## Usage

Common commands
```sh
# Info & Status
lncli getinfo – daemon status, pubkey, block height, peers/channels counts
lncli debuglevel info|debug|trace – change logging verbosity
lncli feereport – current channel fee settings
lncli walletbalance / lncli channelbalance – on-chain vs. LN balances
lncli pendingchannels / lncli listchannels --active_only – channel states
# Wallet Lifecycle
lncli create – initialize wallet + seed (first run)
lncli unlock – enter wallet password after restart
lncli changepassword – rotate wallet password
lncli newaddress p2wkh|np2wkh – get deposit address
lncli sendcoins <addr> --amount=... – send on-chain BTC
lncli signmessage "text" / lncli verifymessage <sig> "text"
# Peers & Channels
lncli listpeers – current peer connections
lncli connect <pubkey>@host:port – add peer
lncli disconnect <pubkey> – drop peer
lncli openchannel <pubkey> <local_amt> [--push_sat=...] – open LN channel
lncli closechannel --force <channel_point> – cooperative/force close
lncli updatechanpolicy --base_fee_msat=... --fee_rate_ppm=... <chan_point>
lncli listchannels --inactive_only – find stuck channels
# Invoices & Payments
lncli addinvoice --amt=... --memo="desc" – create BOLT11 invoice
lncli lookupinvoice <r_hash> – check invoice status
lncli listinvoices --pending_only – filter outstanding requests
lncli payinvoice <bolt11> / lncli sendpayment --pay_req=<bolt11> – pay invoice
lncli trackpayment <payment_hash> – monitor attempt
lncli queryroutes <pubkey> --amt=... – preview routing path
# Lightning Network Grapevine
lncli describegraph – full view (large JSON)
lncli getchaninfo <chan_id> – channel details
lncli getnodeinfo <pubkey> – node capabilities
lncli listpayments / lncli listchaintxns – history
# Backups & Recovery
lncli exportchanbackup --all > backup.scb – static channel backup
lncli verifychanbackup --single_backup=... – confirm backup integrity
lncli restorechanbackup --multi_file=backup.scb – restore from SCB
lncli unlock + lncli restorechanbackup – run after seed restore
# Node Maintenance
lncli stop – request graceful shutdown
lncli bakemacaroon info:read invoices:write – create restricted macaroon
lncli listmacaroonids / lncli deletemacaroonid <id> – manage macaroons
lncli getrecoveryinfo – rescan status after recovery
lncli walletbalance --witness_only – watch-only output balances
```
