# 战斗音效与触觉

以本机 CUSA03173 1.09 的 `sprj_main.fev`、`sprj_main_eng.fsb` 和玩家动画 `c0000.anibnd.dcx` 为样本。对 135 个普通挥击、变形、枪械和碰撞片段，解码后用四毫秒窗量起音后能量峰值和累计 90% 能量的时间。手柄波形参照这些时间与频谱的相对差异，用适合握柄的频段重新合成。[vgmstream FSB5 解码器](https://github.com/vgmstream/vgmstream/blob/d9875b1/src/meta/fsb5.c)

## 原声样本与触感

| 原声样本 | 峰值时间 | 累计 90% 能量 | 握柄表现 |
| --- | --- | --- | --- |
| `swing-sword`、`swing-sword2` | 48–52 ms | 84–100 ms | 短、亮，迅速收尾 |
| 锯齿砍刀 `sprj_nokonata_noko*`、`sprj_nokonata_nata*` | 60–164 ms | 112–200 ms | 展开后加强低频和拖尾 |
| 猎人斧 `sprj_onosao_ono*`、`sprj_onosao_sao*` | 44–120 ms | 260–356 ms | 重心偏左，长柄摆动更慢 |
| `swing-stab`、`swing-stab2` | 36–80 ms | 176–180 ms | 窄而集中的起音，后段迅速收窄 |
| `swing_whip`、`w_whip_swing*` | 60–492 ms | 100–500 ms | 先轻拉，再在右手收一个脆响 |
| `iron-cut-stone*` | 8–12 ms | 92–96 ms | 尖锐的触地瞬间和第二下较弱的反弹 |
| `iron-cut-wood` | 24 ms | 48 ms | 短闷击，尾音迅速消失 |
| `iron-cut-iron*` | 8–32 ms | 96–144 ms | 快起音和延续的较高频振动 |
| `iron-cut-meat*` | 24–68 ms | 112–256 ms | 较钝的命中感，保留较低频的余震 |
| `sprj_oodutsu_shot` | 32 ms | 980 ms | 瞬间的强低频后坐加衰减尾音 |

样本时长取决于原声变体，触觉时长经过压缩。制作人对锯齿砍刀的说明也区分了短形态的快速连击和长形态的重挥。[PlayStation Blog 的战斗介绍](https://blog.playstation.com/2014/08/13/bloodborne-on-ps4-new-combat-details/)

## 动画与游戏信号

下面是本机原始普通轻击动画中选出的声音事件。负值表示声音先于同段攻击判定，毫秒数来自动画时间轴。

| 武器 | 动画组 | 基础形态 | 变形后 |
| --- | --- | --- | --- |
| 锯齿砍刀 | `a112` | `c000000610` −66.7 ms | `c000000611` −100 ms |
| 猎人斧 | `a103` | `c000000760` −33.3 ms | `c000000761` −66.7 ms |
| 螺纹手杖 | `a127` | `c000000790` −100 ms | `c000005001`、`c000005850` −200 ms |
| 教会的石锤 | `a105` | `c000000783` −100 ms | `c000000761` −100 ms，`c000000780` 与第二段冲击同时触发 |
| 旋转锯 | `a148` | `c000000931` −100 ms | `c000000933` −366.7 ms，`c000000890` −133.3 ms |

- 这些事件在本机玩家动画和 `sprj_main.fev` 中都有记录。当前挥击触觉接到攻击体创建，声音事件的时间可用于后续逐动作对齐。[Bloodborne 动画事件定义](https://github.com/Meowmaritus/DSAnimStudio/blob/f1bff06cd422de991b0a0fa8a2da81db43417318/DSAnimStudioNETCore/Res/TAE.Template.BB.xml)
- 地图和道具碰撞使用游戏音效路径选择的材质。地图石头常见 `1`、`2`，木头 `4`、`30`、`38`，铁 `9`。游戏按末两位选择地图碰撞音，例如 `201` 走 `1` 的石头音效。敌人受击用自己的防御音效材质表，例如 `50`、`51`、`54`、`56`、`57` 和 `79` 选中金属层。布料、骨头等细分类仍需找到独立且可复测的碰撞信号。
- 发射请求使用原生 `BehaviorParam_PC` 动作 ID。猎人手枪的正常请求是 `101400800`，引用弹丸 `500`。弹丸之后的飞行和命中阶段使用独立编号，后坐在首发请求时输出一次。[弹丸字段定义](https://github.com/soulsmods/Paramdex/blob/master/BB/Defs/BulletParam.xml)
- 有代表性的手感差异是冲击起音、持续时长和频率分布。程序只在游戏事件发生时发出这些短波形，原始游戏音频在研究时用于测量。[接触瞬态反馈研究](https://pubmed.ncbi.nlm.nih.gov/16509381/) · [碰撞声音的材质衰减研究](https://pubmed.ncbi.nlm.nih.gov/30762560/)
- 同类武器可以共享一条动作曲线。短剑、重刃、突刺、鞭、旋转切割等先按原生动作数据选曲线，再对出招强度和长度做调整。逐件武器的主观盲测和逐动作调校仍需实机扩充。[RDR2 DualSense 开源项目的事件与波形组织](https://github.com/OldKrab/rdr2-dualsense)

## 复测

在独立存档里用同一武器分别空挥、击中墙面、击中道具。`BB_DSE_CONTACT_TRACE=1` 会记录原生材质编号、发射动作 ID 和提交触觉的时间戳。引擎已有的 `BB_AUDIO_DUMP` 可输出独立的游戏主音效端口，用于对照实际游戏声音与同一时段的触觉。
