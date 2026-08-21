<#
.SYNOPSIS
    Windows 설정 앱에서 지워지지 않는 블루투스 기기를 레지스트리에서 강제 제거한다.

.DESCRIPTION
    BTHPORT 레지스트리의 Devices 키와 Keys(페어링 키)를 SYSTEM 권한으로 삭제한다.
    SYSTEM 권한은 임시 예약 작업으로 얻으므로 PsExec 등 외부 도구가 필요 없다.

    중요: 삭제 후 블루투스 스택을 건드리면 안 된다. BTHPORT 드라이버는 페어링 목록을
    메모리에 들고 있다가 스택이 깨어날 때 레지스트리로 도로 덮어쓴다. 그래서 이 스크립트는
    bthserv 재시작도, pnputil /remove-device 도 하지 않는다. 재부팅이 삭제를 확정한다.

.EXAMPLE
    .\Remove-BluetoothDevice.ps1 -List
    페어링된 기기 목록만 출력한다.

.EXAMPLE
    .\Remove-BluetoothDevice.ps1
    목록에서 번호로 골라 삭제한다.

.EXAMPLE
    .\Remove-BluetoothDevice.ps1 -Mac cad0ebc66e06,df8d4e491cc7
    지정한 MAC을 확인 없이 삭제한다.
#>
[CmdletBinding()]
param(
    [string[]]$Mac,
    [switch]$List,
    [switch]$Force,
    # 내부용: 이 값이 있으면 우리는 SYSTEM으로 실행 중이며 삭제만 수행한다.
    [string]$SystemPurge
)

$ErrorActionPreference = 'Stop'
$DevRoot = 'HKLM:\SYSTEM\CurrentControlSet\Services\BTHPORT\Parameters\Devices'
$KeyRoot = 'HKLM:\SYSTEM\CurrentControlSet\Services\BTHPORT\Parameters\Keys'


function Get-BtDevice {
    if (-not (Test-Path $DevRoot)) { return @() }
    $nodes = @{}
    foreach ($d in (Get-PnpDevice -ErrorAction SilentlyContinue |
                    Where-Object { $_.InstanceId -match 'DEV_?([0-9A-Fa-f]{12})' })) {
        $null = $d.InstanceId -match 'DEV_?([0-9A-Fa-f]{12})'
        $k = $Matches[1].ToLower()
        $nodes[$k] = [int]$nodes[$k] + 1
    }
    foreach ($k in (Get-ChildItem $DevRoot)) {
        $p  = Get-ItemProperty $k.PSPath -ErrorAction SilentlyContinue
        $nm = if ($p.Name) { [Text.Encoding]::UTF8.GetString($p.Name).TrimEnd([char]0) } else { '' }
        [PSCustomObject]@{
            MAC           = $k.PSChildName
            Name          = if ($nm) { $nm } else { '(이름 없음 - 유령 항목)' }
            PnpNodes      = [int]$nodes[$k.PSChildName]
            LastConnected = if ($p.LastConnected) { [DateTime]::FromFileTime([int64]$p.LastConnected) } else { $null }
        }
    }
}

# 대상 MAC들을 Devices 와 Keys 양쪽에서 지운다. SYSTEM 권한이 필요하다.
function Invoke-Purge([string[]]$Targets) {
    foreach ($m in $Targets) {
        "=== $m ==="
        if (Test-Path "$DevRoot\$m") {
            Remove-Item "$DevRoot\$m" -Recurse -Force
            if (Test-Path "$DevRoot\$m") { "  Devices: 삭제 실패" } else { "  Devices: 삭제됨" }
        } else { "  Devices: 없음" }

        foreach ($a in (Get-ChildItem $KeyRoot -ErrorAction SilentlyContinue)) {
            # 페어링 키는 어댑터 아래 하위 키(LE)로도, 값(클래식 BT)으로도 존재한다. 둘 다 처리.
            if (Test-Path "$($a.PSPath)\$m") {
                Remove-Item "$($a.PSPath)\$m" -Recurse -Force
                "  Keys 하위키 삭제됨 (어댑터 $($a.PSChildName))"
            }
            $hit = (Get-Item $a.PSPath).GetValueNames() | Where-Object { $_ -ieq $m }
            if ($hit) {
                Remove-ItemProperty $a.PSPath -Name $hit -Force
                "  Keys 값 삭제됨 (어댑터 $($a.PSChildName))"
            }
        }
    }
}

# 자기 자신을 SYSTEM 계정의 임시 예약 작업으로 재실행한다.
function Invoke-AsSystem([string[]]$Targets) {
    $tmp  = Join-Path $env:TEMP "btpurge-$PID"
    $null = New-Item -ItemType Directory -Path $tmp -Force
    $Targets | Set-Content "$tmp\macs.txt" -Encoding ASCII

    $name = "BtPurge-$PID"
    $arg  = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -SystemPurge "{1}"' -f $PSCommandPath, $tmp
    $task = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arg
    $prin = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    # 예약 작업 기본 설정은 "AC 전원일 때만 실행"이다. 노트북이 배터리면 Queued 에서 멈춘다.
    $set  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
                -ExecutionTimeLimit (New-TimeSpan -Minutes 5) -StartWhenAvailable
    Register-ScheduledTask -TaskName $name -Action $task -Principal $prin -Settings $set -Force | Out-Null
    try {
        Start-ScheduledTask -TaskName $name
        # State 는 Ready -> Queued -> Running 순으로 바뀌어 레이스가 난다.
        # 실제 완료 신호인 출력 파일을 기다린다.
        $n = 0
        while ($n -lt 120 -and -not (Test-Path "$tmp\out.log")) { Start-Sleep -Milliseconds 500; $n++ }
    } finally {
        Unregister-ScheduledTask -TaskName $name -Confirm:$false -ErrorAction SilentlyContinue
    }

    if (Test-Path "$tmp\out.log") { Get-Content "$tmp\out.log" }
    else { throw "SYSTEM 작업이 60초 안에 출력을 남기지 않았다. 예약 작업이 정책으로 차단됐을 수 있다." }
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}


# --- SYSTEM 모드: 삭제만 하고 끝낸다 ---------------------------------------
if ($SystemPurge) {
    $out = @("whoami: $(whoami)")
    try {
        $targets = Get-Content "$SystemPurge\macs.txt" | Where-Object { $_ -match '^[0-9a-fA-F]{12}$' }
        $out += Invoke-Purge $targets
    } catch {
        $out += "오류: $($_.Exception.Message)"
    }
    $out | Set-Content "$SystemPurge\out.log" -Encoding UTF8
    exit
}

# --- 일반 모드 --------------------------------------------------------------
$devices = @(Get-BtDevice | Sort-Object Name)

if ($List) {
    # Format-Table 을 쓰면 파이프로 걸러 쓸 수 없는 포맷 객체가 나온다. 객체를 그대로 내보낸다.
    $devices | Select-Object MAC, Name, PnpNodes, LastConnected
    return
}

if (-not $devices) { Write-Host "페어링된 블루투스 기기가 없다."; return }

# 삭제할 대상 정하기
if ($Mac) {
    $targets = @($Mac | ForEach-Object { $_.ToLower() -replace '[^0-9a-f]', '' })
    $unknown = $targets | Where-Object { $devices.MAC -notcontains $_ }
    if ($unknown) { throw "레지스트리에 없는 MAC: $($unknown -join ', ')" }
} else {
    Write-Host ""
    for ($i = 0; $i -lt $devices.Count; $i++) {
        $d = $devices[$i]
        $when = if ($d.LastConnected) { $d.LastConnected.ToString('yyyy-MM-dd') } else { '기록없음' }
        "{0,3}) {1}  {2,-30} 노드:{3}  최종연결:{4}" -f ($i + 1), $d.MAC, $d.Name, $d.PnpNodes, $when
    }
    Write-Host ""
    $pick = Read-Host "삭제할 번호 (쉼표로 여러 개, 예: 1,3,7)"
    $idx  = $pick -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ - 1 }
    $idx  = @($idx | Where-Object { $_ -ge 0 -and $_ -lt $devices.Count } | Sort-Object -Unique)
    if (-not $idx) { Write-Host "선택 없음. 종료."; return }
    $targets = @($devices[$idx].MAC)
}

Write-Host ""
Write-Host "삭제 대상:" -ForegroundColor Yellow
foreach ($m in $targets) { "  $m  $(($devices | Where-Object MAC -eq $m).Name)" }
Write-Host ""

if (-not $Force) {
    if ((Read-Host "진행할까? (y/N)") -notmatch '^[yY]') { Write-Host "취소."; return }
}

# 여기서부터 관리자 권한이 필요하다.
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
         ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    Write-Host "관리자 권한이 필요하다. 새 창을 띄운다 (UAC에서 '예')." -ForegroundColor Yellow
    $a = '-NoExit -NoProfile -ExecutionPolicy Bypass -File "{0}" -Force -Mac {1}' -f $PSCommandPath, ($targets -join ',')
    Start-Process powershell.exe -Verb RunAs -ArgumentList $a
    return
}

Write-Host ""
Invoke-AsSystem $targets

Write-Host ""
Write-Host "--- 남은 기기 ---" -ForegroundColor Cyan
Get-BtDevice | Sort-Object Name | Format-Table -AutoSize MAC, Name

$left = @(Get-BtDevice | Where-Object { $targets -contains $_.MAC })
if ($left) {
    Write-Host "경고: 아직 남아있다 -> $($left.MAC -join ', ')" -ForegroundColor Red
} else {
    Write-Host "삭제 완료. 지금 재부팅해라." -ForegroundColor Green
    Write-Host "재부팅 전까지는 블루투스 설정을 열거나 기기를 켜지 마라 - 스택이 깨어나면 되살아난다." -ForegroundColor Yellow
}
