## On your Ubuntu machine:
```bash
sudo apt update
sudo apt install xrdp -y
sudo systemctl status xrdp

sudo ufw status
sudo ufw enable
sudo ufw allow 3389
sudo ufw reload

sudo systemctl enable xrdp
// Find you internet ip4 address:
ip a
// Find your username
whoami
```

## On your router
- Open 192.168.0.1 to login to router
- Set you mac address device to a static IP address
- Port forward 3389 to 3389 of your static IP address

## On your Windows machine:
- Open microsoft remote desktop
- In computer field use `publicIP:3389`
