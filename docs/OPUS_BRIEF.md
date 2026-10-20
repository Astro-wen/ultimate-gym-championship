# Opus 交接书：Ultimate Gym Championship

读完这份文档再动手。游戏设计和里程碑见 [PLAN.md](PLAN.md)，素材规范见 [../assets/README.md](../assets/README.md)。本文是**执行手册**：环境事实、接口约定、子 agent 分工、出图流程、测试要求、验收门槛、已知的坑。

审查者（Sonnet）会在每个里程碑结束时验收，验收标准写在第 8 节。不满足不算完成。

---

## 0. 开工前 10 分钟检查清单

按顺序做，任何一项失败先修好再继续。

1. 读 `docs/PLAN.md`、本文、`assets/README.md`。
2. 确认工程：`D:\game championship\project.godot` 存在，`addons/godot_ai/` 已启用。
3. 确认 Godot 命令行可用（见第 1 节命令），版本应为 `4.7.2.stable.steam...`。
4. 确认 Godot AI MCP 已连接（本会话的工具列表里能看到 godot 相关工具；若没有，说明会话不是从项目目录启动的，让用户重启会话）。
5. `git status` 确认是干净的 git 仓库，分支 `main`，`origin` 已设置，**没有推送过**。
6. 把第 9 节"待定决策"里的默认值当作已批准，不要为此询问用户。

---

## 1. 环境事实（已验证，不要重复排查）

| 项 | 值 |
|---|---|
| 项目根目录 | `D:\game championship` |
| 系统 | Windows 11，Shell 是 **Windows PowerShell 5.1**（没有 `&&`、`\|\|`、三元运算符） |
| Godot | 4.7.2，路径 `D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`（Steam 版） |
| Godot 编辑器 | 用户已打开本项目，Godot AI 插件 v4.3.0 已连接（WS 9500、HTTP 8000） |
| uv | `C:\Users\LinmengFDM\.local\bin\uv.exe` / `uvx.exe`，已全局固定 Python 3.12 |
| Node | v24，Codex CLI 0.163.0 已登录（ChatGPT 账号） |
| Git | 2.55，仓库已初始化，`origin` = `https://github.com/Astro-wen/ultimate-gym-championship.git`，远端是空的 |

### 1.1 Godot 命令行（重要）

这个 exe 是 GUI 子系统程序，**直接调用拿不到输出**。必须用 `Start-Process` 重定向：

```powershell
$g = "D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
$out = "$env:TEMP\godot_out.txt"; $err = "$env:TEMP\godot_err.txt"
Start-Process $g -ArgumentList "--headless","--path","D:\game championship","--quit-after","300" `
  -Wait -NoNewWindow -RedirectStandardOutput $out -RedirectStandardError $err
Get-Content $out; Get-Content $err
```

- 解析检查：`--headless --check-only -s <script.gd>`
- 跑测试：`--headless --path <proj> -s res://tests/run_all.gd`（见第 7 节）
- 参数里的路径要用 `"`"$PWD`""` 之类的方式加引号，路径含空格。

### 1.2 PowerShell 5.1 的坑

- `Set-Content` / `Out-File -Encoding utf8` 会写入 **BOM**，Godot 的 `project.godot`、`.tscn`、`.gd` 遇到 BOM 可能出问题。写文件用 Write 工具，或 `[IO.File]::WriteAllText(path, text, (New-Object Text.UTF8Encoding($false)))`。
- 新装的程序 PATH 不会自动刷新，需要时：
  `$env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [Environment]::GetEnvironmentVariable("Path","User")`
- 路径含中文（`rpgmaker素材`）时注意编码，尽量不要碰这个目录。

### 1.3 Godot 工程的坑

- `rpgmaker素材/` 里有 `.gdignore`，**不要删除**，否则 Godot 会给 1155 张图生成 `.import` 文件污染素材包。
- 不要手写复杂的 `.tscn`（UID、子资源 ID 容易出错）。优先用 Godot AI MCP 工具建场景，或用 GDScript 在代码里构建节点，必要时才手写最小 `.tscn`。
- 所有脚本用静态类型（`var x: int`、`func f() -> void`）。
- 修改 `project.godot` 里的输入映射、自动加载、碰撞层名，只允许**主控 agent**改（见第 4 节），避免并发冲突。

---

## 2. 目录结构与所有权

```
D:\game championship\
├─ project.godot              ← 仅主控 agent 可改
├─ scenes/
│   ├─ main.tscn              ← 仅主控 agent 可改
│   ├─ levels/                ← 关卡 agent
│   ├─ actors/                ← 角色/NPC agent
│   ├─ stations/              ← 器械 agent
│   └─ ui/                    ← UI agent
├─ scripts/
│   ├─ core/                  ← 主控：事件总线、GameState、常量
│   ├─ actors/                ← 角色 agent
│   ├─ stations/              ← 器械 agent
│   ├─ stealth/               ← 潜行 agent（视野、警戒、巡逻）
│   ├─ level/                 ← 关卡 agent
│   └─ ui/                    ← UI agent
├─ data/
│   ├─ stations/*.tres        ← StationData
│   ├─ npcs/*.tres            ← NpcData
│   └─ levels/*.tres
├─ tests/                     ← 每个 agent 各写自己模块的测试
├─ tools/art/                 ← 美术 agent：后处理脚本
├─ assets/                    ← 美术 agent，遵守 assets/README.md
└─ docs/                      ← 主控维护 STATUS.md
```

**一个文件同一时间只有一个所有者。** 要改别人的文件，先通过主控 agent。

---

## 3. 接口约定（所有 agent 必须遵守，主控在 M0 落地）

### 3.1 碰撞层（2D Physics Layer，在 project.godot 命名）

| 层 | 名称 | 用途 |
|---|---|---|
| 1 | `world` | 墙、不可通行的家具 |
| 2 | `player` | 玩家 |
| 3 | `npc` | NPC |
| 4 | `station` | 器械交互区域（Area2D） |
| 5 | `vision_blocker` | **挡视线**的物体（墙、隔断、柜子；玻璃不挡） |
| 6 | `cover` | 掩护点区域（Area2D，躲进去警戒回落更快） |
| 7 | `goal` | 电梯终点区域 |

注意：`world` 和 `vision_blocker` 是**两个独立的层**，因为有的东西挡路但不挡视线（低矮器械），有的挡视线但可穿过（帘子）。

### 3.2 输入映射

`move_left` `move_right` `move_up` `move_down`（方向键和 WASD）、`sprint`（按住 Shift，跑，警戒涨得更快）、`interact`（E 或空格）、`pause`（Esc）。**默认是慢走。**

### 3.3 全局事件总线（autoload `Events`，`scripts/core/events.gd`）

只用信号，不放逻辑：

```gdscript
signal player_detected(by: Node)          # 警戒条满了
signal alert_changed(value: float)        # 0.0 ~ 1.0，全局警戒
signal station_claimed(station: Node, who: Node)
signal station_released(station: Node, who: Node)
signal station_use_finished(station: Node, who: Node)
signal reached_goal()
signal run_started()
signal run_finished(result: Dictionary)   # {time, detections, perfect}
signal buff_applied(kind: StringName, duration: float)
```

### 3.4 `GameState`（autoload，`scripts/core/game_state.gd`）

保存当局状态：`elapsed`、`detections`、`active_buffs`、`state`（`READY/RUNNING/CAUGHT/WON`）。**重开必须调用 `reset()` 清空一切**，不允许有残留。

### 3.5 器械：`StationData`（Resource，`scripts/stations/station_data.gd`）

字段：`id: StringName`、`display_name: String`、`use_time: float`、`capacity: int`、`buff_kind: StringName`、`buff_duration: float`、`noise: float`（使用时产生的噪声，会吸引视野）、`anim_name: StringName`、`sprite_sheet: Texture2D`、`frames: int`、`anchor_offsets: Array[Vector2]`（每个使用位的站位）。

**新增一种器械只允许新增 `.tres` 和美术，不改任何脚本。** 审查时会用这条检验。

### 3.6 占用规则（必须严格实现，M1 重点）

- `Station.try_claim(who) -> bool` 原子操作，成功才返回 true。
- 任何导致使用者离开的路径（完成、被推开、被发现、重开、节点被释放）都必须调用 `release(who)`。**`_exit_tree` 里也要释放。**
- 同一个 `who` 不能同时占用两个器械。
- 被推开时有冷却，防止"互相推来推去"的抖动。
- 预约/排队：同一器械同一时刻最多 `capacity` 个占用者，其他人排队，排队有超时，超时换目标。

### 3.7 视野与警戒（M4 重点）

- `VisionCone`（`scripts/stealth/vision_cone.gd`）：参数 `angle_deg`、`range_px`、`ray_count`。用 `PhysicsDirectSpaceState2D.intersect_ray` 对 `vision_blocker` 层做射线检测，生成**被遮挡后的多边形**，同时用于**绘制**（半透明锥形）和**检测**。
- 检测点：玩家的 5 个采样点（中心加四角），任意点可见即视为可见，避免"半个身子露出来却没被发现"。
- 警戒公式（每个 NPC 独立的 `awareness`，0 到 1）：
  `rise = base_rise * distance_factor * speed_factor * (1 - cover_factor)`
  - `speed_factor`：静止 0.3、慢走 1.0、跑 2.5
  - `distance_factor`：越近越快，边缘最慢
  - `cover_factor`：在掩护区内为 0.5
  - 不可见时以固定速率回落，回落有短暂延迟
- 全局警戒 = 所有 NPC `awareness` 的最大值（不是求和）。`>= 1.0` 触发 `player_detected`。
- 被发现后：玩家被送回最近的安全点（或起点），`detections += 1`，该 NPC 进入短暂"追击后返回巡逻"状态，难度参数（视野大小、速度）按次数微升。

### 3.8 NPC 类型

| 类型 | 行为 |
|---|---|
| `Patroller`（需求人） | 沿路线巡逻，到路点会停下、转头扫视；有视野锥 |
| `Sitter`（坐着办公的同事） | 固定位置，视野锥窄，偶尔转椅子 |
| `GymGoer`（健身房竞争者） | 选器械、使用、被占了就等待或换目标；不是敌人，但在器械上会产生噪声，**被推开会吸引附近 Patroller 的视线** |

---

## 4. 子 agent 分工（建议）

**先串行，后并行。** M0 只能由一个主控 agent 做，因为它定义了所有接口。

| 阶段 | agent | 职责 | 依赖 |
|---|---|---|---|
| M0 | **主控** | 工程骨架、碰撞层、输入映射、autoload、地图占位、玩家移动、测试框架 | 无 |
| M1 | 器械 agent | `Station`、`StationData`、占用/预约/打断、结算、测试 | M0 |
| M1 | 美术 agent | 出图流水线、后处理脚本、器械单件裁切 | M0（可与 M0 并行启动） |
| M2 | 器械 agent | 3 种器械交互与动画 | M1、美术首批图 |
| M3 | 角色 agent | `GymGoer` 的 AI | M1 |
| M4 | 潜行 agent | 视野、警戒、巡逻、掩护 | M0 |
| M4 | 关卡 agent | 完整地图、路线、路点、遮挡体 | M0、M4 视野接口 |
| M5 | UI/循环 agent | HUD、警戒条、计时、结算、重开 | M3、M4 |
| M6 | 美术 agent | 统一风格、替换占位 | 全部 |
| M7 | **主控** | 集成、回归、难度、导出 | 全部 |

**并行规则**：
- 每个并行 agent 用独立的 git worktree（`isolation: worktree`），由主控合并，避免同时写同一个文件。
- 合并顺序按依赖，合并后必须跑全部测试，不通过不得提交。
- M4（潜行）与 M1、M2、M3 **互不依赖**，可以与它们同时进行。

---

## 5. 美术流水线（实测过的经验）

### 5.1 调用 Codex 出图

```powershell
$env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [Environment]::GetEnvironmentVariable("Path","User")
$prompt = @'
（多行提示词）
'@
$prompt | codex exec --skip-git-repo-check -s workspace-write -C "D:\game championship" -
```

- **提示词必须用管道传入（末尾的 `-`）**。把多行文本直接作为参数传，会被 `codex.ps1` 拆成多个参数而报错。
- 模型默认是 `gpt-6.1-sol`，不用指定。
- Codex 先把图保存到 `~\.codex\generated_images\...`，提示词里要明确让它**复制到目标路径**。
- 它的沙箱写不了项目外的目录；`-C` 指向项目根目录即可。
- **只用文字描述风格，不要把 LimeZu 素材作为参考图发给它**（授权考虑）。
- 一次调用约 20k tokens、数十秒到几分钟，可以并行多个。

### 5.2 实测结果与问题（卧推 4 帧样张）

样张在 `assets/generated/_raw/equip_benchpress_use_4f_ai_v1_raw.png`，**请先看一眼**。

- 好的：风格接近 RPG Maker，深色描边，色调柔和，姿势可读。
- 问题 1：输出尺寸不可控（给了 2172×724，3:1，不是 4 个正方形格）。
- 问题 2：**是高分辨率的"像素风插画"，不是严格的 48px 点阵**，直接缩小会糊。
- 问题 3：**帧间不对齐**：第 1 帧角色偏大偏左，杠铃位置和凳子位置都在漂，做成动画会抖。

### 5.3 应对策略（必须采用）

1. **分层，不要整图逐帧。** 器械静态底座（凳子、杠铃架）一张图，角色躺姿一张图，杠铃一张图。"杠铃上下推举"用 `Tween` 或 `AnimationPlayer` 改位置，不要靠 AI 逐帧画。AI 只负责出**静态部件**和**少量关键姿势**，对齐问题自然消失。
2. **统一分辨率目标**：游戏里角色约 48px 高，器械占 1.5 到 2 格。AI 出的大图要经过后处理：
   - 先按目标尺寸的整数倍（如 96 或 144 高）用 `Lanczos` 缩小，再**量化到固定调色板**，再用最近邻缩放到最终尺寸。
   - 调色板从 `assets/sheets/` 现有素材里提取（只在本地使用，用来统一色调，不上传）。
3. **对齐脚本**（`tools/art/align_frames.py`）：把每一帧按"器械底座底边中心"对齐到同一锚点，再裁成统一格子。
4. **一致性**：同一角色的不同姿势，生成时在提示词里固定外貌描述（发型、衣服颜色、体型），逐个姿势单独生成，不要期待一次出多个姿势还保持一致。
5. 后处理脚本用 uv 运行（Python 3.12 已固定）：
   `& "$env:USERPROFILE\.local\bin\uvx.exe" --with pillow python tools/art/xxx.py ...`

### 5.4 命名、归档、记录

- 命名：`类别_名称_动作_帧数f_来源_v版本.png`（见 `assets/README.md`）。
- 原始输出放 `assets/generated/_raw/`，处理后的放 `assets/sprites/` 或 `assets/anim/`。
- 每张 AI 图的**提示词**存到 `assets/generated/_prompts/<同名>.md`，并在 `assets/manifest.csv` 登记。
- 修改不覆盖旧版本，版本号递增。

### 5.5 首批美术清单（优先级顺序）

1. 玩家（办公室打工人）：待机、慢走 4 方向各 3 帧、跑 4 方向各 3 帧、被发现（惊讶）、按电梯
2. 需求人 NPC：行走 4 方向、转头扫视、追击
3. 同事（坐姿）：坐着办公、转椅
4. 健身器械：卧推（凳子加杠铃架加躺姿角色）、哑铃（站姿举哑铃）、跑步机（原地跑）
5. 健身房竞争者：用捏人素材 `assets/characters/parts/` 组合，不必都用 AI 出
6. 电梯（含开门动画）、办公桌、隔断、盆栽、打印机、饮水机：优先用现有素材 `assets/sheets/interiors/`，缺什么再补
7. UI：警戒条、视野锥贴图（半透明渐变）、提示图标

**原有素材优先**：能用 `int03/int19`（办公）、`int05`（健身器械）、`int07`（更衣）、`npc_walk_set*`、`npc_sit_set*` 的，就不要 AI 重画。缺口是：人使用器械的姿势、电梯、需求人的表情。

---

## 6. 地图与关卡设计规格（关卡 agent）

- 单层办公楼，约 40×25 格（1920×1200 px，48px 格）。
- 分区（从左到右）：工位区（起点）→ 会议室区 → 走廊 → 茶水间 → 健身房 → 电梯厅（终点）。
- 路线必须**至少有两条**：一条短而危险（穿过会议室区的视野），一条长而安全（绕茶水间）。健身房是必经的"瓶颈"，但里面有多个遮挡和掩护位。
- 至少放 4 个 `Patroller`、3 个 `Sitter`、3 个 `GymGoer`；视野范围允许少量重叠，但不能让任何一处必然被发现（每处都必须存在可通过的时间窗口）。
- 每个视野扫视周期要让玩家**可预测、可学习**：路点停留时间固定，不随机到不可判断。
- 起点和每个区域入口附近放"安全点"，被发现后回到最近安全点。

---

## 7. 测试要求（所有 agent 必须写，我会运行）

### 7.1 测试入口

`tests/run_all.gd`：`extends SceneTree`，逐个运行 `tests/test_*.gd`，打印 `[PASS]` / `[FAIL] 名称: 原因`，**有失败时 `quit(1)`，全通过 `quit(0)`**。

```powershell
Start-Process $g -ArgumentList "--headless","--path","D:\game championship","-s","res://tests/run_all.gd" -Wait -NoNewWindow -RedirectStandardOutput $out -RedirectStandardError $err
```

### 7.2 必须有的测试

| 模块 | 测试内容 |
|---|---|
| Station | 占用原子性；1000 次随机操作（占用、释放、推开、节点销毁）后无"永久被占"、同一角色不会占两个、属性不重复结算 |
| Station | 器械只靠 `.tres` 新增：加载所有 `data/stations/*.tres`，全部能实例化并完成一次使用 |
| Vision | 墙挡视线（射线）；玻璃不挡；锥角边界（刚好在边缘内和外）；5 个采样点逻辑 |
| 警戒 | 慢走 vs 跑速率比；掩护区衰减；多个 NPC 取最大值；回落延迟 |
| NPC | 3 个 GymGoer 模拟 5 分钟（用加速的物理帧）无死锁、无重叠站位、无永久等待 |
| GameState | `reset()` 后与新建完全一致；重开 20 次无泄漏（`Performance.get_monitor(OBJECT_COUNT)` 稳定） |
| 关卡 | 从起点到电梯存在可达路径（导航网格），且每个区域的安全点可达 |

测试不是装饰：**我会故意改坏实现，看测试能不能抓住。**

---

## 8. 每个里程碑的验收门槛

提交前自查，缺一项就不要提交。

- [ ] 项目无头启动，`stdout`/`stderr` 无 `ERROR`、`WARNING: ... GDScript` 级别的解析警告
- [ ] `tests/run_all.gd` 全通过，退出码 0
- [ ] 所有新增脚本有静态类型、无未使用变量警告
- [ ] 通过 Godot AI MCP 实际运行游戏、截图确认画面（附到 `docs/STATUS.md`）
- [ ] 无硬编码数值：可调参数用 `@export` 或 `.tres`
- [ ] `docs/STATUS.md` 更新：本里程碑完成了什么、已知问题、下一步
- [ ] git 提交，一次一个里程碑（或一个逻辑单元），提交信息清楚
- [ ] 没有提交 `rpgmaker素材/`、`assets/sheets/`、`assets/characters/parts/`、`assets/anim/` 里的受授权素材（`.gitignore` 已拦截，不要用 `-f` 强制添加）
- [ ] **不要 `git push`**，没有用户明确同意前不推送

具体里程碑的验收条目见 `PLAN.md` 第 3 节。

---

## 9. 待定决策（已给默认值，直接采用，不要询问用户）

| 问题 | 默认 |
|---|---|
| 视野锥默认角度/距离 | 70°，6 格（Patroller）；40°，4 格（Sitter） |
| 被发现后的惩罚 | 回安全点，`detections += 1`，该 NPC 难度参数上调 5%（上限 +30%） |
| 健身增益 | 做完一组后 8 秒内被发现速度降低 40%；不同器械颜色提示不同 |
| 地图尺寸 | 40×25 格，48px |
| 玩家速度 | 慢走 70 px/s，跑 160 px/s |
| 难度 | 一个难度，M7 再调 |
| 音效 | M6 用免费/自制简单音效，BGM 一首循环 |
| 分辨率 | 960×540，canvas_items 拉伸，纹理最近邻 |
| 语言 | UI 文字中文（简体），代码标识符英文 |

---

## 10. 禁止事项

1. 不要删除或移动 `rpgmaker素材/`，也不要在里面生成任何文件。
2. 不要用 `git push`、`git push --force`、`git reset --hard`、改写历史，除非用户明确说。
3. 不要把 LimeZu 素材作为参考图发给 Codex 或任何外部服务。
4. 不要新增大型第三方依赖或插件（Godot AI 之外），需要先问用户。
5. 不要用 `-f` 强行添加被 `.gitignore` 忽略的文件。
6. 不要为了让测试通过而改测试断言；测试不对时，先说明为什么，再改。
7. 不要在主线程里做重计算（如每帧大量射线）：视野射线数量可配置，默认每锥 48 条以内，必要时隔帧更新。
8. 不要把"能跑起来"当作完成。完成 = 验收门槛全部满足。

---

## 11. 出现分歧或不确定时

- 设计问题：以 `PLAN.md` 第 1 节为准；没写的，用第 9 节默认值；仍不确定，选**最简单、最可测试**的方案，并记入 `STATUS.md`，**不要停下来问用户**。
- 技术阻塞超过 15 分钟：记录现象和已尝试的办法到 `STATUS.md`，换一个任务，不要空转。
- 发现本文档有错误或与实际不符：以实际为准，并**修正本文档**，在 `STATUS.md` 里说明改了什么。
