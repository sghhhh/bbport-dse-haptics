# 构建和安装

基于 Windows bbport 1.9.8.6。请自备上游源码、Windows 运行包以及 1.09 游戏数据，包括 `eboot.bin`、`sce_sys`、`sce_module` 和 `dvdroot_ps4`。

战斗事件面向 CUSA03173 与 CUSA00207 的 1.09 版，引擎先核对相关游戏代码签名。高级触觉使用匹配该 USB 手柄的四声道 WASAPI 端点。

## 上游与补丁

- `patches/windows-launcher.patch` 基于 Supermedo/bloodborne_pc 标签 [`windows-v1.9.8.6`](https://github.com/Supermedo/bloodborne_pc/releases/tag/windows-v1.9.8.6) 的提交 `b69561c0fae84f115db00110d28442ee5f3672d5`。
- `patches/seamless-dse-haptics.patch` 基于同一发布的官方对应源码资产 [`bb-probe-seamless-1.9.8.6-source.zip`](https://github.com/Supermedo/bloodborne_pc/releases/download/windows-v1.9.8.6/bb-probe-seamless-1.9.8.6-source.zip)。
- Seamless 源码 ZIP 的 SHA-256 为 `2fc82471bc71965ede76cbcab3c19ea03854014340f1704252ee750b6ba4d8ef`。

## 应用和构建

在本仓库根目录运行 PowerShell 7。克隆 Windows 源码，将上面的 Seamless 源码 ZIP 下载到 `.upstream/`，校验散列值并解压。

```powershell
git clone --depth 1 --branch windows-v1.9.8.6 --filter=blob:none --sparse https://github.com/Supermedo/bloodborne_pc.git .upstream/windows
git -C .upstream/windows sparse-checkout set launcher scripts packaging/windows
$zip = '.upstream/bb-probe-seamless-1.9.8.6-source.zip'
$expected = '2fc82471bc71965ede76cbcab3c19ea03854014340f1704252ee750b6ba4d8ef'
if ((Get-FileHash -Algorithm SHA256 -LiteralPath $zip).Hash -ne $expected) { throw '源码 ZIP 的 SHA-256 不匹配' }
Expand-Archive -LiteralPath $zip -DestinationPath .upstream/seamless
$seamlessSource = '.upstream/seamless/bb-probe-seamless-src'
.\scripts\apply-patches.ps1 -WindowsSource .upstream/windows -SeamlessSource $seamlessSource
```

安装 MSYS2 CLANG64 工具链和依赖。参考引擎构建环境使用 Clang 23.1.5、CMake 4.5.1、Ninja 1.13.2 与 Release `-O2`。[上游 Windows 构建说明](https://github.com/Supermedo/bloodborne_pc/blob/b69561c0fae84f115db00110d28442ee5f3672d5/packaging/windows/README.md)

从 MSYS2 CLANG64 历史存档获取下列 `mingw-w64-clang-x86_64-<包名>-<版本>-any.pkg.tar.zst`，把每个包里的 `clang64/` 解压到同一个 `.upstream/deps/`。这些版本与 1.9.8.6 运行包的 DLL 接口匹配。[MSYS2 CLANG64 包存档](https://repo.msys2.org/mingw/clang64/)

| 包名 | 版本 |
| --- | --- |
| `sdl3` | `3.4.18-1` |
| `ffmpeg` | `9.0.2-3` |
| `openssl` | `3.6.5-1` |
| `protobuf` | `36.2-1` |
| `abseil-cpp` | `20260526.0-1` |
| `zlib` | `1.3.2-1` |

```powershell
.\scripts\build-seamless.ps1 -SeamlessSource $seamlessSource -Clang64 C:\msys64\clang64 -DependencyPrefix .upstream/deps/clang64 -Revision bbsc100-p198-dse8
py -3.12 -m venv .build/venv
.\.build\venv\Scripts\python.exe -m pip install pyinstaller==6.22.3 pillow==13.0.0
.\scripts\build-launcher.ps1 -WindowsSource .upstream/windows
```

启动器的参考构建环境使用 64 位 Python 3.12.10。引擎产物位于 `.build/seamless/bb-probe-seamless.exe`，启动器及其 `_launcher_dse` 运行目录位于 `.build/dist/Bloodborne/`。

## 本地试用

在自用的 `Bloodborne-Windows.zip` 1.9.8.6 解压副本中，将引擎产物复制为 `bin/bb-probe-seamless-dse.exe`。用构建时的 CLANG64 `bin/libc++.dll` 更新运行包的 `bin/libc++.dll`，并保留对应许可证。再将构建出的 `Bloodborne.exe` 和 `_launcher_dse` 放到运行包根目录。用上游脚本刷新这个副本的文件清单。

```powershell
.\.build\venv\Scripts\python.exe .upstream/windows/scripts/package_files.py --write 'C:\Games\bbport-dse' 1.9.8.6
```

### DSE 数据包

把本仓库 `mods/DSE Haptics` 整个文件夹复制到运行包的 `mods` 目录。如果启动器设置了自定义模组目录，请用该目录。默认安装路径如下。

```text
mods/DSE Haptics/dvdroot_ps4/other/bbport-dse-haptics.json
```

在启动器「模组与补丁」启用、禁用或调整数据包的顺序。游戏启动时读取最终生效的模组配置。最终配置缺失或无效时，引擎使用内置参数。修改模组顺序或文件后，重启游戏即可重新读取配置。

打开该副本的启动器，设置原本的游戏目录，用 USB 连接 DualSense Edge。在「控制 → 手柄」启用「DSE 高级震动（离线）」，然后点「开始游戏」。中文玩家可在「玩法 → 语言 → 文本语言」选择简体或繁体中文，bbport 会读取游戏目录里的对应语言资源。

## Linux x86-64

Linux 对应源码为上游 [`linux-seamless-beta.1`](https://github.com/Supermedo/bloodborne_pc/releases/tag/linux-seamless-beta.1) 的 `bb-probe-seamless-linux-beta.1-source.zip`，SHA-256 为 `9d85c78d99c89f51dfc8cba979abb4ce2b544a2c5797a4fc7c99afad27bcc114`。解压后进入含 `build.sh` 的目录，用 Git 应用本仓库的 `patches/seamless-linux-dse-haptics.patch`，再执行 `scripts/build-seamless-linux.sh` 并传入该源码目录。需要 SDL3、ALSA 与上游 Vulkan 引擎依赖，源码自带 `shell.nix`。

输出是 `out/bb-probe`、`out/bb-gpu-capabilities` 与 `out/gpu/libbbgpu.so`。发布版使用 Nixpkgs `93a9ed0a866099a230ed5146a5bb7d16fd5c9b14` 的 GCC 16.2、SDL 3.4.18、ALSA 1.2.16.1 与 Vulkan 1.4.363。用 Nix 构建的 ELF 依赖所选 Nix store 的运行库，发布包带有匹配的运行库与入口脚本。[二进制安装](releases.md)

## 许可证与致谢

补丁和新增构建脚本采用 GPL-2.0-or-later，见 [LICENSE](../LICENSE)。上游 bbport 由 [Supermedo 和贡献者](https://github.com/Supermedo/bloodborne_pc)开发，Seamless 使用 [CLSAMG22 的 BBSC](https://github.com/CLSAMG22/BBSC)。上游各文件的版权声明和第三方组件许可随对应源码保留。
