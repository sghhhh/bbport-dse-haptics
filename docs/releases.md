# Binary releases | 二进制发布

The release uses separate x86-64 binaries for Windows and Linux. Both use the same editable JSON profile. The game stays in your existing bbport installation. See [profile fields and weapon IDs](profiles.md).

Windows 和 Linux 各有一套 x86-64 二进制，使用同一份可编辑的 JSON。存档、游戏数据和选区沿用已有 bbport。[配置字段与武器 ID](profiles.md)

## Windows 10/11

Use the official Windows bbport 1.9.8.6 base. Extract `bbport-dse8-windows-x86_64.zip`, close the game and launcher, and run the bundled installer with PowerShell 7. Pass `-ModsDir` if your launcher uses a custom Mods folder.

```powershell
.\Install-DSE.ps1 -PortDir 'C:\Games\bbport-windows'
```

Open the installed launcher, enable **DSE haptics (offline)** in the controller settings, and click **Play**. The installer updates the file manifest and keeps any existing DSE profile.

使用官方 Windows 1.9.8.6。关掉游戏和启动器后运行上面的安装命令。然后在手柄设置启用 DSE，点原来的「开始游戏」。自定义模组目录可传入 `-ModsDir`。

## Linux preview | Linux 预览版

Use the official [Linux Seamless beta 1 AppImage](https://github.com/Supermedo/bloodborne_pc/releases/tag/linux-seamless-beta.1). Extract `bbport-dse8-linux-x86_64.tar.gz` and start the original launcher through its supplied wrapper. Copy the bundled `mods/DSE Haptics` folder into the Mods folder configured in the launcher. Play offline with a wired DualSense Edge. HD output uses the controller's four-channel ALSA USB playback device. The normal SDL rumble path remains available if the USB audio device is unavailable.

```bash
./start-linux.sh ~/Downloads/Bloodborne-Linux-x86_64.AppImage
```

Linux 使用官方 beta 1 AppImage 的原启动器。把随附的 **DSE Haptics** 放进配置好的模组目录，从上面的脚本打开启动器，再用普通「开始游戏」离线玩。

## Profiles | 配置包

`bbport-dse8-profiles.zip` contains the default Mod pack. Either platform can edit or substitute the JSON and restart the game. Existing files can keep their custom values. New curves missing from an older pack use the engine defaults.

两个平台都可以换用同一个配置包，改完重启游戏即可。原有自定义值可保留，旧包缺少的新曲线使用引擎默认值。
