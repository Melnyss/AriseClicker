#Requires -Version 5.0
# AriseClicker - Autoclicker con GUI minimal dark
# Avvio: powershell -ExecutionPolicy Bypass -Command "Invoke-Expression (Invoke-RestMethod 'https://raw.githubusercontent.com/<user>/<repo>/main/AriseClicker.ps1')"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

if (-not ("AutoClicker.Native" -as [type])) {
    Add-Type -Language CSharp -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace AutoClicker
{
    public class Native
    {
        [DllImport("user32.dll")]
        public static extern bool ReleaseCapture();

        [DllImport("user32.dll")]
        public static extern int SendMessage(IntPtr hWnd, int Msg, int wParam, int lParam);

        [DllImport("user32.dll")]
        public static extern short GetAsyncKeyState(int vKey);

        [DllImport("dwmapi.dll")]
        public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);
    }

    [StructLayout(LayoutKind.Sequential)]
    struct MOUSEINPUT
    {
        public int dx;
        public int dy;
        public uint mouseData;
        public uint dwFlags;
        public uint time;
        public IntPtr dwExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct INPUT
    {
        public int type;
        public MOUSEINPUT mi;
    }

    public class MouseSim
    {
        [DllImport("user32.dll")]
        static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);

        const int INPUT_MOUSE = 0;
        const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
        const uint MOUSEEVENTF_LEFTUP = 0x0004;
        const uint MOUSEEVENTF_RIGHTDOWN = 0x0008;
        const uint MOUSEEVENTF_RIGHTUP = 0x0010;

        public static void Click(bool rightButton)
        {
            uint down = rightButton ? MOUSEEVENTF_RIGHTDOWN : MOUSEEVENTF_LEFTDOWN;
            uint up = rightButton ? MOUSEEVENTF_RIGHTUP : MOUSEEVENTF_LEFTUP;

            INPUT[] inputs = new INPUT[2];
            inputs[0] = new INPUT { type = INPUT_MOUSE, mi = new MOUSEINPUT { dwFlags = down } };
            inputs[1] = new INPUT { type = INPUT_MOUSE, mi = new MOUSEINPUT { dwFlags = up } };
            SendInput(2, inputs, Marshal.SizeOf(typeof(INPUT)));
        }
    }
}
'@
}

# ---------- Palette (dark minimal) ----------
$colBg          = [System.Drawing.Color]::FromArgb(10,10,11)
$colCard        = [System.Drawing.Color]::FromArgb(22,22,25)
$colCardBorder  = [System.Drawing.Color]::FromArgb(40,40,44)
$colInputBg     = [System.Drawing.Color]::FromArgb(30,30,34)
$colHover       = [System.Drawing.Color]::FromArgb(40,40,44)
$colTextPrimary = [System.Drawing.Color]::FromArgb(245,245,247)
$colTextMuted   = [System.Drawing.Color]::FromArgb(142,142,150)
$colTextFaint   = [System.Drawing.Color]::FromArgb(88,88,94)

$fontTitle   = New-Object System.Drawing.Font("Segoe UI",9.5,[System.Drawing.FontStyle]::Bold)
$fontCredit  = New-Object System.Drawing.Font("Segoe UI",7.5,[System.Drawing.FontStyle]::Bold)
$fontSection = New-Object System.Drawing.Font("Segoe UI",8,[System.Drawing.FontStyle]::Bold)
$fontLabel   = New-Object System.Drawing.Font("Segoe UI",8.5)
$fontSmall   = New-Object System.Drawing.Font("Segoe UI",8.5)
$fontStatBig = New-Object System.Drawing.Font("Segoe UI",26,[System.Drawing.FontStyle]::Bold)
$fontStatLbl = New-Object System.Drawing.Font("Segoe UI",7.5)
$fontMicro   = New-Object System.Drawing.Font("Segoe UI",7.5)
$fontIcon    = New-Object System.Drawing.Font("Segoe UI",10)

$CONTENT_X = 16
$CONTENT_W = 308
$CORNER_RADIUS = 12

# ---------- Geometry helpers ----------
function New-RoundedPath {
    param([int]$Width,[int]$Height,[int]$Radius)
    $d = $Radius * 2
    if ($d -gt $Width)  { $d = $Width }
    if ($d -gt $Height) { $d = $Height }
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc(0,0,$d,$d,180,90)
    $path.AddArc($Width-$d,0,$d,$d,270,90)
    $path.AddArc($Width-$d,$Height-$d,$d,$d,0,90)
    $path.AddArc(0,$Height-$d,$d,$d,90,90)
    $path.CloseFigure()
    return $path
}

function Set-RoundedRegion {
    param($Control,[int]$Radius = 10)
    $p = New-RoundedPath -Width $Control.Width -Height $Control.Height -Radius $Radius
    $Control.Region = New-Object System.Drawing.Region($p)
    $p.Dispose()
}

function New-CardBorderHandler {
    param([int]$Radius = 12,$Color = $colCardBorder)
    return {
        param($s,$e)
        $e.Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $p = New-RoundedPath -Width ($s.Width-1) -Height ($s.Height-1) -Radius $Radius
        $pen = New-Object System.Drawing.Pen($Color,1)
        $e.Graphics.DrawPath($pen,$p)
        $pen.Dispose(); $p.Dispose()
    }.GetNewClosure()
}

function New-Card {
    param([int]$X,[int]$Y,[int]$Width,[int]$Height,[int]$Radius = 12)
    $c = New-Object System.Windows.Forms.Panel
    $c.Location = New-Object System.Drawing.Point($X,$Y)
    $c.Size = New-Object System.Drawing.Size($Width,$Height)
    $c.BackColor = $colCard
    Set-RoundedRegion -Control $c -Radius $Radius
    $c.Add_Paint((New-CardBorderHandler -Radius $Radius -Color $colCardBorder))
    return $c
}

function New-SectionLabel {
    param([string]$Text,[int]$X,[int]$Y)
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $Text.ToUpper()
    $l.Font = $fontSection
    $l.ForeColor = $colTextMuted
    $l.AutoSize = $true
    $l.Location = New-Object System.Drawing.Point($X,$Y)
    $l.BackColor = [System.Drawing.Color]::Transparent
    return $l
}

# ---------- Pill button: fully hand-painted (no Region clipping -> no corner artifacts) ----------
function New-RoundButton {
    param([string]$Text,[int]$Width,[int]$Height,$FillColor,$HoverColor,$ForeColor,$HoverForeColor,[int]$Radius = 10,$Font,$BgBehind)
    $b = New-Object System.Windows.Forms.Panel
    $b.Size = New-Object System.Drawing.Size($Width,$Height)
    $b.Cursor = [System.Windows.Forms.Cursors]::Hand
    if ($BgBehind) { $b.BackColor = $BgBehind } else { $b.BackColor = $colCard }
    if (-not $HoverForeColor) { $HoverForeColor = $ForeColor }
    $b | Add-Member -NotePropertyName BtnText -NotePropertyValue $Text -Force
    $b | Add-Member -NotePropertyName FillColor -NotePropertyValue $FillColor -Force
    $b | Add-Member -NotePropertyName HoverColor -NotePropertyValue $HoverColor -Force
    $b | Add-Member -NotePropertyName TextColor -NotePropertyValue $ForeColor -Force
    $b | Add-Member -NotePropertyName HoverTextColor -NotePropertyValue $HoverForeColor -Force
    $b | Add-Member -NotePropertyName BtnRadius -NotePropertyValue $Radius -Force
    $b | Add-Member -NotePropertyName BtnFont -NotePropertyValue $Font -Force
    $b | Add-Member -NotePropertyName IsHover -NotePropertyValue $false -Force

    $b.Add_Paint({
        param($s,$e)
        $e.Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $fill = if ($s.IsHover) { $s.HoverColor } else { $s.FillColor }
        $fg = if ($s.IsHover) { $s.HoverTextColor } else { $s.TextColor }
        $path = New-RoundedPath -Width $s.Width -Height $s.Height -Radius $s.BtnRadius
        $brush = New-Object System.Drawing.SolidBrush($fill)
        $e.Graphics.FillPath($brush,$path)
        $brush.Dispose(); $path.Dispose()
        if ($s.BtnText) {
            $sf = New-Object System.Drawing.StringFormat
            $sf.Alignment = [System.Drawing.StringAlignment]::Center
            $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
            $tb = New-Object System.Drawing.SolidBrush($fg)
            $rect = New-Object System.Drawing.RectangleF(0,0,$s.Width,$s.Height)
            $e.Graphics.DrawString($s.BtnText,$s.BtnFont,$tb,$rect,$sf)
            $tb.Dispose(); $sf.Dispose()
        }
    })
    $b.Add_MouseEnter({ $this.IsHover = $true; $this.Invalidate() })
    $b.Add_MouseLeave({ $this.IsHover = $false; $this.Invalidate() })
    return $b
}

function Set-ButtonStyle {
    param($Btn,$FillColor,$TextColor,$HoverColor,$HoverTextColor)
    $Btn.FillColor = $FillColor
    $Btn.TextColor = $TextColor
    if ($HoverColor) { $Btn.HoverColor = $HoverColor } else { $Btn.HoverColor = $FillColor }
    if ($HoverTextColor) { $Btn.HoverTextColor = $HoverTextColor } else { $Btn.HoverTextColor = $TextColor }
    $Btn.Invalidate()
}

# ---------- Toggle pair (segmented 2-option control) ----------
function New-TogglePair {
    param([string]$TextA,[string]$TextB,[int]$X,[int]$Y,[int]$Width,[int]$Height = 30,[int]$Selected = 0)
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Location = New-Object System.Drawing.Point($X,$Y)
    $panel.Size = New-Object System.Drawing.Size($Width,$Height)
    $panel.BackColor = $colCard

    $gap = 6
    $w = [int](($Width - $gap) / 2)

    $btnA = New-RoundButton -Text $TextA -Width $w -Height $Height -FillColor $colInputBg -HoverColor $colHover -ForeColor $colTextMuted -Radius 8 -Font $fontSmall -BgBehind $colCard
    $btnB = New-RoundButton -Text $TextB -Width $w -Height $Height -FillColor $colInputBg -HoverColor $colHover -ForeColor $colTextMuted -Radius 8 -Font $fontSmall -BgBehind $colCard
    $btnA.Location = New-Object System.Drawing.Point(0,0)
    $btnB.Location = New-Object System.Drawing.Point(($w + $gap),0)
    $panel.Controls.AddRange(@($btnA,$btnB))

    $group = [PSCustomObject]@{ Panel=$panel; A=$btnA; B=$btnB; Selected=-1; OnChange=$null }

    $setSel = {
        param($idx)
        if ($idx -eq 0) {
            Set-ButtonStyle -Btn $btnA -FillColor $colTextPrimary -TextColor $colBg -HoverColor $colTextPrimary -HoverTextColor $colBg
            Set-ButtonStyle -Btn $btnB -FillColor $colInputBg -TextColor $colTextMuted -HoverColor $colHover -HoverTextColor $colTextPrimary
        } else {
            Set-ButtonStyle -Btn $btnB -FillColor $colTextPrimary -TextColor $colBg -HoverColor $colTextPrimary -HoverTextColor $colBg
            Set-ButtonStyle -Btn $btnA -FillColor $colInputBg -TextColor $colTextMuted -HoverColor $colHover -HoverTextColor $colTextPrimary
        }
        $group.Selected = $idx
        if ($group.OnChange) { & $group.OnChange $idx }
    }.GetNewClosure()

    $btnA.Add_Click({ & $setSel 0 }.GetNewClosure())
    $btnB.Add_Click({ & $setSel 1 }.GetNewClosure())
    & $setSel $Selected

    $group | Add-Member -NotePropertyName SetSelected -NotePropertyValue $setSel -Force
    return $group
}

# ---------- Toggle switch ----------
function New-ToggleSwitch {
    param([int]$X,[int]$Y,[bool]$Checked = $false)
    $sw = New-Object System.Windows.Forms.Panel
    $sw.Location = New-Object System.Drawing.Point($X,$Y)
    $sw.Size = New-Object System.Drawing.Size(34,18)
    $sw.Cursor = [System.Windows.Forms.Cursors]::Hand
    $sw.BackColor = $colCard
    $sw | Add-Member -NotePropertyName Checked -NotePropertyValue $Checked -Force
    $sw | Add-Member -NotePropertyName OnChange -NotePropertyValue $null -Force

    $sw.Add_Paint({
        param($s,$e)
        $e.Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $trackColor = if ($s.Checked) { $colTextPrimary } else { $colInputBg }
        $path = New-RoundedPath -Width $s.Width -Height $s.Height -Radius ([int]($s.Height/2))
        $brush = New-Object System.Drawing.SolidBrush($trackColor)
        $e.Graphics.FillPath($brush,$path)
        $brush.Dispose(); $path.Dispose()
        $d = $s.Height - 6
        $x = if ($s.Checked) { $s.Width - $d - 3 } else { 3 }
        $thumbColor = if ($s.Checked) { $colBg } else { $colTextMuted }
        $tb = New-Object System.Drawing.SolidBrush($thumbColor)
        $e.Graphics.FillEllipse($tb,$x,3,$d,$d)
        $tb.Dispose()
    })
    $sw.Add_Click({
        param($s,$e)
        $s.Checked = -not $s.Checked
        $s.Invalidate()
        if ($s.OnChange) { & $s.OnChange $s.Checked }
    })
    return $sw
}

# ---------- Slider ----------
function New-Slider {
    param([int]$X,[int]$Y,[int]$Width,[int]$Height = 26,[int]$Min = 1,[int]$Max = 100,[int]$Value = 10)
    $s = New-Object System.Windows.Forms.Panel
    $s.Location = New-Object System.Drawing.Point($X,$Y)
    $s.Size = New-Object System.Drawing.Size($Width,$Height)
    $s.Cursor = [System.Windows.Forms.Cursors]::Hand
    $s.BackColor = $colCard
    $s | Add-Member -NotePropertyName Min -NotePropertyValue $Min -Force
    $s | Add-Member -NotePropertyName Max -NotePropertyValue $Max -Force
    $s | Add-Member -NotePropertyName Value -NotePropertyValue $Value -Force
    $s | Add-Member -NotePropertyName OnChange -NotePropertyValue $null -Force
    $s | Add-Member -NotePropertyName Dragging -NotePropertyValue $false -Force

    $thumbD = 14

    $s.Add_Paint({
        param($ctl,$e)
        $e.Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $trackH = 6
        $trackY = [int](($ctl.Height - $trackH)/2)
        $usable = $ctl.Width - 14
        $ratio = ($ctl.Value - $ctl.Min) / [double]($ctl.Max - $ctl.Min)
        if ($ratio -lt 0) { $ratio = 0 }; if ($ratio -gt 1) { $ratio = 1 }
        $thumbX = [int]($ratio * $usable)

        $trackPath = New-RoundedPath -Width $ctl.Width -Height $trackH -Radius ([int]($trackH/2))
        $g2 = $e.Graphics
        $g2.TranslateTransform(0,$trackY)
        $brushTrack = New-Object System.Drawing.SolidBrush($colInputBg)
        $g2.FillPath($brushTrack,$trackPath)
        $brushTrack.Dispose(); $trackPath.Dispose()

        $fillW = $thumbX + 7
        if ($fillW -lt $trackH) { $fillW = $trackH }
        $fillPath = New-RoundedPath -Width $fillW -Height $trackH -Radius ([int]($trackH/2))
        $brushFill = New-Object System.Drawing.SolidBrush($colTextPrimary)
        $g2.FillPath($brushFill,$fillPath)
        $brushFill.Dispose(); $fillPath.Dispose()
        $g2.TranslateTransform(0,-$trackY)

        $thumbY = [int](($ctl.Height - 14)/2)
        $pen = New-Object System.Drawing.Pen($colBg,2)
        $brushThumb = New-Object System.Drawing.SolidBrush($colTextPrimary)
        $e.Graphics.FillEllipse($brushThumb,$thumbX,$thumbY,14,14)
        $e.Graphics.DrawEllipse($pen,$thumbX,$thumbY,14,14)
        $brushThumb.Dispose(); $pen.Dispose()
    })

    $updateFromX = {
        param($ctl,$x)
        $usable = $ctl.Width - 14
        $rel = $x - 7
        if ($rel -lt 0) { $rel = 0 }
        if ($rel -gt $usable) { $rel = $usable }
        $ratio = $rel / $usable
        $val = [int][Math]::Round($ctl.Min + $ratio * ($ctl.Max - $ctl.Min))
        if ($val -ne $ctl.Value) {
            $ctl.Value = $val
            $ctl.Invalidate()
            if ($ctl.OnChange) { & $ctl.OnChange $val }
        }
    }

    $s.Add_MouseDown({
        param($ctl,$e)
        $ctl.Dragging = $true
        $ctl.Capture = $true
        & $updateFromX $ctl $e.X
    }.GetNewClosure())
    $s.Add_MouseMove({
        param($ctl,$e)
        if ($ctl.Dragging) { & $updateFromX $ctl $e.X }
    }.GetNewClosure())
    $s.Add_MouseUp({
        param($ctl,$e)
        $ctl.Dragging = $false
        $ctl.Capture = $false
    })

    return $s
}

# ---------- State ----------
$script:isRunning          = $false
$script:clickCount         = 0
$script:hotkeyVK           = 0x75  # F6
$script:prevHotkeyState    = $false
$script:listeningForHotkey = $false

# ---------- Form ----------
$form = New-Object System.Windows.Forms.Form
$form.Text = "AriseClicker"
$form.Size = New-Object System.Drawing.Size(340,478)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "None"
$form.BackColor = $colBg
$form.ShowInTaskbar = $true
$form.KeyPreview = $true

$form.Add_Load({
    Set-RoundedRegion -Control $form -Radius $CORNER_RADIUS
    try {
        $pref = 2 # DWMWCP_ROUND
        [AutoClicker.Native]::DwmSetWindowAttribute($form.Handle, 33, [ref]$pref, 4) | Out-Null
    } catch {}
})
$form.Add_Paint((New-CardBorderHandler -Radius $CORNER_RADIUS -Color $colCardBorder))

# ---------- Title bar ----------
$titleBar = New-Object System.Windows.Forms.Panel
$titleBar.Size = New-Object System.Drawing.Size($form.Width,38)
$titleBar.Location = New-Object System.Drawing.Point(0,0)
$titleBar.BackColor = $colBg
$titleBar.Anchor = "Top,Left,Right"
$titleBar.Add_Paint({
    param($s,$e)
    $pen = New-Object System.Drawing.Pen($colCardBorder,1)
    $e.Graphics.DrawLine($pen,0,$s.Height-1,$s.Width,$s.Height-1)
    $pen.Dispose()
})

$dotIcon = New-Object System.Windows.Forms.Panel
$dotIcon.Size = New-Object System.Drawing.Size(8,8)
$dotIcon.Location = New-Object System.Drawing.Point(16,15)
$dotIcon.Add_Paint({
    param($s,$e)
    $e.Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $b = New-Object System.Drawing.SolidBrush($colTextPrimary)
    $e.Graphics.FillEllipse($b,0,0,$s.Width,$s.Height)
    $b.Dispose()
})

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "AriseClicker"
$titleLabel.ForeColor = $colTextPrimary
$titleLabel.Font = $fontTitle
$titleLabel.AutoSize = $true
$titleLabel.Location = New-Object System.Drawing.Point(30,9)
$titleLabel.BackColor = [System.Drawing.Color]::Transparent

$TITLEBTN_MARGIN = 20
$btnClose = New-RoundButton -Text ([string][char]0x2715) -Width 26 -Height 26 -FillColor $colBg -HoverColor $colHover -ForeColor $colTextMuted -HoverForeColor $colTextPrimary -Radius 8 -Font $fontIcon -BgBehind $colBg
$btnClose.Location = New-Object System.Drawing.Point(($form.Width-26-$TITLEBTN_MARGIN),6)
$btnClose.Anchor = "Top,Right"

$btnMin = New-RoundButton -Text ([string][char]0x2013) -Width 26 -Height 26 -FillColor $colBg -HoverColor $colHover -ForeColor $colTextMuted -HoverForeColor $colTextPrimary -Radius 8 -Font $fontIcon -BgBehind $colBg
$btnMin.Location = New-Object System.Drawing.Point(($form.Width-26-$TITLEBTN_MARGIN-26-6),6)
$btnMin.Anchor = "Top,Right"

$titleBar.Controls.AddRange(@($dotIcon,$titleLabel,$btnMin,$btnClose))

$dragHandler = {
    if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        [AutoClicker.Native]::ReleaseCapture() | Out-Null
        [AutoClicker.Native]::SendMessage($form.Handle, 0xA1, 2, 0) | Out-Null
    }
}
$titleBar.Add_MouseDown($dragHandler)
$titleLabel.Add_MouseDown($dragHandler)

# ---------- Body ----------
$body = New-Object System.Windows.Forms.Panel
$body.Location = New-Object System.Drawing.Point(0,38)
$body.Size = New-Object System.Drawing.Size($form.Width,($form.Height-38))
$body.BackColor = $colBg

$y = 16

# --- Card: Hotkey ---
$cardHotkey = New-Card -X $CONTENT_X -Y $y -Width $CONTENT_W -Height 64
$cardHotkey.Controls.Add((New-SectionLabel "Hotkey" 14 10))

$lblHotkeyDesc = New-Object System.Windows.Forms.Label
$lblHotkeyDesc.Text = "Avvia/ferma da qualunque finestra"
$lblHotkeyDesc.Font = $fontMicro
$lblHotkeyDesc.ForeColor = $colTextFaint
$lblHotkeyDesc.AutoSize = $true
$lblHotkeyDesc.BackColor = [System.Drawing.Color]::Transparent
$lblHotkeyDesc.Location = New-Object System.Drawing.Point(14,34)

$btnHotkey = New-RoundButton -Text "F6" -Width 84 -Height 30 -FillColor $colInputBg -HoverColor $colHover -ForeColor $colTextPrimary -Radius 8 -Font $fontSmall -BgBehind $colCard
$btnHotkey.Location = New-Object System.Drawing.Point(($CONTENT_W-84-14),17)

$cardHotkey.Controls.AddRange(@($lblHotkeyDesc,$btnHotkey))
$y += 64 + 10

# --- Card: Click ---
$cardClick = New-Card -X $CONTENT_X -Y $y -Width $CONTENT_W -Height 68
$cardClick.Controls.Add((New-SectionLabel "Click" 14 10))
$tpButton = New-TogglePair -TextA "Sinistro" -TextB "Destro" -X 14 -Y 30 -Width ($CONTENT_W-28) -Height 28
$cardClick.Controls.Add($tpButton.Panel)
$y += 68 + 10

# --- Card: Velocita ---
$cardSpeed = New-Card -X $CONTENT_X -Y $y -Width $CONTENT_W -Height 128
$cardSpeed.Controls.Add((New-SectionLabel "Velocita" 14 10))

$lblCpsBig = New-Object System.Windows.Forms.Label
$lblCpsBig.Text = "10"
$lblCpsBig.Font = $fontStatBig
$lblCpsBig.ForeColor = $colTextPrimary
$lblCpsBig.AutoSize = $true
$lblCpsBig.BackColor = [System.Drawing.Color]::Transparent
$lblCpsBig.Location = New-Object System.Drawing.Point(14,24)

$lblCpsUnit = New-Object System.Windows.Forms.Label
$lblCpsUnit.Text = "CLICK AL SECONDO"
$lblCpsUnit.Font = $fontStatLbl
$lblCpsUnit.ForeColor = $colTextFaint
$lblCpsUnit.AutoSize = $true
$lblCpsUnit.BackColor = [System.Drawing.Color]::Transparent
$lblCpsUnit.Location = New-Object System.Drawing.Point(16,78)

$sldSpeed = New-Slider -X 14 -Y 96 -Width ($CONTENT_W-28) -Height 24 -Min 1 -Max 100 -Value 10

$cardSpeed.Controls.AddRange(@($lblCpsBig,$lblCpsUnit,$sldSpeed))
$y += 128 + 14

# --- Start/Stop ---
$btnStart = New-RoundButton -Text "AVVIA" -Width $CONTENT_W -Height 46 -FillColor $colTextPrimary -HoverColor $colTextPrimary -ForeColor $colBg -Radius 12 -Font (New-Object System.Drawing.Font("Segoe UI",10.5,[System.Drawing.FontStyle]::Bold)) -BgBehind $colBg
$btnStart.Location = New-Object System.Drawing.Point($CONTENT_X,$y)
$y += 46 + 14

# --- Footer ---
$sepFooter = New-Object System.Windows.Forms.Panel
$sepFooter.Size = New-Object System.Drawing.Size($CONTENT_W,1)
$sepFooter.Location = New-Object System.Drawing.Point($CONTENT_X,$y)
$sepFooter.BackColor = $colCardBorder
$y += 10

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = "Pronto - click totali: 0"
$lblStatus.Font = $fontLabel
$lblStatus.ForeColor = $colTextMuted
$lblStatus.AutoSize = $true
$lblStatus.BackColor = [System.Drawing.Color]::Transparent
$lblStatus.Location = New-Object System.Drawing.Point($CONTENT_X,$y)

$lblCredit = New-Object System.Windows.Forms.Label
$lblCredit.Text = "Made by Melnyyy"
$lblCredit.Font = $fontCredit
$lblCredit.ForeColor = $colTextFaint
$lblCredit.AutoSize = $true
$lblCredit.BackColor = [System.Drawing.Color]::Transparent
$creditWidth = $lblCredit.PreferredSize.Width
$lblCredit.Location = New-Object System.Drawing.Point(($CONTENT_X+$CONTENT_W-$creditWidth),($y+2))

$body.Controls.AddRange(@($cardHotkey,$cardClick,$cardSpeed,$btnStart,$sepFooter,$lblStatus,$lblCredit))
$form.Controls.AddRange(@($titleBar,$body))

# ---------- Timers ----------
$timerClick = New-Object System.Windows.Forms.Timer
$timerHotkey = New-Object System.Windows.Forms.Timer
$timerHotkey.Interval = 50

function Get-IntervalMs {
    $cps = $sldSpeed.Value
    if ($cps -lt 1) { $cps = 1 }
    $ms = [int][Math]::Round(1000.0 / $cps)
    if ($ms -lt 10) { $ms = 10 }
    return $ms
}

function Start-Clicking {
    $script:clickCount = 0
    $script:isRunning = $true
    $btnStart.BtnText = "FERMA"
    Set-ButtonStyle -Btn $btnStart -FillColor $colInputBg -TextColor $colTextPrimary -HoverColor $colHover -HoverTextColor $colTextPrimary
    $lblStatus.Text = "In esecuzione..."
    $timerClick.Interval = Get-IntervalMs
    $timerClick.Start()
}

function Stop-Clicking {
    $script:isRunning = $false
    $timerClick.Stop()
    $btnStart.BtnText = "AVVIA"
    Set-ButtonStyle -Btn $btnStart -FillColor $colTextPrimary -TextColor $colBg -HoverColor $colTextPrimary -HoverTextColor $colBg
    $lblStatus.Text = "Fermo - click totali: $script:clickCount"
}

$btnStart.Add_Click({
    if ($script:isRunning) { Stop-Clicking } else { Start-Clicking }
})

$sldSpeed.OnChange = {
    param($v)
    $lblCpsBig.Text = "$v"
    if ($script:isRunning) { $timerClick.Interval = Get-IntervalMs }
}.GetNewClosure()

$timerClick.Add_Tick({
    $right = ($tpButton.Selected -eq 1)
    [AutoClicker.MouseSim]::Click($right)
    $script:clickCount++
    $lblStatus.Text = "In esecuzione - click: $script:clickCount"
})

function Get-KeyDisplayName {
    param($vk)
    try {
        $k = [System.Windows.Forms.Keys]$vk
        return $k.ToString().ToUpper()
    } catch { return "F6" }
}

$timerHotkey.Add_Tick({
    if ($script:listeningForHotkey) { return }
    $state = [AutoClicker.Native]::GetAsyncKeyState($script:hotkeyVK)
    $pressed = ([int]$state -band 0x8000) -ne 0
    if ($pressed -and -not $script:prevHotkeyState) {
        if ($script:isRunning) { Stop-Clicking } else { Start-Clicking }
    }
    $script:prevHotkeyState = $pressed
})
$timerHotkey.Start()

$btnHotkey.Add_Click({
    $script:listeningForHotkey = $true
    $btnHotkey.BtnText = "..."
    $btnHotkey.Invalidate()
})

$form.Add_KeyDown({
    param($s,$e)
    if ($script:listeningForHotkey) {
        $script:hotkeyVK = [int]$e.KeyCode
        $script:listeningForHotkey = $false
        $script:prevHotkeyState = $false
        $btnHotkey.BtnText = Get-KeyDisplayName $script:hotkeyVK
        $btnHotkey.Invalidate()
        $e.Handled = $true
        $e.SuppressKeyPress = $true
    }
})

$btnClose.Add_Click({
    $timerClick.Stop(); $timerHotkey.Stop()
    $form.Close()
})
$btnMin.Add_Click({ $form.WindowState = "Minimized" })

$form.Add_FormClosing({
    $timerClick.Stop(); $timerHotkey.Stop()
})

[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::Run($form)
