<#
.SYNOPSIS
    Remove-BluetoothDevice.ps1 의 자가 권한 상승 경로 테스트.

.DESCRIPTION
    반드시 **일반(비관리자) PowerShell 창**에서 실행해야 한다. 관리자 창에서 돌리면
    검증하려는 분기 자체를 타지 않는다.

    가짜 기기를 심고(UAC 1회), 비관리자 상태로 툴을 호출해 툴이 스스로 UAC를
    띄우는지(UAC 2회), 그리고 승격된 인스턴스가 실제로 삭제를 수행하는지 확인한다.
    실기기는 건드리지 않는다.

.EXAMPLE
    .\Test-SelfElevation.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
$tool    = Join-Path $PSScriptRoot 'Remove-BluetoothDevice.ps1'
$DevRoot = 'HKLM:\SYSTEM\CurrentControlSet\Services\BTHPORT\Parameters\Devices'
$KeyRoot = 'HKLM:\SYSTEM\CurrentControlSet\Services\BTHPORT\Parameters\Keys'
$FAKE    = 'aabbccddeef2'
$fail    = 0

function Check($label, $ok) {
    if ($ok) { Write-Host "  PASS  $label" -ForegroundColor Green }
    else     { Write-Host "  FAIL  $label" -ForegroundColor Red; $script:fail++ }
}

if (-not (Test-Path $tool)) { throw "툴을 찾을 수 없다: $tool" }

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
         ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($admin) {
    Write-Host "이 창은 관리자 권한이다. 자가 승격 분기를 탈 수 없다." -ForegroundColor Red
    Write-Host "일반 PowerShell 창에서 다시 실행해라." -ForegroundColor Yellow
    exit 1
}

$tmp  = Join-Path $env:TEMP "btselftest-$PID"
$null = New-Item -ItemType Directory -Path $tmp -Force

# --- 1) 가짜 기기 심기 (여기만 관리자 권한이 필요하다) ----------------------
Write-Host "[1] 가짜 기기 심기 - UAC 창이 뜨면 '예'" -ForegroundColor Cyan
$seeder = "$tmp\seed.ps1"
@"
`$tmp  = '$tmp'
`$name = 'BtSelfTestSeed'
`$s    = "`$tmp\seedchild.ps1"
@'
`$d = '$DevRoot\$FAKE'
New-Item -Path `$d -Force | Out-Null
Set-ItemProperty -Path `$d -Name 'Name' -Value ([byte[]][Text.Encoding]::UTF8.GetBytes("ZZ TEST SELFELEV`0")) -Type Binary
foreach (`$a in (Get-ChildItem '$KeyRoot')) {
    New-Item -Path "`$(`$a.PSPath)\$FAKE" -Force | Out-Null
    Set-ItemProperty -Path "`$(`$a.PSPath)\$FAKE" -Name 'LTK' -Value ([byte[]](1..16)) -Type Binary
}
'ok' | Set-Content '$tmp\seed.out' -Encoding UTF8
'@ | Set-Content -Path `$s -Encoding UTF8
`$act  = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f `$s)
`$prin = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
`$set  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
Register-ScheduledTask -TaskName `$name -Action `$act -Principal `$prin -Settings `$set -Force | Out-Null
Start-ScheduledTask -TaskName `$name
`$n = 0
while (`$n -lt 120 -and -not (Test-Path '$tmp\seed.out')) { Start-Sleep -Milliseconds 500; `$n++ }
Unregister-ScheduledTask -TaskName `$name -Confirm:`$false -ErrorAction SilentlyContinue
"@ | Set-Content -Path $seeder -Encoding UTF8

Start-Process powershell.exe -Verb RunAs -Wait -ArgumentList `
    '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$seeder`""
Check "가짜 기기 심어짐" (Test-Path "$DevRoot\$FAKE")
if ($fail) { Write-Host "심기 실패. 중단." -ForegroundColor Red; exit 1 }

# --- 2) 비관리자 상태에서 툴 호출 -------------------------------------------
Write-Host "`n[2] 비관리자 상태로 툴 호출 - 툴이 스스로 UAC를 띄워야 한다" -ForegroundColor Cyan
Write-Host "    UAC 창이 뜨면 '예'. 새 창이 열리고 삭제가 진행된다." -ForegroundColor Yellow
# 안내는 Write-Host 라 정보 스트림(6)으로 나간다. 2>&1 로는 안 잡힌다.
$out = & $tool -Mac $FAKE -Force 6>&1 | Out-String
Check "자가 승격 분기를 탔음 (안내 메시지 출력)" ($out -match '관리자 권한이 필요')

# --- 3) 승격된 인스턴스가 실제로 삭제했는가 ---------------------------------
Write-Host "`n[3] 승격된 인스턴스의 삭제 결과 대기 (최대 90초)" -ForegroundColor Cyan
$n = 0
while ($n -lt 180 -and (Test-Path "$DevRoot\$FAKE")) { Start-Sleep -Milliseconds 500; $n++ }
Check "Devices 키 삭제됨 ($([math]::Round($n*0.5,1))초 소요)" (-not (Test-Path "$DevRoot\$FAKE"))

Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
if ($fail) { Write-Host "$fail 개 실패" -ForegroundColor Red; exit 1 }
else {
    Write-Host "전체 통과" -ForegroundColor Green
    Write-Host "툴이 띄운 창은 -NoExit 이라 열려 있다. 확인 후 닫아라." -ForegroundColor DarkGray
}
