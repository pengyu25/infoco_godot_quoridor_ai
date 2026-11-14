# Quoridor · 步步为营（双人 / 人机 / AI 对战）

InfoCo 编程社 · 社团文化节展示作品。引擎：**Godot 4.7**（GDScript）。

> **状态（W1 完成于 2026-10-23；2026-11-13 加入人机对战；2026-11-14 加入大模型对战）**：规则引擎 + headless 测试（**183 项全绿**）+ 可玩界面已就位——开局菜单选「双人对战」「人机对战 · 低 / 中 / 高」或「AI 对战 · 大模型」，点自己的棋子走子、按钮切放墙模式、随时重开或回菜单。W2 做交互打磨与结算界面。目标 **11/20 社团文化节**展示。
> **分工**：初版（规则引擎 + 同屏双人界面 + Web 打包）由 pppig 与小龙虾完成；之后由合作方接力做完善（手感 / 美术 / 文案）。
> 本地电脑对手见 [`技术骨架.md`](技术骨架.md) 第 7 节，大模型对战见第 14 节；改对手只依赖第 5 节接口，**不要改规则引擎**。

## 玩法（标准《步步为营》规则）

- 棋盘 **9×9**，双方各 1 枚棋子，从己方底线中央出发，**先走到对面底线任意一格者胜**
- 每回合二选一：
  1. **走子**：正交走一格；正对对手棋子时可跳过它（越过的格子被墙/边界挡住时，可斜走绕到对手旁边）
  2. **放墙**：在格线上放一堵墙（长 2 格），每人共 **10 堵**
- 墙不能重叠、不能交叉，且**不能把任意一方的通路彻底封死**（每次放墙做一次 BFS 通路校验，非法则拒绝）
- 一局约 3 分钟

## 对战模式

| 模式 | 说明 |
|------|------|
| 双人对战（同屏） | 两人轮流操作同一台电脑（热座），蓝方先手 |
| 人机对战 · 低 | 电脑只挑离终点最近的一步，经常随便走，不放墙 |
| 人机对战 · 中 | 电脑往后看 2 步，会放墙挡你 |
| 人机对战 · 高 | 电脑往后看 3 步，每步最多想约 1 秒 |
| AI 对战 · 大模型 | 和 DeepSeek 大模型下棋，对手带你设定的人设，每走一步都会说一句话；需要你自己的 API key |

人机 / AI 对战里你执蓝先手，对手执橙。对手思考时棋盘不响应点击；这时点「重开一局」或「菜单」可以直接放弃这一局。

### AI 对战（大模型）怎么用

1. 到 [DeepSeek 开放平台](https://platform.deepseek.com/) 申请 API key（按用量付费，一局大约几分钱人民币）
2. 开局菜单点「设置」：
   - 粘贴 API key（输入框默认遮挡；可点「测试连接」确认能用，不产生费用）
   - **公用电脑请取消「保存到本机」**：key 只留在内存里，关掉游戏就没了
   - 填角色名和性格提示词（例如你想让它扮演的角色）。规则和下棋方法已经内置，这里只写性格和说话风格；不填就用默认性格
3. 回到菜单点「AI 对战 · 大模型」。没配 key 会提示你先去设置
4. 对局中：
   - 对手每走一步都会在顶部说一句话；开局打招呼、终局说感想（设置里可关）
   - 底部输入框可以跟它聊天，它会在下一步时回应
   - 网络出错或它连续走错时，这一步由本地电脑代下，对局不会卡住；key 无效时本局剩下的都由电脑代下

> **隐私**：key 只保存在本机（桌面版在系统用户目录，Web 版在浏览器本地存储），不会上传到别处，也不进仓库；但这只是明文保存，不是加密。保存后设置页只显示首尾几位。

## 运行

1. 用 **Godot 4.7** 打开本目录
2. 按 **F5** 运行，在开局菜单里选模式

**怎么玩**

- 点自己的棋子（蓝=玩家1，橙=玩家2）→ 出现可走位置绿点 → 点目标格走子
- 想放墙：点底部「放墙模式」，然后点棋盘上靠近某条格线的位置；放完自动退出放墙模式
- 距离最近的格线决定是横墙还是竖墙；非法位置会在顶部提示（重叠 / T 形或十字交叉 / 墙数不足 / 会封死通路）
- 谁先走到对面底线任意一格即胜
- 底栏「重开一局」保留当前模式和难度；「菜单」回到开局菜单换模式

> **已知问题**：一方墙用完、终点只剩一个入口时，另一方可以站在入口来回挪、永久堵住，对局结束不了。原版官方规则同样没有和棋判定（比赛靠给每人限时解决），本项目暂按原版不加。这时可点「重开一局」。详见技术骨架 7.5 节。

### 命令行

仓库里**不写死任何盘符路径**：项目位置用相对路径（在项目根目录执行，`--path .` 就是当前目录），Godot 的位置由每台电脑自己告诉终端。

```powershell
# 每台电脑做一次：告诉终端 Godot 在哪（换成你自己的安装位置）
# 官网下载版请指向带 _console 的那个 exe，否则终端里看不到输出
$env:GODOT = "<你的 Godot 4.7 可执行文件完整路径>"
```

> 上面这行只对当前终端窗口有效。想一劳永逸：把它写进 PowerShell 的 `$PROFILE`，或者把 Godot 所在目录加进系统 PATH（那样下面的 `& $env:GODOT` 换成 `godot` 即可）。

```powershell
# 启动游戏
& $env:GODOT --path .

# 单元测试（183 项断言：规则引擎 + 棋盘坐标换算 + 电脑对手 + 大模型对战），退出码 0 = 全过，约 5 秒
# 大模型部分用假客户端，不联网、不需要 key
& $env:GODOT --headless --path . --script tests/run_tests.gd

# 自对弈压力测试 + 性能取样
& $env:GODOT --headless --path . --script tests/selfplay.gd

# 电脑强度评估：各档互相对战 10 局，打印胜率与每步思考时间，约 1 分钟
& $env:GODOT --headless --path . --script tests/ai_match.gd

# 界面冒烟测试：模拟点击走一遍菜单 / 人机 / 重开 / 双人（会弹出窗口，不能加 --headless）
& $env:GODOT --path . --script tests/ui_smoke.gd

# 大模型对战界面冒烟测试：设置页、开场白、台词、聊天、出错兜底、重开（假客户端，会弹出窗口）
& $env:GODOT --path . --script tests/ui_llm_smoke.gd

# 大模型联调：没设 DEEPSEEK_API_KEY 时只用无效 key 测网络（不花钱）；
# 设了就用你的 key 真下 3 步，打印延迟和台词（会产生少量费用，key 只显示首尾）
& $env:GODOT --headless --path . --script tests/llm_live.gd

# 截图目检（确认字体/棋盘没画错），生成 tmp_shot.png（已在 .gitignore 里）
& $env:GODOT --path . --script tests/shot.gd
```

刚 clone 下来、还没用编辑器打开过项目时，先跑一次 `& $env:GODOT --headless --path . --import` 生成导入缓存（`.godot/` 不进仓库）。

## 导出

> ⚠️ 仓库里**还没有** `export_presets.cfg`：导出前要先在编辑器「项目 → 导出」里建好下面两个预设，并安装与引擎版本一致的导出模板。

| 预设 | 说明 |
|------|------|
| Windows Desktop | 输出 `build/Quoridor.exe` |
| Web（HTML5） | **主交付**（社团网站游戏中心）：`thread_support` / `extensions_support` 均关闭；wasm 需 gzip 处理才能过 Cloudflare 25MiB 单资源上限 —— 完整步骤见 [`导出与体积.md`](导出与体积.md) |

## 项目结构

```
project.godot
scenes/            main.tscn（主场景）
scripts/
  main.gd          场景入口：状态机，决定轮到人 / 电脑 / 大模型
  human_turn.gd    人的回合：点击 → 着法
  computer_turn.gd 本地电脑回合调度（不卡画面、可作废）
  llm_turn.gd      大模型回合调度（问模型、出错由电脑兜底、开场白 / 感言）
  rules/           ★ 规则引擎：纯逻辑、零 UI 依赖、可 headless 测试
  ai/              本地电脑对手：难度参数表、搜索、候选着法、评估（纯逻辑）
  llm/             大模型对战：设置、记谱法、提示词、工具表、DeepSeek 客户端、agent 循环
  ui/              棋盘渲染与输入、坐标换算、HUD、菜单、设置页、聊天框、对局文案、公用样式
tests/             run_tests.gd（入口）、cases/（用例）、假客户端、自对弈、强度评估、两个界面冒烟、联调、截图
tools/             bake_board.ps1（烘焙棋盘 / 背景 / 墙贴图）
assets/            sprites（贴图）、fonts（中文字体），见 assets/素材清单.md
技术骨架.md         实现蓝图 + 接口契约 + 验收依据（改代码前必读）
导出与体积.md       Web 导出与 wasm gzip 方案
```

## 开发约定（摘要）

- 规则引擎放 `scripts/rules/`，**纯逻辑**：不引用场景、UI、`Input`、`OS`；可 headless 跑测试
- UI 与 AI 只通过 [`技术骨架.md`](技术骨架.md) 第 5 节的接口读局面，不直接读墙的内部数组
- 命名遵循 Godot 官方风格指南：节点/类 PascalCase、变量/函数 snake_case、常量 ALL_CAPS；注释中文
- 单文件 ≤150 行，超了拆；不用 autoload
- 文档、脚本里**不写绝对路径**（项目内用相对路径 / `res://`，Godot 位置用 `$env:GODOT`）
- 每个里程碑都要**可运行**，不提交半成品
- 提交前跑一遍 `tests/run_tests.gd`

## Credits（素材来源）

| 素材 | 作者 | 来源 | 协议 | 状态 |
|------|------|------|------|------|
| Board Game Pack（棋子） | Kenney | [kenney.nl/assets/boardgame-pack](https://kenney.nl/assets/boardgame-pack) | CC0 | 已使用 |
| Zpix 最像素字体（中文） | SolidZORO | [github.com/SolidZORO/zpix-pixel-font](https://github.com/SolidZORO/zpix-pixel-font) | MIT | 已使用 |
| UI Pack（图标 / 音效） | Kenney | [kenney.nl/assets/ui-pack](https://kenney.nl/assets/ui-pack) | CC0 | 备选，尚未入库 |
| Music Jingles（音效） | Kenney | [kenney.nl/assets/music-jingles](https://kenney.nl/assets/music-jingles) | CC0 | W3 计划引用，尚未入库 |

详见 [`assets/素材清单.md`](assets/素材清单.md)。

> 素材与导出经验复用自同社群的 Godot 三消项目（`godot-match3`，独立工程，不在本仓库内），代码为全新实现。

---

InfoCo | Godot 4.7 | 骨架版 v1 | 2026
