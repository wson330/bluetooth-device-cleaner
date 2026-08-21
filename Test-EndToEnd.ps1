<#
.SYNOPSIS
    Remove-BluetoothDevice.ps1 엔드투엔드 테스트.

.DESCRIPTION
    가짜 MAC으로 레지스트리 항목을 만든 뒤 툴로 삭제하고, 실제 기기는 하나도
    건드리지 않았는지 확인한다. 실기기는 절대 건드리지 않는다.

    커버하는 것:
      1. Keys 하위키 형태 (LE 기기)
      2. Keys 값(value) 형태 (클래식 BT 기기)
      3. 대화형 번호 선택 경로 (stdin 리다이렉트)

    자가 권한 상승(-Verb RunAs) 경로는 UAC 클릭이 필요해 여기서 자동화하지 않는다.
    Test-SelfElevation.ps1 을 일반 권한 창에서 실행해 확인한다.

.EXAMPLE
    .\Test-EndToEnd.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
$tool    = Join-Path $PSScriptRoot 'Remove-BluetoothDevice.ps1'
$DevRoot = 'HKLM:\SYSTEM\CurrentControlSet\Services\BTHPORT\Parameters\Devices'
$KeyRoot = 'HKLM:\SYSTEM\CurrentControlSet\Services\BTHPORT\Parameters\Keys'

$SUBKEY = 'aabbccddeeff'   # LE 형태: Keys\<어댑터>\<MAC> 하위키
$VALUE  = 'aabbccddeef0'   # 클래식 형태: Keys\<어댑터> 아래 값 이름이 MAC
$INTER  = 'aabbccddeef1'   # 대화형 선택 테스트용

if (-not (Test-Path $tool)) { throw "툴을 찾을 수 없다: $tool" }

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
         ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    Write-Host "관리자 권한이 필요하다. 새 창을 띄운다 (UAC에서 '예')." -ForegroundColor Yellow
    Start-Process powershell.exe -Verb RunAs -ArgumentList `
        ('-NoExit -NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $PSCommandPath)
    return
}

$tmp  = Join-Path $env:TEMP "bttest-$PID"
$null = New-Item -ItemType Directory -Path $tmp -Force
$fail = 0

# 임의의 스크립트를 SYSTEM 계정 임시 예약 작업으로 실행한다.
function Run-AsSystem([string]$Body, [string]$OutFile) {
    $s    = "$tmp\child.ps1"
    $name = "BtTest-$PID"
    Set-Content -Path $s -Value $Body -Encoding UTF8
    $act  = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $s)
    $prin = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $set  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    Register-ScheduledTask -TaskName $name -Action $act -Principal $prin -Settings $set -Force | Out-Null
    try {
        Remove-Item $OutFile -Force -ErrorAction SilentlyContinue
        Start-ScheduledTask -TaskName $name
        $n = 0
        while ($n -lt 120 -and -not (Test-Path $OutFile)) { Start-Sleep -Milliseconds 500; $n++ }
    } finally { Unregister-ScheduledTask -TaskName $name -Confirm:$false -ErrorAction SilentlyContinue }
    if (Test-Path $OutFile) { Get-Content $OutFile } else { 'NO OUTPUT' }
}

function Check($label, $ok) {
    if ($ok) { Write-Host "  PASS  $label" -ForegroundColor Green }
    else     { Write-Host "  FAIL  $label" -ForegroundColor Red; $script:fail++ }
}

# Keys 하위에 남아 있는 이름(하위키 + 값)을 모두 모아 온다. SYSTEM 필요.
function Get-KeysEntries {
    $o = "$tmp\keys.out"
    Run-AsSystem @"
`$out = @()
foreach (`$a in (Get-ChildItem '$KeyRoot' -ErrorAction SilentlyContinue)) {
    `$out += (Get-ChildItem `$a.PSPath -ErrorAction SilentlyContinue | Select-Object -Expand PSChildName)
    `$out += (Get-Item `$a.PSPath).GetValueNames()
}
`$out | Set-Content '$o' -Encoding UTF8
"@ $o
}

function Add-Fake([string]$Mac, [string]$Name, [string]$Form) {
    $o = "$tmp\seed.out"
    # 중첩 이스케이프는 조용히 깨진다. 단일 인용 here-string(보간 없음) + 토큰 치환을 쓴다.
    $tpl = @'
$d = 'DEVROOT\MACADDR'
New-Item -Path $d -Force | Out-Null
Set-ItemProperty -Path $d -Name 'Name' -Value ([byte[]][Text.Encoding]::UTF8.GetBytes("DEVNAME" + [char]0)) -Type Binary
foreach ($a in (Get-ChildItem 'KEYROOT')) {
KEYLINE
}
'seeded' | Set-Content 'OUTFILE' -Encoding UTF8
'@
    $keyLine = if ($Form -eq 'subkey') {
@'
    New-Item -Path "$($a.PSPath)\MACADDR" -Force | Out-Null
    Set-ItemProperty -Path "$($a.PSPath)\MACADDR" -Name 'LTK' -Value ([byte[]](1..16)) -Type Binary
'@
    } else {
@'
    Set-ItemProperty -Path $a.PSPath -Name 'MACADDR' -Value ([byte[]](1..16)) -Type Binary
'@
    }
    $body = $tpl.Replace('KEYLINE', $keyLine).
                 Replace('MACADDR', $Mac).
                 Replace('DEVROOT', $DevRoot).
                 Replace('DEVNAME', $Name).
                 Replace('KEYROOT', $KeyRoot).
                 Replace('OUTFILE', $o)
    Run-AsSystem $body $o | Out-Null
}

$before = @(& $tool -List | Select-Object -ExpandProperty MAC)
Write-Host "테스트 전 실기기 $($before.Count)개" -ForegroundColor Cyan
if (-not $before) { throw "기기 목록을 읽지 못했다. 테스트 중단." }

# --- 1) Keys 두 형태 모두 삭제되는가 ---------------------------------------
Write-Host "`n[1] 가짜 기기 2종 심기 (하위키 형태 + 값 형태)" -ForegroundColor Cyan
Add-Fake $SUBKEY 'ZZ TEST SUBKEY' 'subkey'
Add-Fake $VALUE  'ZZ TEST VALUE'  'value'
$seeded = Get-KeysEntries
Check "Devices 키 2개 생성됨"  ((Test-Path "$DevRoot\$SUBKEY") -and (Test-Path "$DevRoot\$VALUE"))
Check "Keys 하위키 형태 심어짐" ($seeded -contains $SUBKEY)
Check "Keys 값 형태 심어짐"     ($seeded -contains $VALUE)

Write-Host "`n[2] 툴이 둘 다 인식" -ForegroundColor Cyan
$listed = @(& $tool -List | Select-Object -ExpandProperty MAC)
Check "목록에 2개 다 나타남" (($listed -contains $SUBKEY) -and ($listed -contains $VALUE))

Write-Host "`n[3] 툴로 삭제 (-Mac, 2개 동시)" -ForegroundColor Cyan
& $tool -Mac $SUBKEY, $VALUE -Force | Out-Null
$left = Get-KeysEntries
Check "Devices 키 2개 삭제됨"    ((-not (Test-Path "$DevRoot\$SUBKEY")) -and (-not (Test-Path "$DevRoot\$VALUE")))
Check "Keys 하위키 형태 삭제됨"  ($left -notcontains $SUBKEY)
Check "Keys 값 형태 삭제됨"      ($left -notcontains $VALUE)

# --- 2) 대화형 번호 선택 경로 ----------------------------------------------
Write-Host "`n[4] 대화형 번호 선택 경로" -ForegroundColor Cyan
Add-Fake $INTER 'ZZ TEST INTERACTIVE' 'subkey'

# 툴은 Sort-Object Name 순서로 번호를 매기고 -List 도 같은 순서다.
$sorted = @(& $tool -List | Select-Object -ExpandProperty MAC)
$idx    = [array]::IndexOf($sorted, $INTER) + 1
Write-Host "  선택할 번호: $idx / $($sorted.Count)"

# Read-Host 는 콘솔에서 읽으므로 별도 프로세스에 stdin 을 리다이렉트해야 한다.
# 입력 두 줄: 번호, 그리고 확인 프롬프트의 y
$in = "$tmp\stdin.txt"
Set-Content -Path $in -Value @("$idx", 'y') -Encoding ASCII
Start-Process powershell.exe -Wait -NoNewWindow `
    -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$tool`"" `
    -RedirectStandardInput $in `
    -RedirectStandardOutput "$tmp\i.out" -RedirectStandardError "$tmp\i.err"

$iout = if (Test-Path "$tmp\i.out") { Get-Content "$tmp\i.out" -Raw } else { '' }
Check "대화형으로 Devices 키 삭제됨" (-not (Test-Path "$DevRoot\$INTER"))
Check "대화형으로 Keys 항목 삭제됨"   ((Get-KeysEntries) -notcontains $INTER)
if ($fail) { Write-Host "  --- 대화형 실행 출력 ---`n$iout" -ForegroundColor DarkGray }

# --- 3) 실기기 무결성 ------------------------------------------------------
Write-Host "`n[5] 실기기 무결성" -ForegroundColor Cyan
$after = @(& $tool -List | Select-Object -ExpandProperty MAC)
Check "실기기 $($before.Count)개 그대로 ($($after.Count)개 남음)" `
      (-not (Compare-Object -ReferenceObject $before -DifferenceObject $after))

Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
if ($fail) { Write-Host "$fail 개 실패" -ForegroundColor Red; exit 1 }
else       { Write-Host "전체 통과" -ForegroundColor Green }
