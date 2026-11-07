# 문서 자동 동기화

`scripts/doc_sync.ps1`은 프로젝트의 운영 문서 네 개를 공유 폴더의 지정된 복사본으로 동기화한다. 원본이 삭제된 경우 공유 복사본은 삭제하지 않으며, 매핑된 네 파일 외에는 읽거나 변경하지 않는다.

## 최초 설정

프로젝트 루트에서 `.local/doc-sync.json` 파일을 만든다. 이 파일에는 공유 폴더의 절대 경로가 들어가므로 Git에서 제외된다.

```json
{
  "SourceRoot": "프로젝트 루트의 절대 경로",
  "SharePath": "공유 폴더의 절대 경로",
  "IntervalSeconds": 60,
  "DebounceMilliseconds": 700
}
```

`SourceRoot`는 `AGENTS.md`와 `docs` 폴더가 있는 프로젝트 루트다. 감시 간격과 저장 묶음 시간은 기본값을 사용하거나 필요에 따라 조정할 수 있다.

## 시작·상태 확인·중지

Windows PowerShell 실행 정책 설정을 변경하지 않고 실행할 수 있도록 .cmd 진입점을 사용한다. PowerShell에서 프로젝트 루트로 이동한 뒤 실행한다.


```powershell
.\scripts\doc_sync.cmd start
.\scripts\doc_sync.cmd status
.\scripts\doc_sync.cmd stop
```

`start`는 숨겨진 백그라운드 PowerShell 프로세스를 시작하고, 시작 시 파일을 대조한다. 이후 파일 변경 감지와 주기적 대조로 복사본을 갱신한다. 이미 실행 중이면 두 번째 프로세스를 만들지 않는다. `status`는 프로세스 상태와 로그 위치를 표시한다. 실패 원인과 복사 결과는 `.local/doc-sync.log`에서 확인한다.

## 로그인 자동 시작

현재 Windows 로그인 자동 시작은 등록되어 있지 않다. 자동 시작을 나중에 등록하면 Windows 작업 스케줄러에서 해당 작업을 사용 안 함으로 전환하거나 삭제해 해제한다. 등록 방식과 범위는 별도 승인 후 안내한다.
