# Bluetooth Device Cleaner

Windows 11 설정 앱에서 **"디바이스 제거"가 안 먹히는 블루투스 기기**를 레지스트리에서 강제로 지운다.

의존성 없음. PowerShell 5.1 기본 내장 기능만 사용한다. PsExec 같은 외부 도구를 받을 필요가 없고, **Home 에디션에서도 동작한다.**

```powershell
.\Remove-BluetoothDevice.ps1 -List                       # 페어링된 기기 목록
.\Remove-BluetoothDevice.ps1                             # 번호로 골라서 삭제
.\Remove-BluetoothDevice.ps1 -Mac cad0ebc66e06 -Force    # MAC 지정 삭제
```

관리자 권한이 없으면 알아서 UAC를 띄운다. **삭제 후 재부팅해야 확정된다.**

---

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
