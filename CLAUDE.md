# CLAUDE.md

이 프로젝트의 작업 규칙은 **AGENTS.md**가 원본이다. 작업을 시작하기 전에 AGENTS.md 전체를 읽고 그대로 따른다. 이 파일과 AGENTS.md가 다르면 AGENTS.md를 따른다.

핵심 요약(세부는 AGENTS.md):
- 요청마다 `work/{작업 ID}` 브랜치를 만들고 그 브랜치에만 커밋한다. push·master 병합·Notion 수정은 하지 않는다.
- 시작 시 작업 트리를 확인한다. 요청에 없는 변경이 있으면 시작하지 않고 보고한다. 사용자 CSV 값 변경은 바이트 보존·커밋 제외하고 보고서에 표로 적는다.
- Godot 검사는 `tests/run_headless.py`(오류 창 억제 실행기)로만 실행한다. 판정은 `.local/<name>-done.json`의 code와 상태 JSON 기준이다. 검사 종료는 `tests/test_exit.gd`의 finish를 쓴다.
- 허용 결과: S1-01 MISMATCH 2건, 인증서 stderr 2줄.
- FAIL 없는 0xC0000005 크래시는 1회 재실행(시도 횟수에 포함하지 않음). 두 번째도 크래시면 중단하고 보고한다.
- 판정·피해·시점·AI·생성·전투 RNG 기대값은 바꾸지 않는다. 표시 기대값만 바꿀 때는 바꾼 검사 이름을 보고한다.
- 연출 값은 combat_presentation.csv 키, typed 캐시로 읽는다. 매 프레임 경로에서 presentation()·문자열 변환 금지. 이펙트는 고정 풀, 활성 없으면 redraw 금지, 재질 공유(OPT-01 규칙).
- 보고서: `.local/reports/{작업 ID}.md`, 짧은 형식.
