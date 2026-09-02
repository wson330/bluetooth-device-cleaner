# Bluetooth Device Cleaner

Windows 11 설정에서 **"디바이스 제거"가 잘 안되는 경우가 많다.** 이 때 제거하고 싶은 블루투스 기기 항목을 레지스트리에서 강제로 지우기 위한 스크립트.

의존성 없음. PowerShell 5.1 기본 내장 기능만 사용. PsExec 같은 외부 도구를 받을 필요가 없고, Windows 11 Home 에디션에서도 작동함.

```powershell
Get-ChildItem *.ps1 | Unblock-File                       # 내려받은 파일 차단 해제 (최초 1회)
powershell -ExecutionPolicy Bypass -File .\Remove-BluetoothDevice.ps1 -List   # 페어링된 기기 목록
powershell -ExecutionPolicy Bypass -File .\Remove-BluetoothDevice.ps1         # 번호로 골라서 삭제
powershell -ExecutionPolicy Bypass -File .\Remove-BluetoothDevice.ps1 -Mac cad0ebc66e06 -Force
```

관리자 권한이 없으면 알아서 UAC를 띄운다. **삭제 후 재부팅해야 확정된다.**

세부 절차는 아래를 확인

---

## 사용법

### 시작하기 전에 확인할 것

| 조건 | 설명 |
|---|---|
| **Windows 10 또는 11** | 검증은 Windows 11 Home 26100에서 했다. |
| **관리자 계정** | 본인 PC의 주 계정이면 대개 관리자다. (회사 지급 PC는 막혀 있을 수 있음.)
| **재부팅할 수 있는 상황** | 삭제는 **재부팅해야 확정된다.** 작업 중인 파일을 먼저 저장해 두자. |

### 1단계 — 파일 내려받기

이 저장소에서 **`Remove-BluetoothDevice.ps1`** 하나만 있으면 된다. (`Test-`로 시작하는 두 파일은 개발용이라 다운로드 불필요.)

### 2단계 — 파일을 둘 위치 정하기

압축을 푼 폴더를 그대로 써도 되지만, 경로가 짧을수록 편하다. 예를 들어 `C:\` 밑에 `bt-cleaner` 폴더를 하나 만들고 `Remove-BluetoothDevice.ps1`을 거기에 옮겨 두자.

```
C:\bt-cleaner\Remove-BluetoothDevice.ps1
```

**중요:** 파일을 다운받은 경로에서 PowerShell을 열어야 한다.

### 3단계 — 그 폴더에서 PowerShell 열기

파일이 든 폴더를 파일 탐색기로 연 다음,

1. 주소 표시줄을 클릭한다.
2. 주소 표시줄의 내용을 지우고 **`powershell`** 이라고 입력한 뒤 Enter.

파란색(또는 검은색) 창이 뜨고 맨 앞에 `PS C:\bt-cleaner>` 라고 나오면 성공. **`PS` 뒤의 경로가 파일을 둔 폴더와 같아야 한다.** 다르면 아래를 입력해 이동한다.

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

**반드시 재부팅해야 삭제가 확정된다.** 재부팅 전에는 지워진 것처럼 보여도 되살아날 수 있다. ([왜 그런가?](#왜-bthserv-재시작을-하지-않는가))

재부팅 후 5단계를 다시 실행해서 목록에서 사라졌는지 확인하면 끝.

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

개발 과정에서 관측된 결과:

| 시도 | 순서 | 결과 |
|---|---|---|
| 1차 | 삭제 → `pnputil /remove-device` → `bthserv` 재시작 | `Devices` 항목 **전부 부활** (PnP 노드가 있던 기기만). `Keys`는 삭제 유지 |
| 2차 | 라디오를 내리고 삭제 시도 | `pnputil /disable-device`가 Home 에디션에서 차단 (`This command is not supported on this OS product`) |
| 3차 | 삭제만, 스택 안 건드림 → 재부팅 | **전부 유지** ✅ |

주의: 1차에서 `pnputil`과 `bthserv` 재시작을 동시에 돌려 **둘 중 어느 쪽이 범인인지는 분리하지 않았다.** 둘 다 건드리지 않는다는 결론은 어느 쪽이든 성립한다.

라디오를 내린 상태에서 지우는 것이 원래 정석이지만, `pnputil /disable-device`는 Home 에디션에서 막혀 있다. Pro 이상이라면 그 경로가 더 깔끔하고 재부팅도 필요 없을 수 있다.


## 참고

- `.ps1` 파일은 반드시 **UTF-8 BOM 포함**으로 저장해야 한다. BOM이 없으면 PowerShell 5.1이 cp949로 읽어서 한글 주석·메시지가 전부 파싱 에러를 낸다.
- 검증 환경: Windows 11 Home 26100, PowerShell 5.1.26100.9168, Intel Wireless Bluetooth.
- PowerShell 7에서는 테스트 아직 안해봄.
- 삭제한 기기를 다시 쓰려면 처음부터 페어링해야 한다.
