# 프로젝트 상태

## 확인된 환경

- Codex 읽기 전용 점검(2026-11-07, 경로 제외): Godot 실행 파일은 PATH에 없고 사용자 바탕 화면에 있으며 버전 출력은 4.7.2.stable.official이다. 구문 검사는 동작 검증이 아니다.
- `project.godot`의 프로젝트 이름은 `나 혼자만 서바이벌`이고 창은 1280×720으로 고정되어 있다. stretch mode는 `canvas_items`, aspect는 `expand`다. 렌더링 방식은 파일에 명시되지 않았고 기능 태그는 Forward Plus다. Windows 그래픽 드라이버는 `d3d12`로 설정되어 있다.
- Git 읽기 전용 점검(2026-11-07): 브랜치 `master`, 상위 `origin/master`이며 `.godot/`·빌드 출력·1MiB 이상 추적 파일은 없다. `.gitignore`는 `.godot/`, `/android/`, `.local/`을 제외한다. `core.autocrlf=true`, `.gitattributes`의 `text=auto`, `eol=lf`에서 줄바꿈 경고는 없었다.
- 동기화 프로그램 점검: Run 레지스트리와 시작 폴더에 일치 항목이 없고 `AigameDocSync` 예약 작업도 찾지 못했다. 전체 예약 작업 목록은 액세스 거부로 확인하지 못했다.
- 2026-11-07에 시작해 2026-11-21까지 제작한다. 하루 작업 계획은 약 9시간이며 최소 3시간이다(사용자 결정, 2026-11-08).
- Claude에서 공유 폴더 문서 읽기와 Notion 대상 페이지('AI 게임 만들기') 읽기·수정이 동작함을 확인했다(2026-11-07). 도구·커넥터 동작 확인이며 게임 기능 검증이 아니다.
- Godot 프로젝트 구성: `project.godot`은 Godot 4.7 설정이고 `main.tscn`이 메인 씬이다.
- CSV 파이프라인을 검증했다(2026-11-08). Godot 4.7.2는 `.csv`를 기본적으로 번역 리소스로 인식하므로 `.import`를 `importer="keep"`으로 설정해 원본을 유지한다. 내보내기 설정의 비리소스 파일 필터에 `*.csv`를 넣으면 실행 파일에 포함되며, 사용자가 내보낸 실행 파일에서 CSV를 읽어 동작하는 것을 확인했다.
- `export_presets.cfg`의 내보내기 경로는 `../../sosv_build/game.exe` 상대 경로이며 사용자별 절대 경로는 없다.
- Godot 4.7.2 헤드리스 300프레임 실행 3회가 모두 종료 코드 0이었다. 로그 파일은 `.local/godot_logs/`에 기록했고, 표준 오류에는 승인된 알려진 루트 인증서 저장소 메시지 두 줄만 있어 검사에서 제외했다(OPS-02).
- Codex의 Git 작업 브랜치 커밋이 동작함을 확인했다(OPS-01).
- Claude는 저장소를 읽기 전용으로 직접 읽는다. 공유 폴더 복사는 OPS-02부터 하지 않는다.

## 완료 사항

- 초기 커밋 `bc0ebca`가 생성됨.
- 사용자가 Godot 편집기에서 프로젝트를 정상 실행하고 종료했음을 직접 확인함. 에이전트가 자동 검사한 결과는 아니다.
- 초기 운영 문서 작성. 사용자가 GitHub Desktop에서 커밋함.
- Godot 프로젝트를 사용자가 GitHub Desktop에서 GitHub 비공개 저장소에 게시함.
- Notion 정리본을 작성하고 대시보드형으로 개편함(2026-11-07). 메인 페이지는 대시보드, 섹션은 하위 페이지로 구성한다. 재조회로 반영을 확인했으며 화면 렌더링은 확인하지 못했다.
- 문서 운영 방식과 시스템 단위 개발 절차를 정함. 세부 내용은 AGENTS.md를 따른다.
- 전체 뼈대와 시스템 목록 10개를 사용자가 확정했다(2026-11-08). 세부는 game_design.md의 '전체 뼈대'와 시스템 목록을 따른다. 시스템 1 상세 기획이 승인됐고, 나머지 시스템의 상세 기획은 아직 시작하지 않았다.
- 작업명을 '나 혼자만 서바이벌'로 정하고 장르를 뱀서라이크(생존형 액션)로 정했다(사용자 결정, 2026-11-08).
- 시스템 1(플레이어와 맵)의 상세 기획과 예외·누락 검토를 사용자가 승인했다(2026-11-08). CSV 공통 약속도 함께 확정했다. 세부는 `docs/systems/01_player_and_map.md`를 따른다.
- 시스템 1(플레이어와 맵) A단계를 완료했다(2026-11-08). 플레이어 이동, 카메라 추적과 맵 경계 정지, 맵 경계 충돌, CSV 읽기 공통 기능이 동작한다. 사용자가 편집기와 내보낸 실행 파일에서 확인 항목을 모두 통과했다.
- 시스템 2(적 생성과 이동)의 상세 기획과 예외·누락 검토를 사용자가 승인했다(2026-11-08). CSV 공통 자료형에 `Enum`을 추가하기로 했다. 세부는 `docs/systems/02_enemy_spawn_and_movement.md`를 따른다.
- 시스템 2(적 생성과 이동) A단계를 완료했다(2026-11-08). 사용자가 실행 파일에서 플레이 검증 20개 항목을 모두 통과했다.
- 시스템 1의 이동 규칙 두 가지를 변경하고 검증했다(2026-11-08). 이동 입력을 WASD로 교체했고, 맵 경계에서 멈추던 동작을 벽을 따라 이동하는 동작으로 바꿨다. 사용자가 확인 항목 12개를 모두 통과했다.
- 사용을 중단한 공유 폴더 동기화 프로그램 파일과 지난 시험 로그를 삭제했다 (OPS-03).
- 시스템 3(전투와 생존) A단계를 완료했다(2026-11-09). P0 자동 검사 93개와 사용자 플레이 확인을 모두 통과했다.
- 시스템 4(경험치와 레벨업) A단계를 완료했다(2026-11-09). P0 자동 검사 140개와 사용자 플레이 확인 13개를 모두 통과했다.

## 현재 구현 상태

- 시스템 1(플레이어와 맵) A단계가 구현되어 있다. 1280×720 창 모드 고정, 2560×1440 맵, WASD 8방향 이동(대각선 속도 정규화), 맵 경계에서 벽을 따라 이동(경계를 향하는 성분만 차단), 카메라 추적과 맵 경계 정지, CSV 읽기 공통 기능(`scripts/csv_data_store.gd`)이다.
- 구현 파일: `project.godot`, `scripts/main.gd`, `scripts/csv_data_store.gd`, `scripts/map.gd`, `scripts/player.gd`, `scenes/map.tscn`, `scenes/player.tscn`, `data/player.csv`.
- 시스템 2 A단계에서 적 생성·추적 이동·개체 간 밀어내기·화면 밖 재배치·동시 생존 상한이 동작한다. 적 200마리를 1분 유지해도 프레임 저하가 없었다.
- 구현 파일: `scripts/enemy_manager.gd`, `scripts/enemy.gd`, `scripts/csv_data_store.gd`, `data/enemy.csv`, `data/spawn.csv`, `data/spawn_rule.csv` 및 기존 플레이어·맵 파일이다.
- 시스템 3(전투와 생존) A단계에서 자동 2타 공격·대상 재선정, 감속 넉백과 추적 합산, 체력·개체별 접촉 재피격 제한, 직선 투사체와 단일 소멸 조건, 논리 사망·흐려짐·생존 수 제외, 임시 체력·사망 표시가 동작한다.
- 구현 파일: `scripts/combat_data.gd`, `scripts/projectile.gd`, `tests/p0_runner.gd`, `tests/run_headless.py`, `data/projectile.csv`, `data/basic_attack.csv` 및 변경된 기존 파일 `scripts/main.gd`, `scripts/csv_data_store.gd`, `scripts/player.gd`, `scripts/enemy.gd`, `scripts/enemy_manager.gd`, `data/player.csv`, `data/enemy.csv`, `data/spawn.csv`다. 새 CSV의 `.import`도 포함한다.
- 시스템 4(경험치와 레벨업) A단계에서 적 사망 위치 경험치 드랍, 가속 끌어당김과 경로 접촉 적립, 바닥 경험치 상한 합치기, 레벨 요구량 마지막 행 반복과 다중 레벨업 이월, 레벨업당 강화 포인트 1개와 레벨업 신호, 임시 레벨·경험치 표시가 동작한다.
- 구현 파일: `scripts/experience_data.gd`, `scripts/experience_manager.gd`, `scripts/experience_orb.gd`, `data/level.csv`, `data/xp_rule.csv`와 두 CSV의 `.import`, 변경된 기존 파일 `scripts/main.gd`, `scripts/enemy.gd`, `scripts/enemy_manager.gd`, `scripts/player.gd`, `scripts/combat_data.gd`, `data/enemy.csv`, `data/player.csv`, `tests/p0_runner.gd`다.
- 시스템 5~10은 상세 기획 전이다.

## 미해결 문제

- 시스템별 세부 수치와 콘텐츠 종류가 미정이다. 전체 목록은 game_design.md의 '미정 항목'에 있다.
- 저장소 이름이 작업명과 다르다. 사용자가 GitHub에서 바꾼다.
- P0 자동 검사(tests/p0_runner.gd)가 시스템 3·4 규칙을 확인한다. 시스템 1·2의 규칙은 아직 P0에 포함되지 않았다.
- Notion 메인 페이지의 소개 문장과 다음 행동은 Claude 초안이며 사용자가 다시 쓸 예정이다.

## 보류한 작업

- Claude와 GitHub의 직접 연동: 선택적으로 보류함. 현재 Filesystem으로 문서를 읽을 수 있어 중복 설정을 줄이기 위한 결정이다. 오류나 미해결 문제가 아니다.
- 시스템 2 B단계: 두 번째 적과 나머지 생성 규칙을 시스템 3 이후 일괄 추가한다.
- 시스템 3 B단계: 정식 적 2종의 전투 수치, 임시 원거리 적·투사체 데이터의 정리 방법을 정한다.
- 시스템 4 B단계: 정식 적별 경험치, 레벨 요구량, 획득 반경·끌어당김·상한의 최종값을 정한다.

## 다음 작업

- 시스템 5(기본 스킬)의 상세 기획을 시작한다.
