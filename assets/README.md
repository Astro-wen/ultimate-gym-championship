# assets 目录规范

原始素材包（`rpgmaker素材/`）保持原样不动，只作为来源。游戏实际使用的素材统一放在这里，原有素材和 AI 生成素材混用。

## 目录

| 目录 | 内容 |
|---|---|
| `sheets/interiors/` | 室内家具图集（768×768，48px 网格），按主题命名 |
| `sheets/tilesets/` | 地板、墙体图集 |
| `sheets/characters/` | NPC 行走、坐姿、看手机等角色图集 |
| `sprites/<场景>/` | 从图集裁出的单个物件，场景分 `gym` `office` `locker_room` `props` |
| `anim/<场景>/` | 带动画帧的物件（跑步机、门、摄像头等） |
| `characters/parts/` | 捏人分层素材（身体、发型、服装、配饰、眼睛） |
| `characters/base/` | 组合好的角色（玩家、关键 NPC） |
| `characters/generated/` | AI 生成的角色动作帧 |
| `generated/_raw/` | AI 原始输出，未处理，不直接进游戏 |
| `generated/_prompts/` | 每张 AI 图对应的提示词记录 |
| `ui/` | 界面素材 |

## 命名规则

全小写、下划线分隔，格式：

```
<类别>_<名称>_<状态/动作>_<帧数>f_<来源>_v<版本>.png
```

- 类别：`equip`（器械）、`char`（角色）、`prop`（道具）、`tile`（地块）、`ui`、`fx`
- 状态/动作：`idle`、`use`、`walk`、`push`、`caught` 等
- 帧数：单帧写 `1f`，动画写实际帧数，横向排成一行，每格 48×48
- 来源：`orig`（原素材包）、`ai`（AI 生成）、`mix`（原素材加手工或 AI 修改）
- 版本：`v1` 起，修改后加版本，不覆盖旧文件

示例：

- `equip_benchpress_use_4f_ai_v1.png`
- `equip_dumbbell_idle_1f_orig_v1.png`
- `char_worker_run_4f_ai_v2.png`

## 规格

- 单格 48×48，透明背景，不抗锯齿
- 动画帧横向排列在一张图里，一行一个动作
- AI 生成图必须经过「缩放到 48 格 + 对齐检查」后才放入 `sprites/` 或 `anim/`，原始输出留在 `generated/_raw/`

## 素材清单

新增素材时更新 `manifest.csv`：`path, source, license_note, notes`。

## 授权提醒

`sheets/`、`characters/parts/`、`anim/` 里的原有素材来自 LimeZu Modern Interiors，属于付费素材，不能原样公开再分发。`.gitignore` 已排除这些目录，推送到公开仓库前请确认授权条款。
