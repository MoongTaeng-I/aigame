# 나 혼자만 서바이벌

<img src="docs/images/app_icon.png" alt="나 혼자만 서바이벌 아이콘" width="128">

AI와 역할을 나눠 15일 동안 만든 2D 생존 액션 게임입니다. 한 판은 약 6분입니다.

## 실행 방법

1. GitHub Releases에서 zip 파일을 내려받아 압축을 풉니다.
2. `SoloSurvival.exe`를 실행합니다. `SoloSurvival.pck`가 같은 폴더에 있어야 합니다.

- 지원 환경: Windows 64비트

## 조작

| 입력 | 동작 |
|---|---|
| W·A·S·D | 이동 |
| Space | 질주 |
| F | 난도 |
| 1 | 은신 |
| 2 | 드래곤 피어 |
| 마우스 클릭 | 레벨업 카드 선택, 스킬 아이콘 강화 |
| ESC | 일시정지 |

## 한 판 흐름

1. 1:00 아이스 엘프 정예병 등장
2. 3:00 아이스 베어 우두머리 등장
3. 5:30 바루카 등장, 처치하면 클리어

## 만든 방식

- 사용자가 방향과 규칙을 결정하고 직접 플레이해 검증했습니다.
- Claude가 기획·작업 요청문 작성·결과 검토를 맡았습니다.
- 구현 AI(Codex → Claude Code)가 구현과 자동 검사를 맡았습니다.
- 게임 수치는 `data/*.csv`에 있습니다. 자세한 개발 기록은 Notion에 정리합니다.

Notion 포트폴리오: (추가 예정)

## 저장소 구조

| 폴더 | 내용 |
|---|---|
| `scripts/` | 게임 코드(GDScript) |
| `scenes/` | Godot 씬 |
| `data/` | 게임 수치·콘텐츠 표(CSV) |
| `assets/` | 그림·소리·글꼴·아이콘 |
| `tests/` | 자동 검사 코드 |
| `docs/` | 기획서·시스템 문서·개발 일지 |

## 빌드와 자동 검사

Godot 4.7.2 편집기와 같은 버전의 Windows 내보내기 템플릿이 필요합니다.

- 내보내기(저장소 폴더에서): `<Godot 편집기 실행 파일> --headless --path . --export-release "Windows Desktop" ../build/SoloSurvival.exe`
- 자동 검사: `.local/godot_path.txt`에 Godot 편집기 실행 파일 경로를 적은 뒤 `python tests/run_headless.py <작업 ID> p0 <회차>`(전체 P0 검사), `python tests/run_headless.py <작업 ID> runtime <회차>`(헤드리스 실행 확인). 결과는 `.local/` 아래에 저장됩니다.

자세한 내용은 [docs/game_design.md](docs/game_design.md)의 '빌드 방법' 절에 있습니다.

## 라이선스·출처

- 글꼴: `assets/fonts/OFL.txt` (SIL Open Font License 1.1)
- 음악·효과음: `assets/audio/CREDITS.txt`

## 고지

이 게임은 웹툰 '나 혼자만 레벨업'의 비상업적 팬 게임(포트폴리오)이며, 원작의 저작권은 각 권리자에게 있습니다.
