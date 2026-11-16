# 시스템 10. 색감·AI 이미지·사운드 — 히트 FX 부분 실험

- 현재 단계: FX-IMPL-01·추가 단계 B 사용자 종합 승인(2026-11-11). 항목별 직접 확인 결과는 미기록. 시스템 10 전체 상세 기획·완료 승인이 아니다.
- 승인일: 2026-11-11 히트 FX 요청 범위만
- 완료일: 미정
- 관련 개발 일지 항목 제목: [히트 이펙트] 기획·검토·구현 (FX-IMPL-01)

- 사용자 원문(2026-11-11): "승인". FX-IMPL-01과 추가 단계 B의 종합 승인이다. 색 구분, 크기·시간 체감, 적 150마리 이상 렉, Enabled 1/0 비교의 개별 확인 결과는 미기록이며 개별 통과로 확대하지 않는다.
- 같은 날 이전 응답(첫 불꽃 버전 테스트): "테스트 사항은 문제 없는데, 불꽃 색상이 발사체 색상과 구분이 안가. 빨간색을 지정하고, 불꽃 크기를 늘려줘. 지속 시간은 0.25초로 설정하고."
- 확정: 빨강 계열·크기 확대·Duration_sec 0.25(사용자 지정). 제안·검증용: #e81818 / #ff6a6a, Radius 28, Core_radius 7. 미정: 최종 외형·소리·보스/스킬별 FX 구분. 렌더링 비용(GPU·실제 화면 프레임)은 헤드리스로 측정하지 않았다.

## 개요와 확정·제안 구분

- 확정(사용자 결정): "몬스터가 공격당할 시에 히트 이펙트 하나만 넣어야겠다. 어디가 맞는건지 확인이 잘 안되네." / "맞은 지점에 불꽃이 잠깐 번쩍이는 걸로 하자. 이후 히트 FX 넣었을 때의 렉 유발 테스트도 할 겸".
- 제안 범위: 기본 공격·난도·이그리트·베르 등 유효한 몬스터 피해에 같은 불꽃 하나를 쓴다. 기존 표시를 유지하고 소리·피해 숫자·몬스터 몸 번쩍임·다른 FX를 추가하지 않는다.
- 추가 확정(사용자 결정, 2026-11-11): "불꽃 색상이 발사체 색상과 구분이 안가. 빨간색을 지정하고, 불꽃 크기를 늘려줘. 지속 시간은 0.25초로 설정하고." 빨강 계열·크기 확대·Duration_sec0.25는 확정이다.
- 제안: 구체적인 빨강 #e81818/#ff6a6a와 반경28/중심7은 검증용 값이다. Enabled1·Max_active200과 풀 동작은 유지한다.
- 미정: 최종 외형·소리·보스/스킬별 FX 구분.

## 규칙

1. 유효한 양수 피해 한 번에 FX 한 번이다. 비활성·이미 사망·0 이하 피해는 표시하지 않고, 처치 타격은 표시한다. 피해량·판정·사망·넉백·이동·AI는 기존대로다.
2. 기존 몬스터 피해 경로에는 별도 충돌/타격 좌표가 없다. 기본 공격의 선 끝은 몬스터 중심이고, 난도·이그리트 부채꼴·베르 경로는 판정 모양만 있을 뿐 표면 타격점이 없다. 모두 피해 순간 몬스터의 세계 중심을 사용한다. 원형/선분의 새 접점 계산을 만들지 않는다. 현재 투사체는 플레이어만 공격하므로 몬스터 FX 대상이 아니다. 질주·은신·피어도 몬스터 피해가 없다.
3. 표시 위치는 발생 순간 세계 좌표로 저장한다. 적이 이동/재사용/처치되어도 FX가 적을 따라가지 않는다. 별도 난수·노드 생성·물리 충돌은 없다.
4. 제안: Node2D 하나에서 고정 슬롯을 일괄 그린다. 매 피격마다 노드/Timer를 만들거나 삭제하지 않는다. 상한이 차면 가장 오래된 슬롯을 원형 순서로 재사용해 새 피격을 표시한다. 슬롯과 노드 수는 증가하지 않는다. 네 갈래 불꽃과 밝은 중심이 지속 시간 동안 옅어지고 사라진다.
5. Enabled=0이면 피격 신호를 구독하지 않고 슬롯·불꽃 도형을 할당하지 않으며 FX 생성/업데이트/그리기를 하지 않는다. 관리 Node2D 하나만 남는다. 게임 시작 시 CSV를 읽으므로 비교하려면 값을 바꾸고 새로 실행한다. 실시간 파일 감시/재로드는 없다.
6. CSV 파싱/필드 오류는 기존 데이터 오류 화면으로 게임을 멈추고 파일·행·열을 표시한다. Enabled는0/1, 시간/반경은 유한한 양수, Core_radius≤Radius, Max_active≥1, 색은 HTML 색상이어야 한다. 필수 Id는 hit_spark다.
7. 일시정지 중 FX 시간도 멈춘다. 화면 그리기 비용은 헤드리스 물리 측정으로 알 수 없으므로 Enabled1/0 직접 플레이로 별도 확인한다. 측정값에 새 성능 합격 기준을 붙이지 않는다.

## 현재 구현 상태: 시스템8 임시 UI·플레이어 히트 표시 (2026-11-12)

아래는 S8-IMPL-01 추가 단계 B와 S8-IMPL-02/B/C에서 이미 구현된 임시 표시를 동기화한 것이다. 초반·중간 보스 플레이 종합 승인은 각각 S8-DONE-01·S8-DONE-02에 기록됐다. 정식 UI 기획은 시스템9에서 정하며 여전히 미정이고, 시스템10 전체 아트/사운드 완료 승인이 아니다. 위 FX-IMPL-01 규칙·승인 기록은 당시 몬스터 FX 범위로 보존한다.

- **보스 토스트 패널:** 경고~출현 중 화면 상단 가운데 둥근 패널·어두운 반투명 바탕·보라 테두리·가운데 정렬·짧은 페이드로 표시한다. 기존 바 형태를 대체했으며 문구는 boss_rule.Toast_text와 이름 치환이다.
- **진행 시간:** 오른쪽 위에 기존 경과 시간을 MM:SS로 표시하고 선택 화면·사망 정지 중 멈춘다. 왼쪽 위 임시 적 수 표시는 유지한다.
- **보유 그림자:** 스킬 아이콘 줄 바로 위 우측에 소환 순서대로 아이콘+Name_ko를 표시하며 소환/제거 시 갱신한다. Icon이 빈칸이면 기존 그림자 임시 도형을 작은 아이콘으로 쓴다.
- **UI75%:** 캐릭터 스킬 UI와 보유 그림자 아이콘·이름을 기존 실제 표시 크기의75%로 축소했다. 우측·스킬 위 배치 및 클릭 좌표를 유지하며 토스트/진행 시간은 이 축소에 포함하지 않는다.
- **플레이어 파란 히트 아이콘:** 접촉·투사체·보스 스킬 등 유효 피해마다 기존 몬스터와 같은 도형·크기·지속 시간의 표시를 파란색으로 출력한다. 피해 순간 플레이어 세계 중심에 남으며 몬스터 빨간 표시와 구분한다. 피해0 엘프 밀기·거절된 피해는 표시하지 않는다. 기존 hit_fx 설정과 고정 슬롯 방식을 재사용하되 플레이어 표시용 배치 노드를 별도로 사용한다.
- **확정/제안/미정:** 위 동작과75%·파란색은 사용자 확정이다. 구체적인 색·여백·패널 크기·페이드 등 이름 붙인 연출 상수 및 밸런스 초안을 전체 최종값 승인으로 확대하지 않는다. 정식 UI·최종 외형·소리·보스/스킬별 FX 분리는 미정이다.

## 테이블

`data/hit_fx.csv`: UTF-8 BOM·LF·엑셀 숫자 표기·첫 열 Id, .import keep.

| 열 | 형식/의미 | 현재값(확정/제안) | 근거 |
| --- | --- | --- | --- |
| Id | String, 필수 불꽃 행 | hit_spark | 이번1종의 식별자 |
| Enabled | Int, 표시 켬/끔 | 1 | 요청의 켬/끔 비교,0이면 비활성 |
| Duration_sec | Float, 표시 시간(초) | 0.25(확정) | 사용자 지정0.25 |
| Radius | Float, 불꽃 끝 반경(px) | 28(제안) | 기존16보다 확대. 몬스터 지름32px를 참조한 검증용 값이며 불꽃 지름은56px |
| Core_radius | Float, 밝은 중심 반경(px) | 7(제안) | 반경28의 불꽃에 맞춰 기존4보다 확대한 검증용 값 |
| Max_active | Int, 동시 논리 슬롯 상한 | 200 | spawn_rule.csv Max_alive200의 한 번 전체 피격을 담는 시작 상한 제안 |
| Outer_color | String, HTML 색 | #e81818(제안) | 발사체의 노랑 #ffdb59/#fff6c7과 다른 고채도 빨강, 몬스터 #ff7d68과 비교할 검증용 값 |
| Core_color | String, HTML 색 | #ff6a6a(제안) | 노란 중심을 붉은 밝은 중심으로 변경한 검증용 값 |

Duration_sec0.25는 사용자 지정이며 색·크기의 구체적인 값과 나머지 기존 값은 검증용 제안이다. RGB 수치 비교를 사람이 보는 구분의 통과 판정으로 쓰지 않는다. 지정한 다섯 칸 외 값은 바꾸지 않는다. 시스템은 피해 알림·고정 슬롯 재사용·도형 표시이며 콘텐츠는 위 불꽃1행이다.

## 시스템 10 후보(확정 아님)

- 2.5D 느낌(y-sort, 지면 그림자, 납작한 범위 표시, 크기 조정, 시차 배경). 논리는 2D 평면 유지, 실제 3D 전환은 제외.

## 테이블 컬럼 설명

파일 공통 형식과 ID 규칙은 [game_design.md의 데이터 관리 원칙](../game_design.md#데이터-관리-원칙)을 따른다.

### hit_fx.csv

예시는 2026-11-12 기준 CSV의 `hit_spark` 행 값이며 최종 밸런스 값이 아니다.

| 컬럼 | 설명(무엇을 정하는 값인가) | 예시 | 자료형 | 단위 | 허용 범위·허용값 | 빈칸 허용 | 참조(다른 테이블·컬럼) | 잘못된 값일 때 | 비고 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Id | 행을 조회·참조하는 식별자 | hit_spark | String | 해당 없음 | 공통 원칙 참조 | 공통 원칙 참조 | 없음 | 자료형 오류: 데이터 오류 화면; 조건 위반: 데이터 오류 화면 | hit_spark 행 필수; 다른 행의 내용 범위는 검증하지 않음 |
| Enabled | 불꽃 FX 표시를 켜거나 끔 | 1 | Int | 해당 없음 | 0 / 1 | 불가 | 없음 | 자료형 오류: 데이터 오류 화면; 조건 위반: 데이터 오류 화면 | hit_spark 행 검증; 꺼도 다른 필드 검증은 생략하지 않음 |
| Duration_sec | 불꽃 표시 지속 시간 | 0.25 | Float | 초 | 유한한 양수 | 불가 | 없음 | 자료형 오류: 데이터 오류 화면; 조건 위반: 데이터 오류 화면 | hit_spark 행에 대해 검증 |
| Radius | 불꽃 바깥 끝 반경 | 28 | Float | px | 유한한 양수 | 불가 | 없음 | 자료형 오류: 데이터 오류 화면; 조건 위반: 데이터 오류 화면 | hit_spark 행에 대해 검증 |
| Core_radius | 밝은 중심 반경 | 7 | Float | px | 유한한 양수; Radius 이하 | 불가 | hit_fx.csv.Radius | 자료형 오류: 데이터 오류 화면; 조건 위반: 데이터 오류 화면 | hit_spark 행에 대해 검증 |
| Max_active | 동시에 유지하는 논리 FX 슬롯 상한 | 200 | Int | 개 | 1 이상 | 불가 | 없음 | 자료형 오류: 데이터 오류 화면; 조건 위반: 데이터 오류 화면 | hit_spark 행 검증; 상한이면 가장 오래된 슬롯 재사용, 적 수와 동적 연동 없음 |
| Outer_color | 불꽃 바깥 부분 색 | #e81818 | String | 해당 없음 | Color.html_is_valid가 허용하는 HTML 색 문자열 | 불가 | 없음 | 자료형 오류: 데이터 오류 화면; 조건 위반: 데이터 오류 화면 | hit_spark 행에 대해 검증 |
| Core_color | 밝은 중심 색 | #ff6a6a | String | 해당 없음 | Color.html_is_valid가 허용하는 HTML 색 문자열 | 불가 | 없음 | 자료형 오류: 데이터 오류 화면; 조건 위반: 데이터 오류 화면 | hit_spark 행에 대해 검증 |

### 현재 상태: 공통 토스트·질주/바루카 잔상·난도

화면 상단 가운데에 폭 533px 토스트를 최신 순으로 쌓는다. 높이는 최소 88px이며 문구 줄바꿈에 맞춰 증가한다. 글자 크기20·여백18은 유지하고 각 패널의 실제 높이에 Toast_gap_px를 더해 다음 패널을 배치한다. 긴 보스 경고도 패널 안에 표시한다. 일반2초, 보스 경고는 기존 시간, 간격8px, 동시4개, 초과 시 가장 오래된 것부터 즉시 페이드 아웃한다. 페이드는 기존0.16/0.2초다. 정지 중에도 진행하며 완료 표시보다 위에 둔다. 스킬·소환 이름은 각각 skill.csv/shadow.csv Name_ko, 조사 을/를·이/가는 이름 끝 받침으로 선택한다.

질주는 플레이어의 실제 임시 도형을 복제하며 바루카 전광석화와 공통 잔상 노드를 사용한다. 수명0.3초·투명도0.45는 공유한다. 플레이어 질주만 시간 간격0.045초를 유지하고 바루카 전광석화는 이동마다 Blink_trail_count=8개를 경로 1/8부터 끝점까지 등간격으로 남긴다. 고속으로 한 프레임에 지나간 구간도 빠짐없이 생성한다. 그림자 텔레포트의 기존 Afterimage_sec는 바꾸지 않는다. 잔상에는 피해·판정·충돌·탐색이 없다.

ART-01부터 플레이어 질주 잔상은 생성 순간의 걷기 시트 칸과 좌우 반전을 복제한다. 수명·생성 간격·투명도는 기존 값을 유지하며 잔상에는 발밑 그림자를 복제하지 않는다. 플레이어 본체 이미지 아래에는 판정 원 중심의 검정 타원 그림자(32×12px, 알파0.35)를 그린다. 텍스처는 mipmap을 생성하고 CanvasItem의 선형 mipmap 필터로 표시한다. 공용 `SpriteBody` 부품은 같은 열 구조를 받을 수 있지만 이 단계에서는 적·보스·그림자에 적용하지 않는다.

ART-02에서 공용 `SpriteBody`에 `Sprite_layout`을 추가한다. 플레이어는 `dir3`로 기존 방향 행 동작을 유지하고, 이그리트는 `state3`로 대기/이동/공격 행을 사용한다. 두 시트 모두 mipmap·선형 mipmap 필터와 같은32×12·알파0.35 발밑 그림자를 사용한다. 이그리트 텔레포트 출발 잔상은 당시 칸·반전을 복제하고, 이미지가 없는 베르는 기존 도형과 도형 잔상을 유지한다. 적·보스·다른 그림자 표시는 바꾸지 않는다.

ART-03에서 플레이어 `dir3` 표시는 이동·대기 시트를 분리한다. 이동 중에는 이동 시트, 정지·빙결·두려움 시전 등 이동 불가 중에는 마지막 방향의 대기 시트를 반복하며 상태 전환 시 새 시트 첫 칸부터 시작한다. 질주 잔상은 이동 시트의 당시 칸·반전만 복제한다. 대기 시트가 없으면 경고 후 이동 시트 첫 칸을 사용하고, 이그리트 `state3`와 다른 대상은 바꾸지 않는다.

벨리온 이미지는 ART-04의 `state3` 시트를 쓴다. 발 기준 `Chain_hand_x`·`Chain_hand_y`(15/-95px, 왼쪽은x만 반전)를 준비 빛과 사슬 시작점으로 공유한다. 사슬은 손에서 현재 판정 끝점(중심+현재 각도×Range, 바닥 높이)까지 높이가0으로 내려오는 곡선이다. `Belion_chain_segments`개의 마름모 조각 두께는 `Belion_chain_width`(24px), 빛 폭은 두께×0.75(18px), 테두리는 두께×0.1875(4.5px)다. S7-FIX-05에서 Range만450으로 늘리며 나머지 전투 수치·번갈아 방향은 유지한다. 공격 칸은 준비1번·쓸기 전체2번·종료 직후3번0.1초·이후4번0.1초다. 칼끝 궤적0.15초·피격 파편·포즈 텔레포트 잔상은 유지하며 이미지 없는 도형은 기존 준비 빛·사슬 표시를 쓴다.

#### SpriteBody 표시 열

ART-05 베르는 `state3`1928×1170(4×3, 칸482×390) 시트와52×18 발밑 타원을 사용한다. 사용자 추가 답변에 따라 기존 즉시 돌진을 유지하고 준비1번은 생략한다. 공격2번은 돌진 처음0.1초,3번은 나머지 돌진,4번은 기존 후딜0.3초 동안 표시한다. 후딜 없는 표시 조건에서는4번을0.1초 유지한다. 돌진x<0이면 반전하고 진행 중 바꾸지 않는다. 새 돌진 잔상은 공용 Trail_life_sec0.3/Trail_interval_sec0.045/Trail_alpha0.45를 사용하며 그 순간 칸·반전을 복제한다. 텔레포트는 기존 수명1초·불투명도0.45를 유지한다. 이미지 없는 경우 도형 대체를 유지한다.

`player.csv`와 `shadow.csv`가 공용으로 쓰는 표시 열이다. 그림자 전용 상태 시간 열은 플레이어에는 없으며, `shadow.csv`에서 `Sprite_path`가 빈 행은 나머지 이미지 열도 비운다. `Shadow_w`·`Shadow_h`는 이미지 유무와 독립이며 각각 빈칸이면32·12px를 쓴다. 유한한 양수만 허용하고 잘못된 값은 데이터 오류 화면으로 처리한다. 자세한 그림자 자료형·검증 규칙은 시스템7 표가 소유한다.

| 열 | 의미 | player_01 예시 | igrit 예시 | belion 예시 | charger_test(베르) 예시 |
|---|---|---|---|---|---|
| Sprite_path | 이동·상태 시트 리소스 경로 | res://assets/art/sd/sd_player.png | res://assets/art/sd/sd_igris.png | res://assets/art/sd/sd_belion.png | res://assets/art/sd/sd_beru.png |
| Idle_sprite_path | dir3 대기 시트 리소스 경로 | (빈칸) | 해당 없음 | 해당 없음 | 해당 없음 |
| Sprite_layout | 행 배치 종류 | pose | pose | pose | pose |
| Sprite_cols / Sprite_rows | 가로·세로 칸 수 | 2 / 1 | 2 / 1 | 2 / 1 | 2 / 1 |
| Sprite_cell_height | 한 칸의 화면 표시 높이(px) | 95 | 143 | 158 | 144 |
| Sprite_baseline | 원본 칸의 발 기준선 y(px) | 187 | 279 | 297 | 269 |
| Sprite_anchor_x | 원본 칸 안 몸 중심x(px), 빈칸이면 칸 가운데 | 68 | 125 | 105 | 89 |
| Sprite_foot_y | 판정 원 중심 아래 발 위치(px) | 8 | 8 | 8 | 8 |
| Anim_fps | 걷기·이동 반복 속도 | 12 | 8 | 8 | 8 |
| Idle_fps | dir3/state3 대기 반복 속도 | 6 | 6 | 6 | 6 |
| Attack_after_frame_sec | 이미지 공격 칸 유지 시간(초) | 해당 없음 | 0.1 | 0.1 | 0.1(돌진2번/후딜 없는 착지) |
| Shadow_w | 검정 발밑 타원 전체 너비(px), Optional Float | 32 | 56 | 60 | 52 |
| Shadow_h | 검정 발밑 타원 전체 높이(px), Optional Float | 12 | 20 | 22 | 18 |
| Chain_hand_x | 오른쪽 기준 발→사슬 손 x(px), Optional Float | 해당 없음 | 빈칸 | 15 | 빈칸 |
| Chain_hand_y | 발→사슬 손 y(px), Optional Float | 해당 없음 | 빈칸 | -95 | 빈칸 |

`Chain_hand_x`·`Chain_hand_y`는 shadow.csv 전용이며 유한한 좌표 쌍으로 함께 지정하거나 함께 비운다. 음수·0도 허용하고 왼쪽 반전 시 x 부호만 바꾼다. 이미지 없는 도형에는 새 손 좌표 표시를 적용하지 않는다.

ART-06의 `Sprite_anchor_x`는 유한한 비음수인 선택적 원본 px다. 원본 가로 기준점이 판정 중심x에 오도록 그림을 배치하고 이 점을 축으로 반전한다. 빈칸은 기존 칸 가운데 위치를 유지한다. 질주·텔레포트·돌진 잔상도 같은 기준점을 복제하며 벨리온 발 기준 손 좌표는 바꾸지 않는다.

#### 일반 근접 적 walk1 표시

| 열 | 의미 | enemy_01 예시 |
|---|---|---|
| Sprite_path | 오른쪽 걷기 투명 시트 경로 | res://assets/art/sd/sd_bear.png |
| Sprite_layout | 한 행 오른쪽 걷기 배치 | pose |
| Sprite_cols / Sprite_rows | 가로/세로 칸 수 | 1 / 1 |
| Sprite_cell_height | 화면 한 칸 높이(px) | 111 |
| Sprite_baseline / Sprite_anchor_x | 원본 발y/몸 중심x(px) | 219 / 118 |
| Sprite_foot_y | 판정 중심 아래 발 위치(px) | 8 |
| Anim_fps | 이동 중 반복 속도 | 13 |
| Shadow_w / Shadow_h | 발밑 검정 타원 전체 크기(px) | 48 / 16 |
| Sprite_tint | 그림에만 곱하는 HTML 색 | #ffffff |

곰 원본은1848×301·6×1(칸308×301)이다. 정규화한 플레이어 방향의 |x|가 Flip_deadband를 초과할 때만 부호에 따라 반전하고, 그 외에는 직전 반전을 유지한다. 공포로 정지하면 첫 칸을 쓰고 기존 공포 색과50% 섞는다. 넉백 중에는 직전 방향을 유지한다. 사망의 actor modulate.a 흐려짐은 그대로이며 그림 색은 타원에 곱하지 않는다. 풀 활성화마다 해당 행으로 다시 설정하고 ResourceLoader 캐시로 텍스처를 공유한다. 다른 적 행의 빈 이미지 열은 기존 도형을 유지한다.

ART-04에서 본체 그림만 공통 `CharacterBodies` 계층으로 분리해 발 기준 월드 y가 큰 순서로 앞에 그린다. 물리 노드·스폰·밀기 구조는 유지한다. UI·토스트·피해 표시·공격 범위·사슬 검은 캐릭터 위의 기존 경로를 유지하고 투사체의 부모·z·삽입 순서는 바꾸지 않는다. 벨리온 원본1816×1131, 칸454×377의 투명 이미지는 mipmap·선형 필터로 표시한다. 이그리트·벨리온 텔레포트와 플레이어 질주 잔상은 생성 순간의 확대된 표시 크기를 복제하며 별도 발밑 타원은 그리지 않는다.

난도는 기존 피해 시점마다 원형 스킬 범위 안에 긴 직선 여러 개를 무작위 각도로 교차한다. 흰 중심·하늘색 가장자리의 짧은 청백색 효과다. 효과음 글자·레퍼런스 이미지 파일은 추가하지 않는다. 시각 난수는 전투 RNG와 분리한다. 최종 느낌은 직접 플레이 확인 대기다.

#### combat_presentation.csv

Id(String)·Value(String)의 두 열이다. 숫자 Id의 Value는 아래 단위로 읽고 색은 HTML로 읽는다. UTF-8 BOM·LF, 첫 열 Id. 스키마 등록은 boss_data, 잔상/스킬/토스트가 공유하는 순수 연출 데이터이며 전투 수치는 없다.

| Id | Value | 단위·의미 |
| --- | --- | --- |
| Flip_deadband | 0.3 | 정규화 방향 x 절댓값의 반전 문턱. 유한한0~1 필수. walk1·state3·dir3 옆줄 이동에 적용; 공격 방향 고정 우선 |
| Trail_life_sec | 0.3 | 초, 질주·바루카 잔상 수명 |
| Trail_interval_sec | 0.045 | 초, 플레이어 질주 잔상 시간 간격 |
| Blink_trail_count | 8 | 개/이동, 바루카 전광석화 경로 등간격 잔상 수 |
| Belion_chain_segments | 12 | 개, 벨리온 사슬 검 조각 수 |
| Belion_chain_width | 24 | px, 마름모 사슬 전체 두께. 유한한 양수 필수; 누락·빈칸·0/음수·비숫자·NaN/Inf는 데이터 오류. 빛·테두리도 비례 |
| Belion_trail_sec | 0.15 | 초, 벨리온 칼끝 궤적 수명 |
| Trail_alpha | 0.45 | 알파 0~1 |
| Slash_count | 9 | 선 개수, 연출 시작값 |
| Slash_width / Slash_core_width | 3 / 1 | px, 하늘색 외곽/흰 중심 두께 |
| Slash_sec | 0.12 | 초, 매 타 선 표시 수명 |
| Slash_outer_color / Slash_core_color | #83d9ff / #ffffff | HTML 색, 연출 시작값 |
| Toast_sec | 2 | 초, 일반 메시지 수명 |
| Toast_gap_px | 8 | px, 메시지 사이 간격 |
| Toast_max | 4 | 동시 활성 메시지 수 |

CSV Value는 String으로 읽고 각 연출 사용처에서 숫자/색으로 변환한다. 이 파일의 의미 범위·필수 Id 검증은 별도 데이터 오류 화면에 연결하지 않았으며, 지정된 정상 값 기준의 연출 데이터다. 기존 hit_fx.csv의 검증·피해·슬롯 정책은 유지한다.


### ART-08 아이스 엘프 이미지

정식 일반 적2종은 아이스 베어(근접, enemy_01)·아이스 엘프(원거리, enemy_test_ranged)다. 기존 내부Id·판정·속도·피해·사거리·발사 간격·투사체·생성 규칙은 유지한다.

| enemy.csv 열 | 아이스 엘프 예시 | 의미 |
|---|---|---|
| Name_ko / Note | 아이스 엘프 / 정식 원거리 적(ART-08) | 표시명·설명 |
| Sprite_path | res://assets/art/enemy/elf_sheet.png | res://assets/art/sd/sd_bear.png |
| Sprite_layout / Sprite_cols / Sprite_rows | walk_shoot / 4 / 2 | 1행 걷기·2행 쏘기;4열2행 필수 |
| Sprite_cell_height | 97 | 111 |
| Sprite_baseline / Sprite_anchor_x / Sprite_foot_y | 424 / 144 / 8 | 원본 발y·몸 중심x·화면 발y |
| Anim_fps | 8 | 걷기 반복 칸/초 |
| Shadow_w / Shadow_h / Sprite_tint | 36 / 13 / #d0d8f0 | 타원 화면px·그림 곱 색 |

walk_shoot는 기본1행 걷기를 Anim_fps로 반복하고 공포 정지는1번 칸이다. 발사가 가능한 사거리 안에서 Shot_interval_sec − shot_elapsed가0.3초 이하면2행1번,0.15초 이하면2번. 실제 투사체 생성 순간3번을0.1초,그다음4번을0.1초 표시한 뒤 걷기로 복귀한다. 사거리 이탈·플레이어 은신·공포는 겨누기와 발사 후 표시를 즉시 취소한다. 플레이어 방향을 정규화해 Flip_deadband 규칙으로 반전하며 넉백 방향 유지도 보존한다. 표시 타이머는 발사 타이머와 분리하며 실제 발사 시점을 바꾸지 않는다.


### ART-09 SD 포즈·코드 움직임

사용자 결정(2026-11-15): 아기자기한2D(SD·카툰) 화풍으로 전환하며 걷기 시트 대신 포즈 이미지와 코드 움직임을 사용한다. 1단계는 플레이어·이그리트·아이스 베어에 적용한다. 베르·벨리온·아이스 엘프와 판정·이동·공격·생성 규칙은 유지한다. 기존 시트 배치와 에셋도 유지한다.

| player.csv·shadow.csv·enemy.csv 열 | 의미·빈칸 | player_01 예시 | igrit 예시 | enemy_01 예시 |
|---|---|---|---|---|
| Sprite_path | 포즈 시트 경로 | res://assets/art/sd/sd_player.png | res://assets/art/sd/sd_igris.png | res://assets/art/sd/sd_bear.png |
| Sprite_layout | 1행 N열 포즈 | pose | pose | pose |
| Sprite_cols / Sprite_rows | 가로/세로 칸 수 | 2 / 1 | 2 / 1 | 1 / 1 |
| Sprite_cell_height | 화면 칸 높이px | 95 | 143 | 111 |
| Sprite_baseline / Sprite_anchor_x | 원본 발y / 몸 중심x | 187 / 68 | 279 / 125 | 219 / 118 |
| Sprite_foot_y | 화면 발y,기존 유지 | 8 | 8 | 8 |
| Shadow_w / Shadow_h | 발밑 타원 전체px,기존 유지 | 32 / 12 | 56 / 20 | 48 / 16 |
| Sprite_tint | 그림 곱 색 | 기존 기본 흰색 | 기존 기본 흰색 | #ffffff |
| Bob_px | Optional Float,상방 출렁임 화면px;빈칸0 | 3 | 4 | 3 |
| Step_hz | Optional Float,이동 sin 주기/초;빈칸0 | 4 | 3 | 3 |
| Squash | Optional Float,출렁임 비례 가로확대/세로축소 비율;빈칸0 | 0.06 | 0.05 | 0.05 |
| Tilt_deg | Optional Float,좌우 sin 기울기 도;빈칸0 | 4 | 3 | 3 |
| Breath | Optional Float,정지 세로 ±비율;빈칸0 | 0.02 | 0.02 | 0 |
| Walk_cols | Optional String,pose 앞 걷기 칸의 0기준 시작-끝(양끝 포함);빈칸은 기존 동작 | 5-12 | 빈칸 | 빈칸 |
| Walk_back_cols | Optional String,pose 뒤 걷기 범위;빈칸은 Walk_cols 사용 | 13-20 | 빈칸 | 빈칸 |
| Walk_fps | Optional Float,걷기 초당 칸 수;범위 사용 시 유한한 양수 | 12 | 빈칸 | 빈칸 |

ART-13(2026-11-16): 위 걷기3열은 player.csv·shadow.csv·enemy.csv 공통이다. pose 이동 시 반복하고 앞/뒤 전환은 시간을 유지,정지 시 기존 대기 칸과 시간0으로 돌아간다. 공격·스킬 포즈가 우선하며 잘못된 범위 형식/순서/칸 초과 또는 fps는 경고 후 기존 포즈로 대체한다. 플레이어 최신 시트는4641×221·21열1행,0~4는 기존 포즈,5~12 앞 걷기,13~20 뒤 걷기다. Sprite_cols21,Bob_px2,Step_hz1.5,Squash0.03,Tilt_deg1이며 Breath는 유지한다. 이전 표의 값은 ART-09 시점 기록이다.

새5열은 유한한 비음수이고 Squash·Breath는1 미만이다. 모두 빈칸이면 변형이 없다. 플레이어 Idle_sprite_path는 빈칸이며 pose에서 별도 대기 시트를 사용하지 않는다. 위쪽 이동(y<0,절댓값y>절댓값x,정규화 y가 Flip_deadband 문턱 초과) 중 뒷모습2열,그 외 앞모습1열이다. 좌우는 정규화 x의 기존 Flip_deadband를 적용한다. 그림자는 cast_active 시작부터 종료까지2열,그 외1열이며 기존 공격 방향 규칙을 따른다. 적은1열이다.

그림만 발 기준점 주위에서 변형한다. 이동 시 Bob_px×abs(sin),Step_hz 주기,납작/길쭉 Squash와 Tilt_deg×sin을 사용한다. 정지는1Hz 호흡으로 세로±Breath. 공격 포즈 시작 순간 방향으로4px 내딛기·짧은10% 찌그러짐을0.1초 동안 감쇠한다. 판정·발밑 타원 위치·정렬 기준은 움직이지 않는다. 잔상은 생성 순간 포즈·반전·변형을 복제하고 고정한다. 적·보스 피격은0.08초 흰색 셰이더 표시이며 원래 알파·사망 흐려짐은 유지한다.

원본 규격: sd_player282×191(칸141×191),sd_igris782×287(칸391×287),sd_bear237×222. 모두 투명. import는 밉맵 생성,표시는 선형 밉맵 필터다.


### ART-10 SD 전환2단계(현재 설정)

베르·벨리온·아이스 엘프도1행2열 pose로 전환한다. 기존 판정·피해 시점·이동·생성 규칙은 유지한다.

| 열 | charger_test(베르) 예시 | belion 예시 | enemy_test_ranged(엘프) 예시 |
|---|---|---|---|
| Sprite_path | res://assets/art/sd/sd_beru.png | res://assets/art/sd/sd_belion.png | res://assets/art/sd/sd_elf.png |
| Sprite_layout / Sprite_cols / Sprite_rows | pose / 2 / 1 | pose / 2 / 1 | pose / 2 / 1 |
| Sprite_cell_height | 144 | 158 | 118 |
| Sprite_baseline / Sprite_anchor_x | 269 / 89 | 297 / 105 | 233 / 75 |
| Sprite_foot_y | 8(유지) | 8(유지) | 8(유지) |
| Shadow_w / Shadow_h | 48 / 16 | 56 / 18 | 34 / 12 |
| Bob_px / Step_hz | 4 / 3.5 | 4 / 3 | 3 / 3.5 |
| Squash / Tilt_deg / Breath | 0.05 / 4 / 0.02 | 0.05 / 3 / 0.02 | 0.05 / 3 / 0.02 |
| Sprite_tint | 기존 기본 흰색 | 기존 기본 흰색 | #ffffff |
| Chain_hand_x / Chain_hand_y | 빈칸 | 8 / -62 | 해당 없음 |

곰 enemy_01은 Shadow_w64·Shadow_h20만 변경한다. 다른 열은 유지한다. 원본은 베르536×289(칸268×289),벨리온566×315(칸283×315),엘프394×237(칸197×237)이며 모두 투명·밉맵 import·선형 밉맵 표시다.

베르는 dash_through_active 시작부터 후딜 종료(cast_active 종료)까지2열,나머지1열이다. 반전은 돌진 방향으로 고정하고 돌진 잔상도0행2열을 복제한다. 벨리온은 준비+쓸기 cast_active 전체2열,종료 즉시1열이다. 손은 발 기준8/-62이고 왼쪽은x만 반전한다. 엘프는 발사0.3초 전부터 실제 발사 후0.15초 미만까지2열,그 외1열이다. 사거리 이탈·은신·공포는 즉시1열로 복귀하며 발사 타이머와 실제 투사체는 유지한다. 기존 walk_shoot 배치의4칸·0.1초+0.1초 연출은 레거시 지원으로 유지한다.

옛 시트는 레거시 배치 검사에서 참조 중이므로 사용자 조건에 따라 삭제하지 않는다. 실제 게임 CSV와 scripts의 옛 시트 파일 참조는 제거했으며,dir3·state3·walk1·walk_shoot 코드와 검사는 유지한다. 검사 준비에서 기존 시트를 명시적으로 사용하고 실제 SD 동작은 별도 검사한다.


### LOOK-01 설원 숲 던전(2026-11-15 사용자 결정)

SD 화풍의 눈보라 치는 설원 숲이다. snow_ground.png1254×1254 불투명 바닥을 기존 맵 전체에 원본 크기로 반복하며 밝기0.93을 곱한다. env_props.png1926×468·6열(칸321×468)은1~4열 나무·5~6열 바위다. 원본 발y464/가로160 기준,화면 높이234. 모든 환경 import는 밉맵 생성·선형 밉맵 표시다.

숲은 각 변 안쪽 띠에2겹,별도 고정 RNG로 위치·종류·반전을 정하며 내부14개 바위/작은 나무도 같은 시드로 재현한다. 충돌 없는 Node2D 장식이며 캐릭터의 CharacterBodies y-sort에 포함한다. 장식 그림자도 공용 부드러운 푸른 회색 타원이다. 기존 맵 경계·판정·이동·전투·생성 규칙은 유지한다.

화면 고정 CanvasLayer의 눈발과 가장자리 흰 안개는 UI 입력을 받지 않고 _process만 사용한다. World_tint는 맵과 월드 그림에만 곱한다. 발밑 그림자는 기존 Shadow_w/h와 위치를 유지하며 가장자리 흐린 타원으로 바꾼다. 경험치는 반지름 안에 마름모 결정을 그리고 주변 빛만 추가한다. 값·획득·합치기·흡수 규칙은 유지한다.

HUD는 위쪽 전체 폭 경험치 바·왼쪽 위 Lv N,기존 오른쪽 위 시간,플레이어 발 아래 작은 빨강 HP 바를 사용한다. 적 수·HP 문구·레벨/경험치/강화 포인트 문구·바닥 경험치 개수는 기본 숨김이다. 강화는 기존 스킬 + 표시를 사용한다. F3 누를 때 기존 텍스트 HUD·격자·맵 테두리를 함께 토글하며 키 반복 입력은 무시한다. 스킬·보유 그림자·토스트 배치는 유지하고 남색 반투명 배경·흰 테두리로 바꾼다.

아래 값은 확정 밸런스가 아닌 연출 시작값이다. 기존 Id(String)·Value(String)의 새 행이며 색은 HTML,수치는 사용처에서 변환한다. 물리·전투 수치가 아니다.

| combat_presentation.csv Id | Value 예시 | 의미 |
|---|---|---|
| Snow_alpha | 0.65 | 눈발 알파 |
| Fog_width_ratio | 0.18 | 화면 짧은 변 대비 안개 폭 비율 |
| Xp_glow_layers | 3 | 경험치 빛 겹 수 |
| Xp_glow_radius | 0.25 | 경험치 반지름 대비 빛 겹 간격 |
| Ground_brightness | 0.93 | 바닥 그림 곱 밝기 |
| Forest_band_px | 160 | 각 변 안쪽 숲 띠px |
| Tree_spacing_px | 90 | 숲 두 겹의 간격px |
| Inner_props | 14 | 맵 내부 장식 수 |
| Forest_seed | 11015 | 장식/날씨 전용 고정 시드;전투 RNG와 분리 |
| Tree_jitter_px | 12 | 띠 안 위치 흔들림px |
| Inner_prop_scale | 0.55 | 내부 작은 나무 배율 |
| Prop_cell_height | 234 | 원본468px 칸의 화면 높이 |
| Prop_shadow_w | 70 | 장식 타원 전체 너비px |
| Prop_shadow_h | 24 | 장식 타원 전체 높이px |
| Snow_count | 160 | 화면 고정 눈발 수 |
| Snow_speed | 260 | 눈발 화면px/초 |
| Snow_angle_deg | 20 | 수직에서 오른쪽으로 기울기 도 |
| Snow_size_px | 2 | 눈발 굵기px |
| Fog_strength | 0.45 | 가장자리 흰 눈안개 알파 |
| World_tint | #eef2fa | 월드 그림 전체 곱 색;UI에는 미적용 |
| Shadow_color | #46506e | 발밑 타원 RGB |
| Shadow_alpha | 0.45 | 부드러운 타원 중심 합성 알파 |
| Shadow_softness | 0.35 | 타원 가장자리 흐림 폭 비율 |
| Shadow_layers | 8 | 겹친 타원 수 |
| Xp_color | #a68cff | 경험치 결정/상단 경험치 바 색 |
| Xp_glow_alpha | 0.18 | 결정 주변 빛 알파 |
| Hud_background | #101d35dd | 스킬·보유 그림자·토스트 남색 배경 |
| Hud_border | #ffffff | 위 UI의 테두리 색 |
| Hp_color | #e84d5b | 발밑 HP 채움 색 |
| Hp_background | #182238 | HP 바 어두운 테두리 색 |


### ART-11 플레이어 스킬 포즈·표시

플레이어 시트는1105×221·5열1행(칸221×221),앞·뒤·질주·난도·피어 순서다. player.csv의 Sprite_cols5,Sprite_cell_height110,Sprite_baseline202,Sprite_anchor_x101만 바꾸고 나머지는 유지한다. 용 머리는투명496×640이다. 두 이미지 모두 밉맵·선형 밉맵 표시다.

포즈 우선순위는 fear_cast_remaining>0(5열) > dash_remaining>0(3열·돌진 방향 반전 고정) > 난도active(4열) > 기존 위 이동2열/그 외1열이다. 스킬 중 걷기 출렁임 대신 작은 흔들림,난도 빠른 좌우 기울기,피어 작은 상방 떠오름을 사용한다. 이동/판정/시전/쿨타임은 유지한다. 질주 잔상은 포즈·반전·그림 변형을 그대로 복제한다.

기본 공격은 같은 판정 삼각형 안의 초승달 궤적(흰 중심·하늘빛)을 Hit_effect_sec 동안 감쇠하고 타격마다 그림만2px 내딛는다. 원래 삼각형 좌표·Timer 수명은 유지하며 삼각형 그림만 F3에서 표시한다. 난도는 기존 무작위 선 위치/개수를 유지하고 끝이 가늘고 가운데가 굵은 빛줄기로 바꾼다. 매 틱 중심 흰 번쩍임,마지막 틱에3px·0.08초 흔들림을 추가한다.

피어는 Cast_sec 동안 머리가0.6→1.0 크기로 상승·나타남/소멸한다. 캐릭터 표시의 첫 자식으로 그려 플레이어 몸보다 뒤에 놓는다. 시작 순간 판정 중심에 고정한 보라 충격파는 동일 Range까지 퍼지고 붉은 할퀴기6개와 검은 박쥐20개를 그린다. 시작 보라 번쩍임0.15초와5px·0.15초 흔들림을 더한다. 은신은 알파0.45와 느린 보라 일렁임이다.

흔들림은 후처리 화면 샘플만 이동한다. Camera2D·맵·플레이어 위치와 화면 좌표 역변환은 건드리지 않아 생성/대상 검색/판정에 영향을 주지 않는다. Shake_enabled0이면 화면 이동이 즉시0이며 보라 번쩍임은 유지한다. 모든 추가 수치는 연출 시작값이며 전투 CSV와 독립이다. 기존 Slash_width/Slash_core_width·Slash_outer_color/Slash_core_color와 선 생성 RNG 구조는 유지한다.

| combat_presentation.csv Id | Value 예시 | 의미 |
|---|---|---|
| Shake_enabled | 1 | 0/1로 렌더링 흔들림 끔/켬 |
| Shake_px | 3 | 난도 마지막 틱 흔들림 화면px |
| Slash_shake_sec | 0.08 | 난도 흔들림 초 |
| Fear_shake_px | 5 | 피어 시작 흔들림 화면px |
| Fear_shake_sec | 0.15 | 피어 흔들림 초 |
| Shake_hz | 38 | 흔들림 주기/초 |
| Fear_head_px | 260 | 용 머리 최대 화면 높이px |
| Fear_head_start_scale | 0.6 | 머리 시작 크기 비율 |
| Fear_head_rise_px | 30 | 솟아오르는 화면px |
| Fear_flash_sec | 0.15 | 시작 화면 보라 번쩍임 초 |
| Fear_flash_alpha | 0.18 | 보라 번쩍임 최대알파 |
| Fear_color | #a34dff | 충격파/화면/은신 보라색 |
| Fear_claw_color | #e83948 | 할퀴기 색 |
| Fear_claw_count | 6 | 방사형 할퀴기 수(시작값6,요청범위5~7) |
| Fear_claw_sec | 0.12 | 할퀴기 초 |
| Fear_claw_width | 3 | 할퀴기 굵기px |
| Fear_bat_count | 20 | 박쥐 수 |
| Fear_bat_px | 6 | 박쥐 크기px |
| Slash_tick_flash_sec | 0.05 | 난도 타격 중심 흰 번쩍임 초 |
| Slash_tick_flash_px | 18 | 타격 번쩍임 반경px |
| Slash_tick_flash_alpha | 0.8 | 타격 번쩍임 알파 |
| Basic_step_px | 2 | 기본 타격마다 그림 내딛기px |
| Basic_step_sec | 0.1 | 내딛기 감쇠 초 |
| Basic_core_width | 1.5 | 기본 베기 흰 중심 굵기px |
| Basic_glow_width | 5 | 기본 베기 빛 굵기px |
| Basic_core_color | #ffffff | 기본 베기 중심색 |
| Basic_glow_color | #83d9ff | 기본 베기 빛색 |
| Slash_pose_hz | 12 | 난도 포즈 기울기 주기/초 |
| Slash_pose_tilt_deg | 5 | 난도 기울기 도 |
| Fear_pose_float_px | 4 | 피어 포즈 떠오름px |
| Skill_pose_sway_deg | 1 | 기타 스킬 포즈 작은 기울기 도 |
| Stealth_alpha | 0.45 | 은신 표시 알파 |
| Stealth_wave_hz | 0.6 | 은신 일렁임 주기/초 |
| Stealth_wave_strength | 0.15 | 은신 보라 곱 색 비율 |

## 승인·변경 이력

- 2026-11-11 FX-IMPL-01: 사용자 요청으로 불꽃 히트 FX1종과 켬/끔 성능 비교를 진행한다. 적용 범위·시작값·단일 일괄 노드/오래된 슬롯 재사용은 제안이며 시스템 10 전체 확정이 아니다. 2.5D 항목은 후보만 추가한다.

- 2026-11-11 FX-IMPL-01 추가 단계(B): 발사체와 구분하도록 빨강·크기 확대·0.25초를 사용자 결정으로 반영했다. 색 #e81818/#ff6a6a·반경28/중심7은 제안·검증용이며 Enabled1/상한200·도형/풀/피해 연결은 유지한다. 켬/끔 물리 측정을 재실행하며 화면 가독성/렉은 직접 확인 전이다.

- 2026-11-11: 사용자 원문 "승인"으로 FX-IMPL-01·추가 단계 B 종합 승인. 개별 결과 미기록, 확정/제안/미정 구분 유지.

- 2026-11-12 DOC-SYNC-02: 시스템8에서 이미 구현된 토스트 패널·진행 시간·그림자 표시·UI75%·플레이어 파란 히트 아이콘을 현재 구현 상태로 동기화한다. 과거 FX 이력은 유지하며 시스템9 정식 UI와 시스템10 전체 기획은 미정이다.

- 2026-11-13 S8-IMPL-03-B: 공통 토스트 쌓기·정지 중 페이드·완료 위 표시, 공유 잔상과 난도 청백색 교차선의 현재 상태 및 연출 CSV를 기록했다. 직접 플레이 미확인.

- 2026-11-14 S8-IMPL-03-C: 토스트 폭533·문구 자동 높이·실제 높이 쌓기와 전광석화 이동당 등간격 잔상8개를 반영한다. 글자·여백·잔상 수명·투명도 및 플레이어 질주 시간 간격은 유지한다.
- 2026-11-14 ART-01: 플레이어 걷기 시트를 데이터로 연결하고 발밑 그림자와 현재 칸·반전을 보존하는 질주 잔상을 적용한다. mipmap·선형 mipmap 필터를 사용하며 다른 대상의 표시는 바꾸지 않는다. 직접 플레이 확인 전이다.
- 2026-11-14 ART-02: 교체된1328×1167 플레이어 시트를 재import하고 이그리트1920×1260 state3 시트를 연결한다. 본체 그림자·포즈 잔상은 공용 표시 부품을 쓰며 베르 도형은 유지한다. 직접 플레이 확인 전이다.
- 2026-11-14 ART-03: 플레이어 dir3 표시를1488×1140 이동·대기 시트로 분리하고 상태별12/6fps와 높이87·기준선368을 적용한다. 질주 잔상은 이동 시트 포즈를 유지하며 이그리트 등 다른 대상은 변경하지 않는다. 직접 플레이 확인 전이다.
- 2026-11-15 S7-IMPL-04: 벨리온의 준비 발광·판정과 같은 각도/거리의 사슬 검12마디·칼끝0.15초 잔상·피격 파편과 도형 텔레포트 잔상을 추가한다. 최종 색·형태·가독성은 직접 플레이 확인 전이다.
- 2026-11-15 ART-04: 그림자 확대·벨리온1816×1131 시트·발밑 타원 데이터·플레이어/그림자/일반 적/보스 본체 y 정렬을 연결한다. 공격 표시·사슬 검·UI와 투사체 경로는 유지하고 질주/텔레포트 잔상은 포즈 크기를 복제한다. 직접 플레이 확인 전이다.
- 2026-11-15 S7-FIX-04: 손 좌표15/-95 기준 준비 빛·높이가 내려오는 곡선 사슬·8px 마름모 조각과 공격1/2/3/4 칸 시간을 맞춘다. 사용자 추가 답변에 따라 고정 방향은 적용하지 않고 기존 피해 결과·시점·번갈아 방향을 보존한다. 궤적·파편 값은 유지하며 직접 플레이 확인 전이다.
- 2026-11-15 S7-FIX-05: 사용자 확정으로 사거리450·사슬 두께24px(기존 대비1.5배·3배)를 적용한다. 두께를 Belion_chain_width CSV 행으로 읽고 마름모·빛·테두리를 비례 확대한다. 손·칸·방향·나머지 전투 수치는 유지하며 직접 플레이 확인 전이다.
- 2026-11-15 ART-05: 베르1928×1170 state3·높이180·기준선376·타원52×18을 연결한다. 사용자 추가 결정에 따라 준비1번 없이 즉시 돌진2→3·후딜4로 표시하며 포즈/반전 잔상을 연결한다. 기존 전투·돌진·타이밍·공용 잔상 값은 유지한다. 직접 플레이 확인 전이다.
- 2026-11-15 ART-06: 공용 가로 기준점과 아이스 베어 walk1·tint·공포 표시·풀 재설정을 추가한다. Icon 오류 검사는 같은 프로세스의 기존 네 조건으로 전환하고 사용하지 않는 하위 프로브를 삭제한다. 종료 크래시는 별도 실행 파일 직접 검증 대상으로 기록한다. 직접 화면 확인 전이다.

- 2026-11-15 ART-07: 베어6칸·13fps·높이72로 교체하고 이동 좌우 반전에 Flip_deadband(0.3)를 적용한다. 정규화 x 절댓값이 문턱을 초과할 때만 변경하며 공격 방향 고정과 잔상 스냅샷은 유지한다. 필수 행의 누락·빈칸·비숫자·비유한·0~1 밖은 데이터 오류다. 기존 시트는 다른 참조가 없어 삭제한다. 직접 플레이 확인 전이다.

- 2026-11-15 ART-08: 정식 일반 적2종을 아이스 베어(근접)·아이스 엘프(원거리)로 기록하고 elf_sheet walk_shoot 표시를 연결한다. 기존 발사·판정·이동·생성 규칙과 내부Id는 유지한다. 직접 플레이 확인 전이다.

- 2026-11-15 ART-09: 사용자 결정으로 SD·카툰2D와 포즈+코드 움직임으로 전환한다. 1단계 플레이어·이그리트·곰만 pose로 교체하고 새5열·피격 표시·잔상 변형 복제를 적용한다. 전투·생성 규칙 및 다른3개 캐릭터는 유지한다. 직접 플레이 확인 전이다.

- 2026-11-15 ART-10: 베르·벨리온·아이스 엘프를SD pose로 전환하고 곰 타원64×20,벨리온 손8/-62를 적용한다. 베르 돌진~후딜·벨리온 cast·엘프 발사 전0.3초~후0.15초 포즈를 사용하며 전투 규칙은 유지한다. 옛 시트는 레거시 검사 참조가 남아 사용자 조건대로 보존한다. 직접 플레이 확인 전이다.

- 2026-11-15 LOOK-01: 사용자 결정으로SD 설원 숲·눈보라 배경과 연출 키,부드러운 그림자·경험치 결정·정리된 HUD/F3 디버그를 적용한다. 기존 물리·전투·생성·획득 규칙은 유지한다. 직접 화면 확인 전이다.

- 2026-11-15 ART-11: 플레이어5포즈·기본 초승달/그림 내딛기·난도 빛줄기/타격 번쩍임·피어 머리/충격파/할퀴기/박쥐·은신 일렁임과 끌 수 있는 렌더링 흔들림을 추가한다. 기존 판정·피해·시점·쿨타임·이동은 유지한다. 직접 화면 확인 전이다.

## FX-02 카툰 스킬 연출 — combat_presentation.csv (2026-11-16)

판정/피해/시점/범위/쿨타임/이동/전투 RNG는 유지한다. 시각 난수는 SkillManager.visual_rng만 사용한다. Slash_count·Slash_sec는 이전 이력용으로 남기고 현재 칼빛에는 새 키를 사용한다. Trail_* 공통값은 그림자/바루카에 유지하며 플레이어 간격/색만 Dash_*를 쓴다. Shake_enabled=0은 화면 오프셋만0으로 하며 다른 FX는 유지한다.

| Id(키) | Value 예시 | 의미 |
|---|---|---|
| Fx_outline_color | #16265a | 공통: HTML 색 |
| Fx_core_ratio | 0.4 | 공통: 흰 중심 폭 / 색 칼빛 폭 |
| Slash_lines_per_tick | 4 | 난도: 매 타격 칼빛 수 |
| Slash_life_sec | 0.25 | 난도: 칼빛 수명 초 |
| Slash_length_mult | 1.5 | 난도: 원 안 현 길이의 표시 배수 |
| Slash_fx_width | 9 | 난도: 칼빛 최대 폭 px |
| Slash_outline_px | 4 | 난도: 남색 외곽 폭 px |
| Slash_glow_mult | 2.6 | 난도: 바깥 빛 폭 / 칼빛 폭 |
| Slash_glow_color | #5ad4ff | 난도: HTML 색 |
| Slash_glow_alpha | 0.3 | 난도: 불투명도 |
| Slash_draw_sec | 0.03 | 난도: 한 끝에서 등장하는 시간 초 |
| Slash_hold_sec | 0.04 | 난도: 등장 후 유지 초; 이후 수명 끝까지 폭 감소 |
| Slash_star_max | 4 | 난도: 실제 피해 적 중 별 표시 최대 수 |
| Slash_star_sec | 0.12 | 난도: 시간/간격 초 |
| Slash_star_px | 12 | 난도: 화면 px |
| Slash_star_inner_ratio | 0.25 | 난도: 비율 |
| Slash_dim_alpha | 0.12 | 난도: 활성 중 남색 화면 농도 |
| Slash_dim_in_sec | 0.05 | 난도: 시간/간격 초 |
| Slash_dim_out_sec | 0.15 | 난도: 시간/간격 초 |
| Slash_range_dashes | 48 | 난도: 연출 조절값 |
| Slash_range_width | 2 | 난도: 폭 px |
| Slash_range_alpha | 0.35 | 난도: 불투명도 |
| Slash_range_color | #5ad4ff | 난도: HTML 색 |
| Slash_finish_width | 16 | 난도: 폭 px |
| Slash_finish_length_mult | 1.8 | 난도: 표시 배수 |
| Slash_finish_flash | 0.35 | 난도: 마지막 흰 화면 번쩍임 농도 |
| Slash_finish_flash_sec | 0.05 | 난도: 시간/간격 초 |
| Shake_px | 5 | 난도: 난도 마지막 흔들림 px; Shake_enabled와 별도 |
| Dash_trail_interval_sec | 0.02 | 질주: 플레이어만 사용하는 잔상 간격 초 |
| Dash_trail_color | #8a6bff | 질주: HTML 색 |
| Dash_trail_back_alpha_ratio | 0.25 | 질주: 맨 뒤 잔상의 Trail_alpha 대비 상한 비율 |
| Dash_speedline_count | 9 | 질주: 생성 개수 |
| Dash_speedline_sec | 0.2 | 질주: 시간/간격 초 |
| Dash_speedline_width | 3 | 질주: 폭 px |
| Dash_speedline_spread_px | 32 | 질주: 화면 px |
| Dash_line_min_ratio | 0.4 | 질주: 비율 |
| Dash_line_max_ratio | 0.8 | 질주: 비율 |
| Dash_stretch_x | 1.25 | 질주: 진행축 그림 배율 |
| Dash_stretch_y | 0.9 | 질주: 진행축 수직 방향 그림 배율 |
| Dash_land_sec | 0.08 | 질주: 착지 반대 눌림 복귀 초 |
| Dash_start_puffs | 5 | 질주: 연출 조절값 |
| Dash_end_puffs | 3 | 질주: 연출 조절값 |
| Dash_puff_sec | 0.25 | 질주: 시간/간격 초 |
| Dash_puff_spread_px | 14 | 질주: 화면 px |
| Dash_puff_start_px | 3 | 질주: 화면 px |
| Dash_puff_end_px | 12 | 질주: 화면 px |
| Dash_puff_color | #dbe7ff | 질주: HTML 색 |
| Dash_puff_core_ratio | 0.65 | 질주: 비율 |
| Dash_shake_px | 2 | 질주: 화면 px |
| Dash_shake_sec | 0.06 | 질주: 시간/간격 초 |
| Fear_color | #e8283c | 피어: HTML 색 |
| Fear_outline_color | #3c000f | 피어: HTML 색 |
| Fear_wave_count | 3 | 피어: 생성 개수 |
| Fear_wave_delay_sec | 0.08 | 피어: 시간/간격 초 |
| Fear_wave_max_px | 900 | 피어: 표시 파장 최대 px; 판정 Range와 별개 |
| Fear_wave_start_width | 22 | 피어: 폭 px |
| Fear_wave_end_width | 4 | 피어: 폭 px |
| Fear_wave_y_scale | 0.62 | 피어: 파장 원근 세로 배율 |
| Fear_range_alpha | 0.18 | 피어: 불투명도 |
| Fear_range_width | 6 | 피어: 실제 판정 Range 링 폭 px |
| Fear_flash_alpha | 0.25 | 피어: 불투명도 |
| Fear_flash_sec | 0.15 | 피어: 시간/간격 초 |
| Fear_vignette_alpha | 0.6 | 피어: 불투명도 |
| Fear_vignette_tail_sec | 0.6 | 피어: Cast_sec 뒤 비네트 꼬리 수명 초 |
| Fear_vignette_width | 0.4 | 피어: 정규화 화면 반경 기준 가장자리 그라데이션 폭(px 아님) |
| Fear_claw_count | 8 | 피어: 생성 개수 |
| Fear_claw_width | 10 | 피어: 폭 px |
| Fear_claw_color | #e8283c | 피어: HTML 색 |
| Fear_claw_jitter | 0.1 | 피어: 방사 방향 시각 난수 편차 라디안 |
| Fear_claw_start_ratio | 0.15 | 피어: 비율 |
| Fear_claw_curve | 0.15 | 피어: 할퀴기 시작/끝 방향 차 라디안 |
| Fear_bat_count | 40 | 피어: 생성 개수 |
| Fear_bat_min_px | 8 | 피어: 화면 px |
| Fear_bat_max_px | 14 | 피어: 화면 px |
| Fear_bat_wing_min | 0.5 | 피어: 날갯짓 세로 배율 최솟값; 최댓값1 |
| Fear_bat_hz | 12 | 피어: 초당 주기 |
| Fear_bat_start_ratio | 0.8 | 피어: 박쥐 초기 반경 상한 / 실제 판정 Range |
| Fear_bat_travel_px | 1100 | 피어: 화면 px |
| Fear_bat_tail_sec | 0.6 | 피어: Cast_sec 뒤 박쥐 꼬리 수명 초 |
| Fear_bat_eye_px | 1 | 피어: 화면 px |
| Fear_shake_px | 8 | 피어: 화면 px |
| Fear_shake_sec | 0.25 | 피어: 시간/간격 초 |

## FX-03 그림자 병사 아우라 — combat_presentation.csv (2026-11-16)

그림자 병사만 적용하며 잔상에는 복제하지 않는다. 알파 윤곽 셰이더는 현재 시트 칸 안에서만 샘플링하고 원래 그림 안쪽은 칠하지 않는다. 아우라는 그림 뒤의 별도 재질이며 기존 틴트/피격 셰이더를 변경하지 않는다. 불씨는 월드 좌표,줄기는 몸 로컬 좌표. 소환/텔레포트 연기는 몸 높이에서만 만들며 별도의 발밑 연기는 없다. 고정 풀 재사용·일시정지 정지·배우 제거 시 정리. 전투 RNG와 별도의 visual_rng 사용.

| Id(키) | Value 예시 | 의미 |
|---|---|---|
| Shadow_aura_enabled | 1 | 공통: 0이면 관련 노드/풀/그리기를 만들지 않음; 시작 시 적용 |
| Aura_px | 6 | 아우라: 원본 알파 외곽 확장 화면px |
| Aura_flame_px | 14 | 아우라: 위쪽 불꽃 확장 화면px |
| Aura_flicker_hz | 2.5 | 아우라: 일시정지 가능한 시각 시계의 초당 노이즈 흐름 |
| Aura_color | #7a5cff | 아우라: HTML 색 |
| Aura_core_color | #c9b8ff | 아우라: HTML 색 |
| Aura_alpha | 0.75 | 아우라: 평시 최대 알파 |
| Aura_attack_boost | 1.3 | 아우라: cast_active 중 최대 알파 배수,상한1 |
| Aura_attack_flame_mult | 1.4 | 아우라: cast_active 중 불꽃 길이 배수 |
| Ember_rate | 6 | 불씨: 그림자당 초당 생성 수; 풀은 ceil(rate×life)+1 |
| Ember_life_sec | 0.8 | 불씨: 수명 초 |
| Ember_rise_px | 40 | 불씨: 월드 좌표 불씨의 위쪽 이동 px/초 |
| Ember_height_min | 0.3 | 불씨: 발~몸높이 중 최소 생성 비율 |
| Ember_height_max | 1 | 불씨: 발~몸높이 중 최대 생성 비율 |
| Ember_spread_ratio | 0.25 | 불씨: 몸 표시 폭 대비 좌우 생성 반폭 |
| Ember_sway_px | 10 | 불씨: 좌우 흔들림 최대px |
| Ember_sway_hz | 1.5 | 불씨: 초당 주기 |
| Ember_min_px | 2 | 불씨: 화면px |
| Ember_max_px | 4 | 불씨: 화면px |
| Ember_color | #a99bff | 불씨: HTML 색 |
| Ember_core_ratio | 0.45 | 불씨: 비율 |
| Wisp_count | 2 | 줄기: 그림자당 고정 로컬 줄기 수 |
| Wisp_length_px | 50 | 줄기: 화면px |
| Wisp_life_sec | 1 | 줄기: 수명 초 |
| Wisp_height_ratio | 0.75 | 줄기: 어깨 시작 높이 / 몸 높이 |
| Wisp_spread_ratio | 0.15 | 줄기: 어깨 시작 좌우 반폭 / 몸 표시 폭 |
| Wisp_steps | 16 | 줄기: 고정 선 분할 수 |
| Wisp_turns | 1.5 | 줄기: 줄기 길이 내 굽이 수 |
| Wisp_flow_hz | 1 | 줄기: 초당 주기 |
| Wisp_sway_px | 6 | 줄기: 화면px |
| Wisp_start_width | 3 | 줄기: 폭px |
| Wisp_end_width | 1 | 줄기: 폭px |
| Wisp_color | #1a1240 | 줄기: HTML 색 |
| Wisp_alpha | 0.85 | 줄기: 줄기 시작 알파; 시간/길이를 따라0으로 감소 |
| Burst_puffs | 12 | 몸 높이 소환/텔레포트 연기: 사건당 고정 풀 개수; 중첩 사건은 같은 풀 재사용 |
| Burst_sec | 0.35 | 몸 높이 소환/텔레포트 연기: 수명 초 |
| Burst_height_ratio | 0.6 | 몸 높이 소환/텔레포트 연기: 연기 중심 높이 / 몸 높이; 발밑 연기 없음 |
| Burst_min_px | 6 | 몸 높이 소환/텔레포트 연기: 화면px |
| Burst_max_px | 12 | 몸 높이 소환/텔레포트 연기: 화면px |
| Burst_spread_px | 30 | 몸 높이 소환/텔레포트 연기: 화면px |
| Burst_above_foot_px | 8 | 몸 높이 소환/텔레포트 연기: 퍼짐 중심의 발 위 최소 간격px |
| Burst_outline_px | 2 | 몸 높이 소환/텔레포트 연기: 화면px |
| Burst_outline_color | #1a1240 | 몸 높이 소환/텔레포트 연기: HTML 색 |
| Burst_color | #46378f | 몸 높이 소환/텔레포트 연기: HTML 색 |
| Aura_noise_scale | 0.09 | 아우라: 화면 좌표에 곱하는 노이즈 입도 |
| Aura_core_spread_ratio | 0.5 | 아우라: 안쪽 색의 윤곽 반경 / Aura_px |
| Aura_core_flame_ratio | 0.3 | 아우라: 안쪽 색의 불꽃 길이 / 바깥 불꽃 길이 |


## 2026-11-16 FX-04 + ART-15 — 공격 FX·피해 숫자·준비/마무리 포즈

그림자 공격은 실제 피해/돌진/쓸기 사건에서만 표시를 생성한다. 벨리온 사슬·준비 빛과 기존 전투 수치/번갈아 방향은 유지한다. 일반 공격은 한 공격 안의 타격 순서로 베기/찌르기를 고르고, 플레이어/그림자 타격 정지는 그림의 칸·변형만 멈춘다. 효과·숫자는 고정 풀을 재사용하고 일시정지 시 멈추며 제거 시 정리한다. 양수 피해가 수락되면 실제 HP 감소량을 월드 숫자로 한 번 표시한다(과잉 피해는 남은 HP). 시각 난수는 전투 RNG와 분리한다.

| 파일·열 | 형식 | 예시 | 설명 |
|---|---|---|---|
| shadow.csv Prep_col | Optional Int | igrit=10, belion=2 | pose 준비 칸(0기준). 이그리트는 Hit_time_sec 전, 벨리온은 Windup_sec 동안. 빈칸이면 기존 공격 칸1 |
| shadow.csv Finish_col | Optional Int | charger_test=2 | pose 돌진 후 cast_active 후딜 칸(0기준). 빈칸이면 기존 공격 칸1 |

새 시트는 플레이어25칸(23 베기/24 찌르기), 이그리트11칸(10 준비), 벨리온/베르3칸(2 준비/마무리)을 사용한다. 화면 높이는110/165/158/144, baseline202/323/297/269, anchor_x101/155/255/224이며 기존 손 좌표·발 위치·걷기 칸 범위는 유지한다. 새 포즈에서도 반전·아우라·잔상 스냅샷이 같은 칸과 변형을 따른다.

combat_presentation.csv 추가 키(모든 단위는 표시 전용):

| 키 | 예시 | 설명 |
|---|---|---|
| Shadow_fx_outline | #1a1240 | 그림자 팔레트: HTML 색(숫자는 출처/처치 색, 잔상은 기존 색에 곱함) |
| Player_fx_outline | #16265a | 플레이어 팔레트: HTML 색(숫자는 출처/처치 색, 잔상은 기존 색에 곱함) |
| Shadow_fx_color | #7a5cff | 그림자 팔레트: HTML 색(숫자는 출처/처치 색, 잔상은 기존 색에 곱함) |
| Player_fx_color | #5ad4ff | 플레이어 팔레트: HTML 색(숫자는 출처/처치 색, 잔상은 기존 색에 곱함) |
| Shadow_fx_core | #ece6ff | 그림자 팔레트: HTML 색(숫자는 출처/처치 색, 잔상은 기존 색에 곱함) |
| Player_fx_core | #ffffff | 플레이어 팔레트: HTML 색(숫자는 출처/처치 색, 잔상은 기존 색에 곱함) |
| Belion_burst_sec | 0.3 | 벨리온: 시간초(수명/유지/그리기/소멸) |
| Belion_shard_count | 7 | 벨리온: 생성/표시 개수 |
| Belion_shard_min_px | 18 | 벨리온: 화면px(폭·길이·크기·간격); 판정에는 사용하지 않음 |
| Belion_shard_max_px | 34 | 벨리온: 화면px(폭·길이·크기·간격); 판정에는 사용하지 않음 |
| Belion_stone_count | 5 | 벨리온: 생성/표시 개수 |
| Belion_stone_px | 5 | 벨리온: 화면px(폭·길이·크기·간격); 판정에는 사용하지 않음 |
| Belion_stone_gravity | 350 | 벨리온: 하향 가속도px/초² |
| Belion_star_px | 12 | 벨리온: 화면px(폭·길이·크기·간격); 판정에는 사용하지 않음 |
| Beru_mark_width | 9 | 베르: 화면px(폭·길이·크기·간격); 판정에는 사용하지 않음 |
| Belion_stone_color | #5f6480 | 벨리온: HTML 색(숫자는 출처/처치 색, 잔상은 기존 색에 곱함) |
| Shadow_spark_width | 3 | 일반 공격: 화면px(폭·길이·크기·간격); 판정에는 사용하지 않음 |
| Damage_number_max | 60 | 월드 숫자 고정 풀 개수; 초과 시 가장 오래된 슬롯 재사용 |
| Damage_number_jitter_px | 8 | 월드 가로 위치 무작위 ±px; 전투 RNG와 별도 |
| Damage_number_head_gap | 6 | 스프라이트 표시 영역 상단과 숫자 사이 px; 도형은 몸 반지름 기준 |
| Damage_number_kill_color | #ffd84a | 피해 숫자: HTML 색(숫자는 출처/처치 색, 잔상은 기존 색에 곱함) |
| Damage_number_shadow_color | #d6c8ff | 피해 숫자: HTML 색(숫자는 출처/처치 색, 잔상은 기존 색에 곱함) |
| Damage_number_player_color | #ffffff | 피해 숫자: HTML 색(숫자는 출처/처치 색, 잔상은 기존 색에 곱함) |
| Damage_number_sec | 0.55 | 피해 숫자: 시간초(수명/유지/그리기/소멸) |
| Damage_number_size | 18 | 기본 폰트 크기px |
| Damage_number_pop_scale | 1.4 | 생성 순간 배율 →1 |
| Damage_number_pop_sec | 0.08 | 팝 배율 복귀 시간초 |
| Damage_number_kill_scale | 1.2 | 처치 숫자 추가 배율 |
| Damage_number_rise_px | 28 | 수명 동안 위로 이동px |
| Damage_number_outline_px | 3 | 숫자 남색 외곽선px |
| Damage_number_bold_px | 0.5 | 기본 폰트 숫자를 겹쳐 굵게 그리는 가로 간격px |
| Shadow_arc_pool | 4 | 그림자당 고정 초승달 슬롯 개수 |
| Belion_band_pool | 64 | 벨리온 고정 각도 띠 슬롯 개수 |
| Shadow_impact_pool_max | 512 | 그림자당 고정 별/불티/파편 슬롯 개수; 초과 시 순환 재사용 |
| Igris_diagonal_tilt_deg | -25 | 대각 궤적 공격 방향 추가 각도° |
| Igris_radius_ratio | 0.85 | 공격 Range 대비 쓸기 궤적 반경 |
| Igris_diagonal_radius_mult | 0.75 | 대각 궤적 반경/쓸기 반경 |
| Igris_diagonal_arc_mult | 0.65 | 대각 궤적 각도 폭/기본 Arc_deg |
| Igris_arc_width | 36 | 이그리트: 화면px(폭·길이·크기·간격); 판정에는 사용하지 않음 |
| Igris_diagonal_width_mult | 0.8 | 대각 궤적 굵기/쓸기 굵기 |
| Beru_mark_length | 44 | 베르: 화면px(폭·길이·크기·간격); 판정에는 사용하지 않음 |
| Beru_mark_sec | 0.2 | 베르: 시간초(수명/유지/그리기/소멸) |
| Igris_star_max | 4 | 실제로 피해를 받은 적 중 별을 표시할 최대 마릿수/타격 |
| Igris_star_px | 18 | 이그리트: 화면px(폭·길이·크기·간격); 판정에는 사용하지 않음 |
| Igris_star_sec | 0.12 | 이그리트: 시간초(수명/유지/그리기/소멸) |
| Igris_spark_count | 6 | 이그리트: 생성/표시 개수 |
| Shadow_spark_px | 8 | 일반 공격: 화면px(폭·길이·크기·간격); 판정에는 사용하지 않음 |
| Shadow_spark_speed | 70 | 일반 공격: 속도px/초 |
| Belion_stripe_deg | 6 | 실제 쓸기 각도를 분할하는 줄무늬 각도°; 기존 번갈아 방향 보존 |
| Igris_arc_life_sec | 0.18 | 이그리트: 시간초(수명/유지/그리기/소멸) |
| Belion_band_sec | 0.25 | 벨리온: 시간초(수명/유지/그리기/소멸) |
| Beru_claw_life_sec | 0.3 | 베르: 시간초(수명/유지/그리기/소멸) |
| Igris_arc_draw_sec | 0.05 | 이그리트: 시간초(수명/유지/그리기/소멸) |
| Shadow_fx_y_scale | 0.62 | 그림자 궤적 바닥 원근의 세로 비율 |
| Beru_claw_gap | 14 | 실제 돌진 시작점→현재 위치에 평행한 발톱3줄 간격px |
| Beru_claw_width | 9 | 베르: 화면px(폭·길이·크기·간격); 판정에는 사용하지 않음 |
| Belion_band_inner_ratio | 0.78 | 띠 안쪽 반경/판정 Range; 바깥 반경은 Range |
| Belion_band_dark | #3c1470 | 벨리온: HTML 색(숫자는 출처/처치 색, 잔상은 기존 색에 곱함) |
| Belion_band_light | #9646ff | 벨리온: HTML 색(숫자는 출처/처치 색, 잔상은 기존 색에 곱함) |
| Belion_band_outline | #1e0832 | 벨리온: HTML 색(숫자는 출처/처치 색, 잔상은 기존 색에 곱함) |
| Belion_tip_width | 8 | 벨리온: 화면px(폭·길이·크기·간격); 판정에는 사용하지 않음 |
| Belion_prep_star_px | 10 | 벨리온: 화면px(폭·길이·크기·간격); 판정에는 사용하지 않음 |
| Belion_prep_star_hz | 8 | 벨리온: 점멸 주파수Hz |
| Basic_fx_enabled | 1 | 1=공격 내 홀수 베기·짝수 찌르기, 0=이전 초승달; 판정 삼각형/Timer 수명 유지 |
| Basic_thrust_length_mult | 1.2 | 찌르기 표시 길이/판정 Range |
| Basic_draw_sec | 0.04 | 베기/찌르기가 그어지는 시간초 |
| Basic_thrust_width | 22 | 일반 공격: 화면px(폭·길이·크기·간격); 판정에는 사용하지 않음 |
| Basic_thrust_rays | 5 | 일반 공격: 생성/표시 개수 |
| Basic_thrust_ray_px | 30 | 일반 공격: 화면px(폭·길이·크기·간격); 판정에는 사용하지 않음 |
| Basic_slash_arc_deg | 130 | 일반 공격 베기 궤적 각도 폭°; 판정에는 사용하지 않음 |
| Basic_slash_radius_mult | 1.05 | 베기 표시 반경/판정 Range |
| Basic_slash_width | 22 | 일반 공격: 화면px(폭·길이·크기·간격); 판정에는 사용하지 않음 |
| Basic_slash_y_scale | 0.8 | 베기 궤적 세로 원근 비율 |
| Shadow_attack_fx_enabled | 1 | 1=새 그림자 공격 FX, 0=기존 범위/궤적; F3에서만 새 모드 범위 도형 표시 |
| Shadow_hitstop_sec | 0.04 | 피해를 준 그림자의 그림 칸·변형만 멈추는 초; 논리 시계/이동 계속 |
| Beru_trail_color | #8a6bff | 베르: HTML 색(숫자는 출처/처치 색, 잔상은 기존 색에 곱함) |
| Basic_fx_pool | 8 | 플레이어 고정 베기/찌르기 노드·Timer 개수; 초과 시 가장 오래된 효과 재사용 |
| Basic_impact_pool | 32 | 플레이어 고정 타격 별 슬롯 개수 |
| Basic_hitstop_sec | 0.03 | 플레이어 그림만 멈추는 초; 이동·공격·걷기 위상 계속 |
| Basic_star_max | 3 | 실제로 피해를 받은 적 중 별을 표시할 최대 마릿수/타격 |
| Basic_star_px | 18 | 일반 공격: 화면px(폭·길이·크기·간격); 판정에는 사용하지 않음 |
| Basic_star_sec | 0.12 | 일반 공격: 시간초(수명/유지/그리기/소멸) |
| Basic_slash_col | 23 | 베기 포즈 0기준 칸 번호 |
| Basic_thrust_col | 24 | 찌르기 포즈 0기준 칸 번호; 기존 Basic_pose_col은 대체 기본값으로 보존 |
| Damage_number_enabled | 1 | 0=숫자 노드/풀 생성 안 함, 플레이어 피격 숫자는 항상 없음 |
| Basic_thrust_ray_width | 4 | 일반 공격: 화면px(폭·길이·크기·간격); 판정에는 사용하지 않음 |
| Basic_rear_lines | 3 | 일반 공격: 생성/표시 개수 |
| Basic_rear_gap | 8 | 일반 공격: 화면px(폭·길이·크기·간격); 판정에는 사용하지 않음 |
| Basic_rear_length | 25 | 일반 공격: 화면px(폭·길이·크기·간격); 판정에는 사용하지 않음 |
| Basic_rear_width | 3 | 일반 공격: 화면px(폭·길이·크기·간격); 판정에는 사용하지 않음 |
| Belion_shard_angle_margin | 0.15 | 위쪽 방사 조각의 수평선 각도 여유값rad |
| Belion_shard_speed_min | 60 | 벨리온: 속도px/초 |
| Belion_shard_speed_max | 120 | 벨리온: 속도px/초 |
| Belion_stone_speed_x | 80 | 벨리온: 속도px/초 |
| Belion_stone_speed_y_max | 120 | 벨리온: 속도px/초 |
| Belion_stone_speed_y_min | 70 | 벨리온: 속도px/초 |
| Damage_number_fade_fraction | 0.4 | 수명 끝에서 알파가 감소하는 비율 |
| Belion_prep_stars | 3 | 벨리온: 생성/표시 개수 |
| Belion_prep_star_min | 0.15 | 손→칼끝 선 위 무작위 위치 최소 비율 |
| Belion_prep_star_max | 0.9 | 손→칼끝 선 위 무작위 위치 최대 비율 |
| Belion_band_outline_px | 2 | 벨리온: 화면px(폭·길이·크기·간격); 판정에는 사용하지 않음 |
| Basic_thrust_step_px | 6 | 찌르기 그림 내딛기px; 몸 위치는 그대로 |
