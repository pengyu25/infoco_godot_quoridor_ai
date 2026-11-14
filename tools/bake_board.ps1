# 一次性素材烘焙 v5：纯暗色面板（无木纹），对齐 InfoCo 网站扁平语言
#   --ink #0d1117 / --panel #161b22 / --panel-2 #1c2128 / --line 10~18% 白 / --acid #3fb950
#
# 输出目录默认是「本脚本所在目录的上一级」下的 assets\sprites —— 跟着项目走，
# 项目搬到哪个盘、clone 到哪台电脑都不用改。想先看效果不覆盖原图：-OutDir <别的目录>
param(
    [string]$OutDir = (Join-Path (Split-Path -Parent $PSScriptRoot) "assets\sprites")
)

Add-Type -AssemblyName System.Drawing

New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$cell = 92
$frame = 18
$boardPx = $cell * 9
$canvas = $boardPx + $frame * 2

$ink = [System.Drawing.Color]::FromArgb(255, 13, 17, 23)
$panelTop = [System.Drawing.Color]::FromArgb(255, 30, 36, 44)
$panelBot = [System.Drawing.Color]::FromArgb(255, 19, 24, 31)
$text = [System.Drawing.Color]::FromArgb(255, 230, 237, 243)
$muted = [System.Drawing.Color]::FromArgb(255, 154, 164, 178)

function New-Graphics([System.Drawing.Bitmap]$bmp) {
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    return $g
}

function New-RoundedPath([int]$w, [int]$h, [int]$r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $p.AddArc(0, 0, $d, $d, 180, 90)
    $p.AddArc($w - $d, 0, $d, $d, 270, 90)
    $p.AddArc($w - $d, $h - $d, $d, $d, 0, 90)
    $p.AddArc(0, $h - $d, $d, $d, 90, 90)
    $p.CloseFigure()
    return $p
}

# ---------- 1) 页面背景（960×1080，顶部绿色微光）----------
$bw = 960; $bh = 1080
$bg = [System.Drawing.Bitmap]::new($bw, $bh)
$gb = New-Graphics $bg
$gb.FillRectangle([System.Drawing.SolidBrush]::new($ink), 0, 0, $bw, $bh)

$glowPath = New-Object System.Drawing.Drawing2D.GraphicsPath
$glowPath.AddEllipse(-260, -420, 1500, 900)
$pgb = New-Object System.Drawing.Drawing2D.PathGradientBrush($glowPath)
$pgb.CenterColor = [System.Drawing.Color]::FromArgb(26, 63, 185, 80)
$pgb.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 63, 185, 80))
$gb.FillPath($pgb, $glowPath)

for ($i = 0; $i -lt 60; $i++) {
    $a = [int](26 * (1 - $i / 60.0))
    $pen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb($a, 1, 4, 9), 1)
    $gb.DrawRectangle($pen, $i, $i, $bw - 1 - $i * 2, $bh - 1 - $i * 2)
}
$gb.Dispose()
$bg.Save("$outDir\bg.png", [System.Drawing.Imaging.ImageFormat]::Png)
$bg.Dispose()

# ---------- 2) 棋盘：纯面板 + 细线 ----------
$bmp = [System.Drawing.Bitmap]::new($canvas, $canvas)
$g = New-Graphics $bmp
$round = New-RoundedPath ($canvas - 1) ($canvas - 1) 12

# 纯色微渐变（上略亮，下略暗）
$rect = [System.Drawing.Rectangle]::new(0, 0, $canvas, $canvas)
$lg = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $panelTop, $panelBot, 90.0)
$g.FillPath($lg, $round)

# 顶端一条绿色微光（站点 accent）
$g.DrawLine([System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(80, 63, 185, 80), 2), 14, 2.2, $canvas - 14, 2.2)

# 面板描边
$border = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(56, 240, 246, 252), 2.0)
$g.DrawPath($border, $round)

# 可下区域边框
$innerPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(58, 240, 246, 252), 1.4)
$g.DrawRectangle($innerPen, $frame, $frame, $boardPx, $boardPx)

# 格线：细、清楚但不刺眼
$linePen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(40, 240, 246, 252), 1.3)
$lineStrong = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(72, 240, 246, 252), 1.7)
for ($i = 0; $i -le 9; $i++) {
    $p = $frame + $i * $cell
    $pen = $linePen
    if ($i -eq 0 -or $i -eq 9) { $pen = $lineStrong }
    $g.DrawLine($pen, $p, $frame, $p, $frame + $boardPx)
    $g.DrawLine($pen, $frame, $p, $frame + $boardPx, $p)
}

$g.Dispose()
$bmp.Save("$outDir\board.png", [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

# ---------- 3) 墙：浅色实心条 ----------
function New-WallSprite([int]$w, [int]$h, [string]$path) {
    $b = [System.Drawing.Bitmap]::new($w, $h)
    $gg = New-Graphics $b
    $rp = New-RoundedPath ($w - 2) ($h - 2) 6

    $r2 = [System.Drawing.Rectangle]::new(1, 1, $w - 2, $h - 2)
    $grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush($r2, $text, $muted, 90.0)
    $gg.FillPath($grad, $rp)
    $gg.DrawPath([System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(120, 13, 17, 23), 1.4), $rp)
    $gg.DrawLine([System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(110, 255, 255, 255), 1.1), 7, 3.2, $w - 7, 3.2)

    $gg.Dispose()
    $b.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $b.Dispose()
}

New-WallSprite 188 26 "$outDir\wall_h.png"
New-WallSprite 26 188 "$outDir\wall_v.png"

"baked v5 (flat dark panel, no wood)"
