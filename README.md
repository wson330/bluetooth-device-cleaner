# Bluetooth Device Cleaner

Windows 11 설정 앱에서 **"디바이스 제거"가 안 먹히는 블루투스 기기**를 레지스트리에서 강제로 지운다.

의존성 없음. PowerShell 5.1 기본 내장 기능만 사용한다. PsExec 같은 외부 도구를 받을 필요가 없고, **Home 에디션에서도 동작한다.**

```powershell
Get-ChildItem *.ps1 | Unblock-File                       # 내려받은 파일 차단 해제 (최초 1회)
powershell -ExecutionPolicy Bypass -File .\Remove-BluetoothDevice.ps1 -List   # 페어링된 기기 목록
powershell -ExecutionPolicy Bypass -File .\Remove-BluetoothDevice.ps1         # 번호로 골라서 삭제
powershell -ExecutionPolicy Bypass -File .\Remove-BluetoothDevice.ps1 -Mac cad0ebc66e06 -Force
```

관리자 권한이 없으면 알아서 UAC를 띄운다. **삭제 후 재부팅해야 확정된다.**

처음이라면 → [사용법 — 처음부터 따라하기](#사용법--처음부터-따라하기)

---

## 사용법 — 처음부터 따라하기

컴퓨터를 잘 모르는 사람도 그대로 따라 할 수 있게 적었다. 맨 위 요약만으로 충분하면 이 절은 건너뛰어도 된다.

### 시작하기 전에 확인할 것

| 조건 | 설명 |
|---|---|
| **Windows 10 또는 11** | 검증은 Windows 11 Home 26100에서 했다. |
| **관리자 계정** | 본인 PC의 주 계정이면 대개 관리자다. 회사 지급 PC는 막혀 있을 수 있다. |
| **재부팅할 수 있는 상황** | 삭제는 **재부팅해야 확정된다.** 작업 중인 파일을 먼저 저장해 두자. |
| 노트북 배터리 | 꽂혀 있지 않아도 된다. (그렇게 동작하도록 고쳐 놨다.) |

PowerShell을 따로 설치할 필요는 없다. Windows에 이미 들어 있다.

> **주의:** 이 도구로 지운 기기는 다시 쓰려면 **처음부터 페어링**해야 한다. 지우기 전에, 설정 앱의 정상적인 "디바이스 제거"를 먼저 시도해 보자. 그게 되면 이 도구는 필요 없다.

### 1단계 — 파일 내려받기

이 저장소에서 **`Remove-BluetoothDevice.ps1`** 하나만 있으면 된다. (`Test-`로 시작하는 두 파일은 개발용이라 안 받아도 된다.)

GitHub 페이지 오른쪽 위 초록색 **Code** 버튼 → **Download ZIP** → 내려받은 ZIP을 오른쪽 클릭 → **압축 풀기**.

### 2단계 — 파일을 둘 위치 정하기

압축을 푼 폴더를 그대로 써도 되지만, 경로가 짧을수록 편하다. 예를 들어 `C:\` 밑에 `bt-cleaner` 폴더를 하나 만들고 `Remove-BluetoothDevice.ps1`을 거기에 옮겨 두자.

```
C:\bt-cleaner\Remove-BluetoothDevice.ps1
```

**중요:** 파일이 든 폴더가 어디인지 기억해 둘 것. 다음 단계에서 그 폴더에서 PowerShell을 열어야 한다.

### 3단계 — 그 폴더에서 PowerShell 열기

파일이 든 폴더를 파일 탐색기로 연 다음,

1. 주소 표시줄(위쪽에 `C:\bt-cleaner` 라고 적힌 칸)을 클릭한다.
2. 거기 적힌 내용을 지우고 **`powershell`** 이라고 입력한 뒤 Enter.

파란색(또는 검은색) 창이 뜨고 맨 앞에 `PS C:\bt-cleaner>` 라고 나오면 성공이다. **`PS` 뒤의 경로가 파일을 둔 폴더와 같아야 한다.** 다르면 아래를 입력해 이동한다.

```powershell
cd C:\bt-cleaner
```

관리자 권한으로 열 필요는 없다. 필요하면 스크립트가 알아서 UAC 창(“이 앱이 디바이스를 변경하도록 허용하시겠어요?”)을 띄운다. 그때 **예**를 누르면 된다.

### 4단계 — 다운로드 차단 해제

Windows는 인터넷에서 받은 스크립트에 "차단됨" 표식을 붙인다. 이걸 떼지 않으면 실행이 막힌다. **받은 파일마다 한 번만** 하면 된다.

```powershell
Get-ChildItem *.ps1 | Unblock-File
```

아무 메시지도 안 나오면 정상이다.

### 5단계 — 페어링된 기기 목록 보기

```powershell
powershell -ExecutionPolicy Bypass -File .\Remove-BluetoothDevice.ps1 -List
```

`-ExecutionPolicy Bypass`는 "이번 실행에 한해 스크립트 실행 제한을 풀어라"는 뜻이다. Windows 기본값이 스크립트 실행을 막아 두기 때문에 필요하다. 시스템 설정을 영구히 바꾸지는 않는다.

기기 목록이 번호와 함께 나온다. 지우려는 기기가 목록에 있는지, 몇 번인지 확인하자.

### 6단계 — 삭제

**방법 A — 번호로 고르기 (권장)**

```powershell
powershell -ExecutionPolicy Bypass -File .\Remove-BluetoothDevice.ps1
```

목록이 다시 나오고 번호를 물어본다. 지울 기기의 번호를 입력하고 Enter.

**방법 B — MAC 주소를 직접 지정**

5단계 목록에 나온 MAC 주소를 그대로 넣는다.

```powershell
powershell -ExecutionPolicy Bypass -File .\Remove-BluetoothDevice.ps1 -Mac cad0ebc66e06 -Force
```

`-Force`는 "정말 지울까요?" 확인을 건너뛴다. 확실할 때만 쓰자.

어느 쪽이든 도중에 UAC 창이 뜨면 **예**를 누른다. 창이 하나 더 열려 작업이 진행될 수 있다.

### 7단계 — 재부팅

**반드시 재부팅해야 삭제가 확정된다.** 재부팅 전에는 지워진 것처럼 보여도 되살아날 수 있다. ([왜 그런지](#왜-bthserv-재시작을-하지-않는가))

재부팅 후 5단계를 다시 실행해서 목록에서 사라졌는지 확인하면 끝이다.

### 잘 안 될 때

| 증상 | 원인과 해결 |
|---|---|
| `이 시스템에서 스크립트를 실행할 수 없으므로` | `-ExecutionPolicy Bypass`를 빼먹었다. 5·6단계 명령을 그대로 복사해 쓰자. |
| `... 파일은 디지털 서명되지 않았습니다` / 실행이 그냥 막힘 | 4단계 `Unblock-File`을 안 했다. |
| `용어 ... 이(가) cmdlet ... 인식되지 않습니다` | 파일이 없는 폴더에서 실행 중이다. `cd`로 파일이 있는 폴더로 이동하자 (3단계). |
| UAC 창에서 "아니요"를 눌렀다 | 아무것도 안 지워진다. 명령을 다시 실행하고 **예**를 누르자. |
| 재부팅했는데 기기가 그대로다 | 어댑터가 여러 개인 PC에서는 아직 검증되지 않았다 ([미검증 항목](#아직-검증하지-못한-것)). 이슈로 알려주면 좋겠다. |

## 무엇이 문제인가

페어링 정보는 두 곳에 나뉘어 저장된다.

| 위치 | 내용 | 접근 권한 |
|---|---|---|
| `HKLM\SYSTEM\CurrentControlSet\Services\BTHPORT\Parameters\Devices\<MAC>` | 기기 이름, 최종 연결 시각 등 | 읽기는 관리자, 삭제는 SYSTEM |
| `...\BTHPORT\Parameters\Keys\<어댑터MAC>` | 페어링 키 | **SYSTEM만** — 관리자도 읽기 거부 |

설정 앱이 실패하면 양쪽에 찌꺼기가 남는다. PnP 노드가 사라진 뒤에도 레지스트리 항목만 남는 "유령 기기"도 생긴다.

`Keys` 아래 페어링 키는 **두 가지 형태**로 저장된다. 한쪽만 지우는 가이드가 많다.

- **하위 키** — LE 기기 (`Keys\<어댑터>\<기기MAC>`)
- **값(value)** — 클래식 BT 기기 (`Keys\<어댑터>` 아래 값 이름이 기기 MAC)

## 어떻게 동작하는가

1. **SYSTEM 권한** — `SYSTEM` 계정으로 실행되는 임시 예약 작업을 등록해 자기 자신을 재실행하고, 끝나면 작업을 지운다. PsExec이 필요 없는 이유다.
2. **양쪽 형태 모두 삭제** — `Devices\<MAC>` + `Keys` 하위 키 + `Keys` 값.
3. **블루투스 스택을 건드리지 않는다.** ← 핵심
4. 재부팅하면 확정된다.

## 왜 `bthserv` 재시작을 하지 않는가

**대부분의 가이드가 시키는 `net stop bthserv && net start bthserv`가 오히려 삭제를 되돌린다.**

BTHPORT 드라이버는 페어링 목록을 메모리에 들고 있다가, 스택이 깨어날 때 레지스트리로 **도로 덮어쓴다.**

이 저장소를 만들게 된 실제 작업에서 관측된 결과:

| 시도 | 순서 | 결과 |
|---|---|---|
| 1차 | 삭제 → `pnputil /remove-device` → `bthserv` 재시작 | `Devices` 항목 **전부 부활** (PnP 노드가 있던 기기만). `Keys`는 삭제 유지 |
| 2차 | 라디오를 내리고 삭제 시도 | `pnputil /disable-device`가 Home 에디션에서 차단 (`This command is not supported on this OS product`) |
| 3차 | 삭제만, 스택 안 건드림 → 재부팅 | **전부 유지** ✅ |

주의: 1차에서 `pnputil`과 `bthserv` 재시작을 동시에 돌려 **둘 중 어느 쪽이 범인인지는 분리하지 않았다.** 둘 다 건드리지 않는다는 결론은 어느 쪽이든 성립한다.

라디오를 내린 상태에서 지우는 것이 원래 정석이지만, `pnputil /disable-device`는 Home 에디션에서 막혀 있다. Pro 이상이라면 그 경로가 더 깔끔하고 재부팅도 필요 없을 수 있다.

## 개발 중 잡은 버그

둘 다 다른 사람이 같은 방식으로 구현하면 똑같이 밟을 것들이다.

**1. 배터리 전원이면 예약 작업이 실행되지 않는다.**
`Register-ScheduledTask`의 기본 설정은 *"컴퓨터가 AC 전원일 때만 작업 시작"* 이다. 노트북용 도구인데 이게 기본값이면 절반은 조용히 실패한다. 작업은 `Queued` 상태에서 영원히 멈춰 있고 에러도 안 난다.

```powershell
New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
```

**2. `State -eq 'Running'` 폴링은 레이스 컨디션이다.**
상태는 `Ready → Queued → Running → Ready` 순으로 바뀐다. `Running`만 기다리면 첫 폴링에서 빠져나가 **큐에 대기 중인 작업을 그대로 삭제**해버린다. 실제 완료 신호인 출력 파일이 나타날 때까지 기다려야 한다.

## 테스트

둘 다 가짜 MAC(`aabbccddeef*`)만 사용한다. **실기기는 건드리지 않는다.**

```powershell
.\Test-EndToEnd.ps1        # 관리자 창에서 (아니면 알아서 UAC를 띄운다)
.\Test-SelfElevation.ps1   # 반드시 일반 권한 창에서
```

`Test-EndToEnd.ps1` — 11개 검사:

- `Keys` **하위 키** 형태 (LE 기기) 심기 → 삭제 확인
- `Keys` **값(value)** 형태 (클래식 BT) 심기 → 삭제 확인
- `-Mac` 다중 인자 삭제
- **대화형 번호 선택** 경로 (stdin 리다이렉트로 `Read-Host` 자동화)
- 실기기 목록 무결성

`Test-SelfElevation.ps1` — 비관리자 상태에서 툴이 스스로 UAC를 띄우고, 승격된 인스턴스가 실제로 삭제하는지 확인한다. 관리자 창에서 실행하면 검증 대상 분기를 타지 않으므로 거부한다.

### 아직 검증하지 못한 것

- **다중 어댑터** — 개발 환경에 블루투스 어댑터가 하나뿐이라 `Keys` 아래 어댑터 순회 루프는 1개 케이스만 돌았다.
- **PowerShell 7** — 5.1에서만 검증했다.

### 테스트 작성 중 발견한 함정

`Keys` 삭제 검사를 `-notcontains`로 쓰면 **심기가 실패했을 때 공허하게 통과한다** (지울 게 없으니 없는 게 맞다). 실제로 중첩 이스케이프가 깨져 심기가 안 됐는데 삭제 검사는 PASS가 떴다. 심기 단계에 별도 검사를 두지 않았으면 커버리지가 없는 걸 모르고 넘어갔을 것이다.

원인은 이중 인용 here-string 안의 중첩 이스케이프(`` ```$ ``)였다. **보간 없는 단일 인용 here-string + 토큰 치환**으로 바꿔서 해결했다.

## 참고

- `.ps1` 파일은 반드시 **UTF-8 BOM 포함**으로 저장해야 한다. BOM이 없으면 PowerShell 5.1이 cp949로 읽어서 한글 주석·메시지가 전부 파싱 에러를 낸다.
- 검증 환경: Windows 11 Home 26100, PowerShell 5.1.26100.9168, Intel Wireless Bluetooth.
- 삭제한 기기를 다시 쓰려면 처음부터 페어링해야 한다.
