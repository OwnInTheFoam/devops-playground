# Enabling WakeOnLan for Ubuntu 22.04

## Enable WakeOnLan within BIOS
To enable WoL in the BIOS, enter the BIOS setup and look for something called "Wake up on PCI event", "Wake up on LAN" or similar. Change it so that it is enabled. Save your settings and reboot.

## Determine ethernet port, IP and MAC address
```
ip a
```

This should output similar to the following:
```
...
2: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP>
    link/ether 00:12:34:aa:bb:dd brd ff:ff:ff:ff:ff:ff
    altname enp0s3
    inet 192.168.0.222/24 brd 192.168.0.255 scope global dynamic
       valid_lft 12345sec preferred_lft 12345sec
    inet6 1000:2000:3000:4000:aaaa:bbbb:cccc:dddd/64 scope global temporary dynamic
       valid_lft 1234sec preferred_lft 1234sec
    inet6 1000:2000:3000:4000:aaaa:bbbb:cccc:dddd/64 scope global dynamic
       valid_lft 1234sec preferred_lft 1234sec
    inet6 aaaa::bbbb:cccc:dddd:eeee/64 scope link noprefixroute
       valid_lft forever preferred_lft forever
...
```
Make note of your ethernet port: `eth1`, IP address: `192.168.0.222` and Mac address: `00:12:34:aa:bb:dd`.

## Enable WakeOnLan
You'll need `ethtool` for this:
```
ethtool --version
```
If `ethtool` is not installed then run:
```
apt update
apt install ethtool
```
With `ethtool` use the ethernet port to check if WakeOnLan is supported.
```
ethtool eth1
```
This should output similar to the following:
```
...
Supports Wake-on: pumbg
Wake-on: d
...
```
You can determine if WakeOnLan is supported (`g` present) using the following legend:
| Option | Description |
| ------ | ----------- |
| p      | Wake on PHY activity |
| u      | Wake on unicast messages |
| m      | Wake on multicast messages |
| b      | Wake on broadcast messages |
| g      | Wake on MagicPacket messages |

To enable WakeOnLan:
```
ethtool --change eth1 wol g
```

## Sending WakeOnLan magic packet from another PC
To do this WakeOnLan needs to be installed
```
wakeonlan -v
```
If it is not then install it with:
```
apt update
apt install wakeonlan
```
To determine if the target PC receives the magic packet use `tcpdump` to listen:
```
tcpdump -i eth1 -x "(udp port 7) or (udp port 9)"
```
Now send the magic packet
```
wakeonlan 00:12:34:aa:bb:dd
```
If the target machine receieved it, it should have output similar:
```
IP 192.168.0.100.1234 > 255.255.255.255.discard: UDP, length 102
```
If not then you may need to send the magic packet with the IP address:
```
wakeonlan -i 192.168.0.222 00:12:34:aa:bb:dd
```

## WakeOnLan from shutdown state
The WakeOnLan enabled setting may reset on shutdown, so first attempt to see if this is the case.
With the target machine shutdown send the magic packet.
```
wakeonlan -i 192.168.0.222 00:12:34:aa:bb:dd
```
If it fails to power on then enable WakeOnLan through a `systemd` service.
Determine the path of `ethtool`:
```
which ethtool
```
Should output similar to:
```
/usr/sbin/ethtool
```
Then create a `systemd` service:
```
cat >/etc/systemd/system/wol.service<<EOF
[Unit]
Description=Enable Wake On Lan

[Service]
Type=oneshot
ExecStart = /usr/sbin/ethtool --change eth1 wol g

[Install]
WantedBy=basic.target
EOF
```
Then reload `systemd`:
```
systemctl daemon-reload
systemctl enable wol.service
systemctl status wol
```

## Automatically trigger WakeOnLan on startup
Create an systemd service file to execute on startup. Note: This could be combined with the above script.

First enable systems to wait for network.
```
systemctl enable systemd-networkd.service systemd-networkd-wait-online.service
```

Then add the cluster boot service
```
cat >/etc/systemd/system/clusterboot.service<<EOF
[Unit]
Description=Boot all cluster nodes with wol
After=systemd-networkd-wait-online.service
Wants=systemd-networkd-wait-online.service

[Service]
Type=oneshot
ExecStartPre=/usr/bin/sleep 15
ExecStart = wakeonlan 00:23:24:E5:0E:DE
ExecStartPost = wakeonlan 00:23:24:E5:0D:FF

[Install]
WantedBy=basic.target
EOF
```
Then reload `systemd`:
```
systemctl daemon-reload
systemctl enable clusterboot.service --now
systemctl status clusterboot
```

