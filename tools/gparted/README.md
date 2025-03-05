# [GParted](gparted.org)

Utility to copy and move data on disks

## Download

Download the live [disk image](https://gparted.org/download.php)
Install the boot image to usb. (Ventoy recommended)

## Install

Reboot (this ensures fastboot is disabled) your machine to boot menu (esc key) and select Ventoy then GParted.
Press enter to open the default GParted live image.
Identify your drives within GParted application. Note the drive names data will be copied from and to.
Open the terminal located on desktop.
Enter `sudo smartctl -i /dev/sda` (update depending on drive name)

## Shrinking

Ideally shrink drive more than necessary before copying and after copying then expand.

- In GParted application select your drive and the partition you want to shrink
- Select menu > Partition > Resize/Move
- Select new size amount and Resize/Move
- There should be a new unallocated partition
- Ensure unallocated partition is at the end of drive.
- Press checkmark to apply the changes.

## Copying

Use dd tool to move data:
- if = input file
- of = output file
- bs = block size (to speed things up)
- status = to show progress
Ensure you update to the correct drive names
```sh
sudo dd if=/dev/sda of=/dev/nvme0n1 bs=1M status=progress
```

If you open GParted with a error invalid simily cancel it, this is because its expecting a certain partition information at the end of the drive but its unallocated.

To fix this use gdisk:
```sh
sudo gdisk /dev/nvme0n1
x
?
e
w
y
lsblk
```

Re-open GParted

## Moving

Move the end partitions to the end (if necessary):
- Select partition
- Select menu > Partition > Resize/Move
- Set Free space following to 0
- Resize/Move
Expand main partition:
- Select partition
- Select menu > Partition > Resize/Move
- Set New size to Maximum Size shown
- Resize/Move
Write to drive:
- Press checkmark to apply the changes.

## Complete

Shutdown and boot into drive.

## Troubleshoot

If you have issues booting to new drive on ubuntu you may boot into [Ubuntu Boot Repair](https://help.ubuntu.com/community/Boot-Repair).
You may run Boot-Info and BootRepair
