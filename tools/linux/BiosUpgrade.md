# Upgrading BIOS

Check current BIOS version:
- `sudo dmidecode -t bios -q`

Finding the correct download link:
- Navigate to [Lenovo Support](https://pcsupport.lenovo.com/us/en)
- Browse your product
- Go to Drivers & Software
- Copy the link to download `BIOS Update (ISO Image Version)`

## Lenovo m70q

## Lenovo M910q

## Lenovo M700
NOTE: https://download.lenovo.com/pccbbs/thinkcentre_bios/fwj9{version}usa.iso
VERSIONS: bf (2022), 
1. download BIOS Update (ISO Image Version) from above link, replace {version} with the version you need.
2. `sudo apt install genisoimage`
3. Extract iso to img, `geteltorito -o x{version}.img fbj9{version}usa.iso`
4. Write img to usb, `sudo dd if=x{version}.img of=/dev/sdd bs=512K`, Use disks program to determine correct `/dev/sdd` path for your usb.
5. Reboot, `shutdown -h 0`
6. Press enter on startup logo
7. Select `f12`
8. Follow prompts to upgrade

If you receive an error in the update terminal like `Please use windows version flash tool` try a different BIOS version to flash and/or USB port.

## Lenovo M93p
NOTE: must update to {version} 74 (2014) then c4 (2016) then d2 (2018) then e0 (2021)
NOTE: https://download.lenovo.com/pccbbs/thinkcentre_bios/fbj9{version}usa.iso
1. download BIOS Update (ISO Image Version) from above link, replace {version} with the version you need.
2. `sudo apt install genisoimage`
3. Extract iso to img, `geteltorito -o x{version}.img fbj9{version}usa.iso`
4. Write img to usb, `sudo dd if=x{version}.img of=/dev/sdd bs=512K`, Use disks program to determine correct `/dev/sdd` path for your usb.
5. Reboot, `shutdown -h 0`
6. Press enter on startup logo
7. Select `f12`
8. Follow prompts to upgrade

If you receive an error in the update terminal like `Please use windows version flash tool` try a different BIOS version to flash and/or USB port.
