# bbport DSE

为 Windows 版 bbport 添加有线 DualSense Edge 高级震动。从启动器「控制 → 手柄」启用「DSE 高级震动（离线）」，再点「开始游戏」。DSE 使用独立的离线存档，沿用启动器保存的全屏与文本语言设置。

仓库提供源码补丁、构建脚本和说明。请自备上游源码、Windows 运行包以及 1.09 游戏数据，包括 `eboot.bin`、`sce_sys`、`sce_module` 和 `dvdroot_ps4`。

## 游戏内触感

- R1 轻挥是一记短促的高频掠过。R2 重挥从低频起，两个握柄先后接力。满蓄力挥出时，触感从左侧快速扫到右侧，再收尾。
- 进入游戏的蓄力动画后，握柄会逐渐增强。松开 R2、离开蓄力动作或挥出时，蓄力触感停止。
- 挥击读取游戏实际选用的动作和攻击参数。锯齿砍刀的短形态更利落，展开后拖尾更长。手杖的鞭形态带有延迟的甩响，石锤和斧头更偏低频。枪、炮、弓、喷射器按游戏的实际发射动作区分。
- 近战武器接触地图、可破坏物和敌人时，根据游戏的碰撞材质改变冲击。石头给短促反弹，木头给闷击，金属保留较长的高频余震，肉身的冲击更钝。空挥继续使用挥击波形。
- 玩家受击按掉血比例区分轻重，单次扣除至少 12% 最大生命值或致死时使用重击效果。识别到 Boss 时会加强低频、延长余震。

战斗事件目前面向 CUSA03173 与 CUSA00207 的 1.09 版，引擎会先核对相关游戏代码签名。高级触觉使用匹配该 USB 手柄的四声道 WASAPI 端点。

原声音库的测量记录、材质识别依据与校准范围见[战斗音效与触觉](docs/combat-audio.md)。

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

安装 MSYS2 CLANG64 工具链和依赖。已验证的引擎构建使用 Clang 23.1.5、CMake 4.5.1、Ninja 1.13.2 与 Release `-O2`。[上游 Windows 构建说明](https://github.com/Supermedo/bloodborne_pc/blob/b69561c0fae84f115db00110d28442ee5f3672d5/packaging/windows/README.md)

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
.\scripts\build-seamless.ps1 -SeamlessSource $seamlessSource -Clang64 C:\msys64\clang64 -DependencyPrefix .upstream/deps/clang64
py -3.12 -m venv .build/venv
.\.build\venv\Scripts\python.exe -m pip install pyinstaller==6.22.3 pillow==13.0.0
.\scripts\build-launcher.ps1 -WindowsSource .upstream/windows
```

启动器构建已用 64 位 Python 3.12.10 验证。引擎产物位于 `.build/seamless/bb-probe-seamless.exe`，启动器及其 `_launcher_dse` 运行目录位于 `.build/dist/Bloodborne/`。

## 本地试用

在自用的 `Bloodborne-Windows.zip` 1.9.8.6 解压副本中，将引擎产物复制为 `bin/bb-probe-seamless-dse.exe`。用构建时的 CLANG64 `bin/libc++.dll` 更新运行包的 `bin/libc++.dll`，并保留对应许可证。再将构建出的 `Bloodborne.exe` 和 `_launcher_dse` 放到运行包根目录。用上游脚本刷新这个副本的文件清单。

```powershell
.\.build\venv\Scripts\python.exe .upstream/windows/scripts/package_files.py --write 'C:\Games\bbport-dse' 1.9.8.6
```

打开该副本的启动器，设置原本的游戏目录，插入 DualSense Edge 的 USB 线，然后用「开始游戏」测试。关闭高级震动复选框即可使用普通启动设置。中文玩家可在「玩法 → 语言 → 文本语言」选择简体或繁体中文，bbport 会读取游戏目录里的对应语言资源。

## 验证

用上面的官方源码重新应用补丁并构建了引擎和启动器。在 CUSA03173 1.09 的独立测试存档里，用有线 DualSense Edge 实测过轻挥、重挥、满蓄力和按住 R2 期间的蓄力。锯齿砍刀的两种形态分别选中了对应曲线。石墙、铁质道具和猎人手枪均已记录到游戏事件与手柄振动。普通敌人的命中和受击已测试，Boss 受击分支仍待实战验证。

## 许可证与致谢

补丁和新增构建脚本采用 GPL-2.0-or-later，见 [LICENSE](LICENSE)。上游 bbport 由 [Supermedo 和贡献者](https://github.com/Supermedo/bloodborne_pc)开发，Seamless 使用 [CLSAMG22 的 BBSC](https://github.com/CLSAMG22/BBSC)。上游各文件的版权声明和第三方组件许可随对应源码保留。
