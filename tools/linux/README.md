# Basic linux commands

## Sleep
- Disable sleep
  ```
  sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
  ```
- Enable sleep
  ```
  sudo systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target
  ```

## Lock screen
- Check lock screen
  ```
  gsettings get org.gnome.desktop.lockdown disable-lock-screen
  ```
- Disable lock screen 
  ```
  gsettings set org.gnome.desktop.lockdown disable-lock-screen 'true'
  ```

## Screen saver
- Check screen saver locking
  ```
  gsettings get org.gnome.desktop.screensaver lock-enabled
  ```
- Disable screen saver locking
  ```
  gsettings set org.gnome.desktop.screensaver lock-enabled false
  ```

## Login
- Automatically login
  ```
  sudo nano /etc/gdm3/custom.conf
  ```
  ```
  AutomaticLoginEnable = true
  AutomaticLogin = root
  ```

## Create root user - NOT RECOMMENDED
```
sudo passwd root
sudo passwd -u root 
```
