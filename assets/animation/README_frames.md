# 吉祥物透明序列帧

从 `budding-animation-pack.zip`、`rabbit-animation-pack.zip`、`lawilim-animation-pack.zip` 中的 WebM 转换得到。原始压缩包保留。

## 图片规格

- PNG，RGBA，保留透明背景及半透明边缘。
- 每帧 256 × 256，保留原始 60 fps；使用 Lanczos 缩小，不裁切画布。
- 各目录按 `frame_0000.png`、`frame_0001.png`……顺序播放。
- 仅保留游戏使用的待机、受击和攻击合成版，共 9 段动画、1,590 帧，PNG 合计约 54.65 MiB。
- PNG 使用无损压缩；分辨率已缩小，半透明边缘与特效仍保留。
- 具体帧数、时长、图层、文件大小及透明抽查结果见 `frames_manifest.json`。

## 动作目录

| 目录 | budding | rabbit | lawilim | 播放方式 |
| --- | --- | --- | --- | --- |
| `character_idle/` | 300 帧 / 5 秒 | 150 帧 / 2.5 秒 | 150 帧 / 2.5 秒 | 循环 |
| `character_hurt/` | 150 帧 / 2.5 秒 | 150 帧 / 2.5 秒 | 150 帧 / 2.5 秒 | 一次 |
| `attack_combined/` | 180 帧 / 3 秒 | 180 帧 / 3 秒 | 180 帧 / 3 秒 | 一次，人物及全部攻击特效 |

`rabbit` 对应游戏角色数据库中的 `tiancaitu`（天才兔）。

budding 原先的 10 秒待机包含两个相同的 5 秒动作周期，rabbit 包含四个相同的 2.5 秒周期。各保留一个完整周期循环播放；没有减少每秒帧数，也没有加速动作。Lawilim 的待机原本就是单个 2.5 秒周期。

## 原始分层素材

独立人物攻击、独立特效及 1024 × 1024 原始视频保存在各角色的 ZIP 包中，没有重复展开到运行时目录。若未来需要独立控制特效，可从原包重新转换。

原包的各攻击层都是 180 帧、3 秒、60 fps。使用分层版本时，从帧 0 同步播放；人物层使用 `character_attack`。

从后到前的合成顺序：

- budding：`effects_back` → `character_attack` → `effects_front`。
- rabbit：`effects` → `character_attack`。
- lawilim：`ink_back` → `card_back` → `character_attack` → `ink_front` → `card_front`。

`attack_combined` 已包含全部图层，使用它时无需叠加独立特效。

## 接入备注

这批文件可供 Godot SpriteFrames 按 60 fps 导入，待机开启循环，受击与攻击播放一次。PNG 文件大小不等于加载后的纹理内存；全套 RGBA8 帧在不含 mipmap、未使用显存压缩时，像素数据约占 397.5 MiB，实际运行占用还取决于加载策略和导入设置。

各角色目录的 `sprite_frames.tres` 已绑定 `idle`、`hurt`、`attack` 三种动画；角色 JSON 的 `battle_animation_path` 指向对应资源，静态头像继续用于准备页等界面。

战斗中待机循环播放；关闭答题结果后，伤害牌先播放一次攻击再结算。敌方回合显示提示，然后逐个行动；被攻击的我方角色播放一次受击动画，结束后再处理下一名敌人。群体攻击的受击动画同步播放，致命一击播放完后才显示失败结算。

可调项：`CharacterMotion` 的 `playback_speed`、`selection_jump_height`、`selection_jump_gravity`，`TurnBanner` 的 `display_seconds`，`EnemyStandee` 的 `action_recovery_seconds`。选中时仅贴图层原地跳一次，血条与站位固定，落地后回到原位；没有脚下选择标记。敌人攻击占位动画位于 `EnemyStandee.tscn > AttackAnimation`，预留动画精灵位于 `Content/Portrait/VisualRoot/AttackOrigin/AttackSprite`。
