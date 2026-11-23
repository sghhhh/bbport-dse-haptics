# DSE haptic profiles

Copy the bundled **DSE Haptics** folder to bbport's Mods folder. The mod file must be at `dvdroot_ps4/other/bbport-dse-haptics.json` within its own mod folder. Toggle or reorder the folder in **Mods & patches**. When enabled packs provide the same file, the last one in the load order supplies the entire file. The engine reads it at game startup, so restart the game after saving an edit. A disabled, missing or invalid pack falls back to the built-in tuning. The DSE switch in controller settings controls the haptic engine.

把随附的 **DSE Haptics** 文件夹放进 bbport 的模组目录。每个参数包都用同一个相对路径 `dvdroot_ps4/other/bbport-dse-haptics.json`。在「模组与补丁」启停或排序，多个启用的包提供同名文件时，以最后加载的整份文件为准。保存修改后重新开始游戏即可。配置包禁用、缺失或无效时，恢复内置参数。

## Example | 示例

```json
{
  "version": 1,
  "name": "Shorter Saw Cleaver and Wood",
  "weapons": {
    "7000000": {
      "normal": { "duration": 0.85, "left": 0.80, "right": 1.10 },
      "transformed": { "duration": 1.30, "pitch": 0.90 }
    }
  },
  "curves": {
    "wood": [
      [0, 0, 0, 45, 95],
      [10, 0.68, 0.35, 54, 103],
      [52, 0, 0, 38, 76]
    ]
  }
}
```

The profile version is `1`. `curves`, `profiles` and `weapons` are optional. Tuning starts with the built-in weapon profile, then applies matching `profiles` fields, then `weapons` fields for the active form. Weapon keys are base game equipment IDs without upgrade or imprint offsets. Use `normal`, `transformed` or `projectile`. The bundled file lists the supported IDs and profile names.

- `duration` runs from `0.5` to `2.0`. `pitch` runs from `0.6` to `1.5`. These scale motion and recoil cues. A contact uses its material curve's own timing and pitch.
- `left` and `right` scale the grip levels from `0` to `1.6`. `flutter` adds rapid amplitude variation from `0` to `0.70` to motion and recoil cues.
- Each curve point contains `[milliseconds, left level, right level, left Hz, right Hz]`. Use 2 to 64 points starting at 0 ms and increasing up to 2500 ms. Levels run from `0` to `1`, and frequencies from `20` to `250` Hz. End a curve at zero level for a gradual finish.
- Surface curves are `stone`, `wood`, `metal` and `flesh`. Traversal curves are `door` and `ladder`. The ladder curve mirrors across the grips for the other hand.

已在模组内提供武器、形态和材质的完整示例。`duration` 控制动作长短，`left` 和 `right` 控制两个握把的强度，`pitch` 控制频率，`flutter` 控制细碎振幅变化。材质可直接调整 `curves` 对应点的时刻与频率。启动日志会记录加载的包，配置有误时也会列出原因。

## Weapon IDs | 武器 ID

| ID | Weapon | 简体中文 |
| --- | --- | --- |
| `1000000` | Bare Fists | 赤手空拳 |
| `2000000` | Chikage | 千影 |
| `4000000` | Blade of Mercy | 仁慈之刃 |
| `5000000` | Hunter Axe | 猎人斧 |
| `5100000` | Burial Blade | 葬仪之刃 |
| `6000000` | Hunter Blunderbuss | 猎人短筒火铳 |
| `6100000` | Ludwig's Rifle | 路德维格的步枪 |
| `7000000` | Saw Cleaver | 锯齿砍刀 |
| `7100000` | Saw Spear | 锯齿长矛 |
| `8000000` | Kirkhammer | 教会的石锤 |
| `8100000` | Ludwig's Holy Blade | 路德维格的神圣之刃 |
| `9000000` | Beast Claw | 兽爪 |
| `10000000` | Rifle Spear | 来福标枪 |
| `10100000` | Reiterpallasch | 骑士剑 |
| `11000000` | Stake Driver | 打桩机 |
| `12000000` | Logarius' Wheel | 洛加留斯的轮椅 |
| `13000000` | Tonitrus | 雷霆 |
| `14000000` | Hunter Pistol | 猎人手枪 |
| `14100000` | Evelyn | 伊芙琳 |
| `14200000` | Repeating Pistol | 连发手枪 |
| `15000000` | Cannon | 大炮 |
| `18000000` | Rosmarinus | 迷迭香 |
| `18100000` | Flamesprayer | 火焰喷射器 |
| `20000000` | Hunter's Torch | 猎人的火把 |
| `20100000` | Torch | 火把 |
| `22000000` | Threaded Cane | 螺纹手杖 |
| `23000000` | Beasthunter Saif | 怪兽猎人曲刀 |
| `24000000` | Beast Cutter | 野兽切割刀 |
| `25000000` | Amygdalan Arm | 阿米戈达拉之臂 |
| `26000000` | Holy Moonlight Sword | 圣洁月光剑 |
| `27000000` | Rakuyo | 洛阳 |
| `28000000` | Boom Hammer | 轰天锤 |
| `29000000` | Bloodletter | 血祭刀 |
| `30000000` | Church Pick | 教会之镐 |
| `31000000` | Whirligig Saw | 旋转锯 |
| `32000000` | Simon's Bowblade | 西蒙的弓刃 |
| `33000000` | Gatling Gun | 加特林机枪 |
| `34000000` | Fist of Gratia | 格拉缇娅之拳 |
| `35000000` | Church Cannon | 教堂大炮 |
| `36000000` | Piercing Rifle | 穿刺枪 |
| `38000000` | Kos Parasite | 科斯寄生虫 |
