# Android

Turn on Developer Options
Enable USB Debugging
Disable password, screen etc
Connect mobile

## ADB and fastboot
[Download Android SDK Platform Tools](https://developer.android.com/tools/releases/platform-tools)
May need USB drivers
Allow USB Debugging
```sh
adb devices
adb reboot fastboot
# wait
fastboot devices
# Flash a modified vbmeta img to disable verification checks allowing for root or custom rom
# Without verification checks disabled it'll bootloop or security error.
# Ensure you backup stock img beforehand. May be able to get from manufacture.
fastboot --disable-verity --disable-verification flash vbmeta vbmeta.img

# Flash TWRP
fastboot flash recovery twrp.img
fastboot boot twrp.img

# TWRP > Backup > stock images

# TWRP > Wipe > Format
# TWRP > Wipe > Dalvik,Metadata,Cache,Cust,System,Vendor,Data,Interal Storage
# TWRP > Advance > ADB Sideload > 
adb devices
adb sideload PixelExperience.zip
# Reboot to System (First boot 5 minutes)
```

## Flash Recovery (TWRP)

Download [TWRP](https://twrp.me/)


## Flash Custom ROM

### LineageOS

#### [Xiaomi Poco F3](https://wiki.lineageos.org/devices/alioth)
Remove all Google accounts

```sh
# Check if bootloader is unlocked
fastboot oem device-info
# Otherwise use the Mi Unlock app

# Check firmware version
fastboot getvar all
# Flash stock firmware OS1.0.2.0.TKHMIXM for LineageOS AEOS to install from.
fastboot flash abl_ab lineageos/miui_ALIOTHGlobal_OS1.0.2.0.TKHMIXM_b69e6a5400_13.0/abl.img
fastboot flash aop_ab lineageos/miui_ALIOTHGlobal_OS1.0.2.0.TKHMIXM_b69e6a5400_13.0/aop.img
fastboot flash bluetooth_ab lineageos/miui_ALIOTHGlobal_OS1.0.2.0.TKHMIXM_b69e6a5400_13.0/bluetooth.img
fastboot flash cmnlib_ab lineageos/miui_ALIOTHGlobal_OS1.0.2.0.TKHMIXM_b69e6a5400_13.0/cmnlib.img
fastboot flash cmnlib64_ab lineageos/miui_ALIOTHGlobal_OS1.0.2.0.TKHMIXM_b69e6a5400_13.0/cmnlib64.img
fastboot flash devcfg_ab lineageos/miui_ALIOTHGlobal_OS1.0.2.0.TKHMIXM_b69e6a5400_13.0/devcfg.img
fastboot flash dsp_ab lineageos/miui_ALIOTHGlobal_OS1.0.2.0.TKHMIXM_b69e6a5400_13.0/dsp.img
fastboot flash featenabler_ab lineageos/miui_ALIOTHGlobal_OS1.0.2.0.TKHMIXM_b69e6a5400_13.0/featenabler.img
fastboot flash hyp_ab lineageos/miui_ALIOTHGlobal_OS1.0.2.0.TKHMIXM_b69e6a5400_13.0/hyp.img
fastboot flash imagefv_ab lineageos/miui_ALIOTHGlobal_OS1.0.2.0.TKHMIXM_b69e6a5400_13.0/imagefv.img
fastboot flash keymaster_ab lineageos/miui_ALIOTHGlobal_OS1.0.2.0.TKHMIXM_b69e6a5400_13.0/keymaster.img
fastboot flash modem_ab lineageos/miui_ALIOTHGlobal_OS1.0.2.0.TKHMIXM_b69e6a5400_13.0/modem.img
fastboot flash qupfw_ab lineageos/miui_ALIOTHGlobal_OS1.0.2.0.TKHMIXM_b69e6a5400_13.0/qupfw.img
fastboot flash tz_ab lineageos/miui_ALIOTHGlobal_OS1.0.2.0.TKHMIXM_b69e6a5400_13.0/tz.img
fastboot flash uefisecapp_ab lineageos/miui_ALIOTHGlobal_OS1.0.2.0.TKHMIXM_b69e6a5400_13.0/uefisecapp.img
fastboot flash xbl_ab lineageos/miui_ALIOTHGlobal_OS1.0.2.0.TKHMIXM_b69e6a5400_13.0/xbl.img
fastboot flash xbl_config_ab lineageos/miui_ALIOTHGlobal_OS1.0.2.0.TKHMIXM_b69e6a5400_13.0/xbl_config.img
fastboot getvar all
fastboot reboot

# Flash LineageOS
fastboot flash boot lineageos/lineage-23.2-20260513-nightly-alioth-signed/boot.img
fastboot flash dtbo lineageos/lineage-23.2-20260513-nightly-alioth-signed/dtbo.img
fastboot reboot bootloader

fastboot flash vendor_boot lineageos/lineage-23.2-20260513-nightly-alioth-signed/vendor_boot.img
fastboot reboot recovery

# "Apply Update" > "Apply from ADB"
adb -d sideload lineageos/copy-partitions-20220613-signed.zip
# advanced > Reboot to recovery

# Factory Reset > Format data / factory reset

# sideload
# "Apply Update" > "Apply from ADB"
adb -d sideload lineageos/lineage-23.2-20260513-nightly-alioth-signed.zip

# Google Apps sideload
# "Apply Update" > "Apply from ADB"
adb -d sideload lineageos/MindTheGapps-16.0.0-arm64-20260409_073023.zip

# Reboot system now
```

## Root (Magisk)

- Download [Magisk APK](https://github.com/topjohnwu/magisk/releases/)
- Copy APK to android and Install
- Backup boot.img (via TWRP)
- In Magisk APK App Install > Patch boot.img
- Reboot android to Fastboot
- Connect to PC

```sh
fastboot devices
fastboot flash boot magisk_patched.img
fastboot reboot
```

## Patches

**SmaliPatcher**

**Play Integrity Fix**
Test with Integrity Checker API App

Magisk > Settings > Hide Magisk App
Play Store > App Info > Force Stop > Clear storage > Clear cache
Google Wallet > App Info > Force Stop > Clear storage > Clear cache

Download [ReZygisk](https://github.com/PerformanC/ReZygisk) as Zygisk OR Zygisk Next
Download [NoHello](https://github.com/MhmRdd/NoHello) to hide Zygisk
Download [Play Integrity Fork](https://github.com/osm0sis/PlayIntegrityFork)
Download [Tricky Store](https://github.com/5ec1cff/TrickyStore) as Tricky Store
//Download [Tricky Addon](https://github.com/KOWX712/Tricky-Addon-Update-Target-List)
Download [Integrity Box](https://github.com/MeowDump/Integrity-Box)
Magisk > Modules > Install from storage > ".zip"
Reboot

Magisk > Modules > Integrity Box > Action x2
Magisk > Modules > Tricky Store > Action 
KsuWebUI > Settings > Tricky Store > Configure DenyList > Show System > Tick All google > Save
Magisk > Settings > Configure DenyList > Show System > Tick All google > Save
KsuWebUI > Settings > Zygisk Next > Use Anonymous memory > linker > Denylist Policy Enforced

May need to get own xml keybox with https://integritybox2.vercel.app
If not root?

Test with Integrity Checker API App
Play Store > Settings > About > Play Store Version repeatedly
Play Store > Settings > General > Developer > Check Integrity


## Swift Backup

- Install APK from Play Store
- Grant Superuser permissions
- Backup

## Unroot

## APK Sideload

