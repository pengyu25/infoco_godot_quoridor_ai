# Quoridor · 步步为营（本地双人）

InfoCo 编程社 · 社团文化节展示作品。引擎：**Godot 4.7**（GDScript）。

> **状态（W1 完成于 2026-10-23；2026-11-13 按开发约定整理了一轮代码与文档）**：规则引擎 + headless 测试（**63 项全绿**）+ 最小可玩界面已就位——点自己的棋子走子、按钮切放墙模式、随时重开。W2 做交互打磨与结算界面。目标 **11/20 社团文化节**展示。
> **分工**：初版（规则引擎 + 同屏双人界面 + Web 打包）由 pppig 与小龙虾完成；之后由合作方接力做完善（手感 / 美术 / 文案）与**单机 AI 逻辑、难度调整**。
> 接 AI 前请先读 [`技术骨架.md`](技术骨架.md) 第 5 节——**只依赖那套接口，不要改规则引擎**。

## 玩法（标准《步步为营》规则）

- 棋盘 **9×9**，双方各 1 枚棋子，从己方底线中央出发，**先走到对面底线任意一格者胜**
- 每回合二选一：
  1. **走子**：正交走一格；正对对手棋子时可跳过它（越过的格子被墙/边界挡住时，可斜走绕到对手旁边）
  2. **放墙**：在格线上放一堵墙（长 2 格），每人共 **10 堵**
- 墙不能重叠、不能交叉，且**不能把任意一方的通路彻底封死**（每次放墙做一次 BFS 通路校验，非法则拒绝）
- 同屏双人轮流操作（热座），一局约 3 分钟

## 运行

1. 用 **Godot 4.7** 打开本目录
2. 按 **F5** 运行

**怎么玩（当前 W1 版）**

- 点自己的棋子（蓝=玩家1，橙=玩家2）→ 出现可走位置绿点 → 点目标格走子
- 想放墙：点底部「放墙模式」，然后点棋盘上靠近某条格线的位置；放完自动退出放墙模式
- 距离最近的格线决定是横墙还是竖墙；非法位置会在顶部提示（重叠 / T 形或十字交叉 / 墙数不足 / 会封死通路）
- 谁先走到对面底线任意一格即胜

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

# 单元测试（63 项断言：规则引擎 + 棋盘坐标换算），退出码 0 = 全过
& $env:GODOT --headless --path . --script tests/run_tests.gd

# 自对弈压力测试 + 性能取样
& $env:GODOT --headless --path . --script tests/selfplay.gd

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
  main.gd          场景入口：持有局面，把点击翻译成着法
  rules/           ★ 规则引擎：纯逻辑、零 UI 依赖、可 headless 测试
  ui/              棋盘渲染与输入、坐标换算、HUD
  ai/              （待建）单机 AI 与难度参数，合作方接力
tests/             run_tests.gd（入口）、cases/（用例）、selfplay.gd、shot.gd
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
