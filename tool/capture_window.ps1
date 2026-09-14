# Снимок окна приложения для README и сайта.
#
# Снимает именно окно, а не весь экран: в кадр не попадают ни рабочий стол,
# ни чужие окна, ни панель задач. Размер задаётся заранее, чтобы снимки
# разных экранов совпадали по кадру и не приходилось их подрезать.
#
#   powershell -File tool/capture_window.ps1 -Out site/assets/screenshots/library.jpg
#
# `-ClickX`/`-ClickY` нажимают внутри окна перед снимком (координаты от его
# левого верхнего угла, то есть те же, что видны на предыдущем снимке) —
# так переход в раздел и кадр делает один запуск, и между ними некому
# выйти вперёд.
param(
  [Parameter(Mandatory = $true)][string]$Out,
  [string]$Process = 'evaporate',
  [int]$Width = 1600,
  [int]$Height = 1000,
  [int]$SettleMs = 900,
  [int]$ClickX = -1,
  [int]$ClickY = -1
)

Add-Type -AssemblyName System.Drawing

Add-Type @'
using System;
using System.Runtime.InteropServices;
public class Win {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int t, bool repaint);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void keybd_event(byte key, byte scan, uint flags, IntPtr extra);
  [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint x, uint y, uint data, IntPtr extra);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
}
'@

$app = Get-Process -Name $Process -ErrorAction SilentlyContinue |
  Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $app) { throw "Окно процесса '$Process' не найдено — приложение запущено?" }
$handle = $app.MainWindowHandle

# Windows не отдаёт передний план процессу, который его не держит, и
# `SetForegroundWindow` в этом случае возвращает ложь молча. Нажатие Alt
# снимает запрет: система считает его началом работы с окнами.
function Front {
  for ($i = 0; $i -lt 10; $i++) {
    [Win]::keybd_event(0x12, 0, 0, [IntPtr]::Zero)
    [Win]::keybd_event(0x12, 0, 2, [IntPtr]::Zero)
    [void][Win]::ShowWindow($handle, 9)
    [void][Win]::SetForegroundWindow($handle)
    Start-Sleep -Milliseconds 250
    if ([Win]::GetForegroundWindow() -eq $handle) { return }
  }
  # Молчаливый отказ здесь означал бы снимок чужого окна: `CopyFromScreen`
  # берёт то, что лежит сверху, и подмену видно только глазом.
  throw "Окно '$Process' не удалось вывести вперёд — снимок был бы чужой."
}

[void][Win]::MoveWindow($handle, 80, 60, $Width, $Height, $true)
Front

$rect = New-Object Win+RECT
[void][Win]::GetWindowRect($handle, [ref]$rect)

if ($ClickX -ge 0 -and $ClickY -ge 0) {
  [void][Win]::SetCursorPos($rect.L + $ClickX, $rect.T + $ClickY)
  Start-Sleep -Milliseconds 200
  [Win]::mouse_event(0x0002, 0, 0, 0, [IntPtr]::Zero)
  [Win]::mouse_event(0x0004, 0, 0, 0, [IntPtr]::Zero)
  Start-Sleep -Milliseconds 1200
  # Указатель уводится из кадра: наведённая клавиша светилась бы на снимке
  # без причины, видимой читателю.
  [void][Win]::SetCursorPos($rect.L + $Width - 4, $rect.T + $Height - 4)
}

Start-Sleep -Milliseconds $SettleMs
if ([Win]::GetForegroundWindow() -ne $handle) { Front }

$w = $rect.R - $rect.L
$h = $rect.B - $rect.T

# Снимаем с экрана, а не через PrintWindow: окно рисует Flutter на своей
# поверхности, и PrintWindow отдаёт по ней пустоту.
$bitmap = New-Object System.Drawing.Bitmap $w, $h
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.CopyFromScreen($rect.L, $rect.T, 0, 0, $bitmap.Size)
$graphics.Dispose()

# Разрешаем и относительный путь, и абсолютный: `Join-Path` со вторым
# абсолютным склеивал из них бессмыслицу — корень репозитория, а следом
# целиком приклеенный второй абсолютный путь.
$full = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Out)
$dir = [System.IO.Path]::GetDirectoryName($full)
if (-not (Test-Path $dir)) { [void](New-Item -ItemType Directory -Path $dir -Force) }
# JPEG для снимков экрана, а не PNG: у кадра с обложками игр PNG выходит
# впятеро тяжелее, а страницу с ним открывают через сеть. Качество 90
# оставляет подписи интерфейса резкими — проверено на самом мелком тексте.
if ([System.IO.Path]::GetExtension($full) -match '^\.jpe?g$') {
  $jpeg = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
    Where-Object { $_.MimeType -eq 'image/jpeg' }
  $quality = New-Object System.Drawing.Imaging.EncoderParameters 1
  $quality.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter(
    [System.Drawing.Imaging.Encoder]::Quality, 90)
  $bitmap.Save($full, $jpeg, $quality)
} else {
  $bitmap.Save($full, [System.Drawing.Imaging.ImageFormat]::Png)
}
$bitmap.Dispose()
Write-Output "снято: $Out ($w x $h)"
