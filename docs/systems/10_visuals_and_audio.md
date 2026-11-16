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


## 2026-11-16 OPT-01 — 표시 경로 최적화

| combat_presentation.csv 키 | 예시 | 설명 |
|---|---|---|
| Damage_number_merge_sec | 0.15 | 같은 적·같은 풀 활성화 번호의 마지막 피해 이후 이 시간 이내라면 활성 숫자에 실제 HP 감소량을 더함. 0이면 이전처럼 매 타격마다 새 숫자 |

합쳐진 숫자는 튀어나옴(pop) 시간만 다시 시작하며, 위치·상승·기존 수명·페이드는 계속된다. 색은 마지막 피해 출처를 따르고 처치 색은 우선한다. 숫자는 외곽선1회+본문1회로 그리며 기존 Damage_number_bold_px는 데이터에 보존하지만 추가 굵게 그리기에는 사용하지 않는다.

피격 번쩍임은 기존0.08초와 흰색을 유지하면서 적·보스가 동일한 활성 ShaderMaterial 하나를 공유하고, 종료하면 material을 null로 분리한다. 표시 설정은 읽기 전용 공유 캐시와 로드 시 한 번 변환한 숫자/Color 캐시를 사용한다(배우별 설정 사본은 초기화 시에만). 발밑 그림자는 기존8겹 원의 색/겹침 알파/반경별 부드러움을 샘플링한 공통 텍스처를 한 번 만들고 Shadow_w/h의 타원 사각형에 한 번 그린다. 장식도 같은 텍스처를 쓴다.

난도 어둡게/흰·빨강 번쩍임은 기존 합성 순서와 알파로 ColorRect를 사용하며, 붉은 비네트는 화면 텍스처를 읽지 않는 UV 셰이더를 쓴다. 화면 텍스처 읽기는 실제 흔들림 중에만 켠다. 빈 효과 풀과 변하지 않은 그림은 기존 그리기 명령을 유지하고, 마지막 효과가 끝난 프레임에는 한 번 지운다. 정지 장식에는 반복 갱신이 없다. 난도 대상의 순서를 유지한 집합 중복 제거와 후보 목록 한 번 복사를 사용하며 판정/시점/AI/생성/전투 RNG는 그대로다.

F3에는 FPS·Performance RENDER_TOTAL_DRAW_CALLS_IN_FRAME·오브젝트 수·노드 수·현재 적 수를 추가로 표시한다(기본 숨김, 0.25초 간격). 헤드리스 CPU 기록과 실제 화면의 GPU/그리기 호출은 구분해 확인한다.

`presentation()`과 `compiled_presentation()`은 로딩 때 설치한 동일한 typed/read-only 표준 캐시를 사용한다. Engine의 표준 캐시와 새 라운드의 설정 값은 같으며, 원시 CSV 문자열 스냅샷은 동등성 검사용으로만 따로 보관한다. 표시 소비자의 사본·변환은 초기화 때만 만들고 그리기/매 프레임 경로에서는 캐시 값을 읽는다.


## 2026-11-16 FX-05 — 보스·게이트·피격 연출

기존 예고 도형의 꼭짓점·반경·시간을 그대로 사용하고 붉은 외곽/채움과 안쪽에서 차오르는 진행 채움만 추가한다. 실행 효과는 기존 판정/도착/은신/발사 준비 지점에 연결한다. 얼음 화살 세 ID(proj_test_01, elf_arrow, elf_burst_arrow)는 같은 판정·속도·수명으로 공유 텍스처를 진행 방향으로 회전하며 꼬리4개는 소멸 뒤에도 남은0.15초 이내에 정리된다.

정상 보스 일정은 기존 경고+등장 준비 시간을 알 수 있으므로 실제 활성화1.2초 전에 게이트를 연다. 직접 생성처럼 일정을 모르는 경로는 활성화 순간 연다. 게이트는 바닥 위·모든 캐릭터 아래이며 세운 원형이다. 활성화 시점·실제 위치·AI는 그대로 두고 그림만 게이트 중심에서0.45초 동안 나오며0.4초에 닫힌다. 그림 변환/투명도는 잔상 스냅샷에도 포함한다.

보스 처치 슬로 모션은 뷰포트의 시각 배율만 사용한다. 게임 시간·전투 시계·물리 이동·판정·결과 데이터·결과 표시 시점과 Engine.time_scale은 바뀌지 않는다. 기존 사망 정리와 별개인 고정 그림 슬롯이 남은 시각 페이드를 담당한다. ESC/선택 일시정지에는 모든 새 효과가 멈춘다. 사용자 승인에 따라 최종 결과 자동정지에서는 처치 그림·흰 번쩍임·흔들림만 끝까지 진행하고, 나머지 효과·세계는 정지한다. 피격 비네트·플래시는 화면 읽기 없는 기존 경로, 흔들림은 기존 skill_screen_fx를 사용하며 겹침은 현재 남은 세기보다 강할 때만 교체하고 벡터 길이를8px로 제한한다. Shake_enabled=0은 흔들림만 끈다.

표시값은 초기화된 typed 캐시, 효과는 고정 슬롯, 텍스처와 피격 재질은 공유한다. 새 효과는 전투 RNG를 사용하지 않고 비활성 풀은 다시 그리지 않는다(마지막 소멸 지우기1회). Boss_fx_enabled=0은 새 보스/화살/게이트 효과 없이 기존 예고를 사용하고 Impact_fx_enabled=0은 새 피격·처치·레벨업 효과를 만들지 않는다.

| combat_presentation.csv 키 | 예시 | 설명 |
|---|---|---|
| Boss_fx_enabled | 1 | 보스 실행 FX 공통 색/사용 여부 · 표시값 |
| Impact_fx_enabled | 1 | 피격·처치·레벨업 표시 사용 여부 · 표시값 |
| Boss_fx_outline | #16265a | 보스 실행 FX 공통 색/사용 여부 · 색상 |
| Boss_fx_color | #7fd3ff | 보스 실행 FX 공통 색/사용 여부 · 색상 |
| Boss_fx_core | #ffffff | 보스 실행 FX 공통 색/사용 여부 · 색상 |
| Boss_warn_outline | #c81e32 | 기존 예고 영역의 외곽·기본/진행 채움 · 색상 |
| Boss_warn_color | #ff3c50 | 기존 예고 영역의 외곽·기본/진행 채움 · 색상 |
| Boss_warn_width | 4 | 기존 예고 영역의 외곽·기본/진행 채움 · 화면px |
| Boss_warn_alpha | 0.18 | 기존 예고 영역의 외곽·기본/진행 채움 · 비율 |
| Boss_warn_deep_alpha | 0.32 | 기존 예고 영역의 외곽·기본/진행 채움 · 비율 |
| Fx05_pool_max | 512 | 고정 풀 및 공통 카툰 도형 · 개 |
| Gate_pool_max | 4 | 동시 게이트 고정 슬롯 수 · 개 |
| Boss_ghost_max | 4 | 보스 사망 그림 고정 슬롯 수 · 개 |
| Fx05_outline_px | 3 | 고정 풀 및 공통 카툰 도형 · 화면px |
| Fx05_draw_ratio | 0.2 | 고정 풀 및 공통 카툰 도형 · 비율 |
| Fx05_ring_end_width | 3 | 고정 풀 및 공통 카툰 도형 · 화면px |
| Fx05_spike_width | 12 | 고정 풀 및 공통 카툰 도형 · 화면px |
| Fx05_star_px | 8 | 고정 풀 및 공통 카툰 도형 · 화면px |
| Boss_fx_y_scale | 0.62 | 보스 실행 FX 공통 색/사용 여부 · 비율 |
| Fx05_puff_spread_px | 40 | 고정 풀 및 공통 카툰 도형 · 화면px |
| Fx05_puff_min_px | 4 | 고정 풀 및 공통 카툰 도형 · 화면px |
| Fx05_puff_max_px | 10 | 고정 풀 및 공통 카툰 도형 · 화면px |
| Bear_claw_count | 3 | 일반 공격 초승달 · 개 |
| Bear_claw_width | 18 | 일반 공격 초승달 · 화면px |
| Bear_claw_sec | 0.2 | 일반 공격 초승달 · 초 |
| Bear_claw_spacing_ratio | 0.16 | 일반 공격 초승달 · 비율 |
| Bear_dust_count | 4 | 돌진 경로 눈먼지 · 개 |
| Bear_dust_interval_sec | 0.1 | 돌진 경로 눈먼지 · 초 |
| Bear_speedline_count | 6 | 돌진 속도선 · 개 |
| Bear_dash_fx_sec | 0.2 | 돌진 속도선 수명 · 초 |
| Bear_speedline_spread | 30 | 돌진 속도선 · 화면px |
| Bear_speedline_width | 3 | 돌진 속도선 · 화면px |
| Bear_wave_sec | 0.3 | 내려찍기 확산 링 · 초 |
| Bear_wave_width | 16 | 내려찍기 확산 링 · 화면px |
| Bear_spike_count | 8 | 내려찍기 얼음 가시 · 개 |
| Bear_spike_min_px | 30 | 내려찍기 얼음 가시 · 화면px |
| Bear_spike_max_px | 50 | 내려찍기 얼음 가시 · 화면px |
| Bear_spike_sec | 0.4 | 내려찍기 얼음 가시 · 초 |
| Bear_spike_radius_ratio | 0.8 | 내려찍기 얼음 가시 · 비율 |
| Bear_shard_count | 6 | 내려찍기 파편 · 개 |
| Bear_shard_speed | 100 | 내려찍기 파편 · 표시값 |
| Bear_shard_px | 18 | 내려찍기 파편 · 화면px |
| Bear_slam_shake_px | 6 | 내려찍기 흔들림 · 화면px |
| Bear_slam_shake_sec | 0.2 | 내려찍기 흔들림 · 초 |
| Elf_push_rings | 2 | 밀어내기 냉기 링 · 개 |
| Elf_push_sec | 0.25 | 밀어내기 냉기 링 · 초 |
| Elf_push_width | 12 | 밀어내기 냉기 링 · 화면px |
| Elf_push_delay_sec | 0.04 | 밀어내기 냉기 링 · 초 |
| Elf_smoke_count | 10 | 은신 시작/종료 눈 연기 · 개 |
| Elf_smoke_sec | 0.35 | 은신 시작/종료 눈 연기 · 초 |
| Elf_gather_sec | 0.3 | 연사 준비 손 빛 · 초 |
| Elf_gather_px | 28 | 연사 준비 손 빛 · 화면px |
| Elf_gather_particles | 8 | 연사 준비 손 빛 · 개 |
| Elf_hand_x | 18 | 손 빛의 발 기준 화면 좌표 · 표시값 |
| Elf_hand_y | -65 | 손 빛의 발 기준 화면 좌표 · 표시값 |
| Baruka_tri_sec | 0.2 | 삼각 돌진 도착 베기 수명 · 초 |
| Baruka_slash_width | 18 | 바루카 베기 폭 · 화면px |
| Baruka_blink_px | 60 | 순간이동 도착 X자 · 화면px |
| Baruka_blink_sec | 0.15 | 순간이동 도착 X자 · 초 |
| Baruka_star_px | 18 | 순간이동 도착 별 · 화면px |
| Zone_crystal_count | 5 | 얼음 지대별 결정 · 개 |
| Zone_crystal_px | 28 | 얼음 지대별 결정 · 화면px |
| Zone_crystal_radius_ratio | 0.6 | 얼음 지대별 결정 · 비율 |
| Zone_fog_count | 12 | 얼음 지대 가장자리 안개 · 개 |
| Zone_fog_px | 10 | 얼음 지대 가장자리 안개 · 화면px |
| Zone_fog_wave | 0.15 | 얼음 지대 가장자리 안개 · 비율 |
| Zone_fog_alpha | 0.2 | 얼음 지대 가장자리 안개 · 비율 |
| Zone_fade_mult | 5 | 지대 말기 시각 페이드 비율 · 표시값 |
| Arrow_px | 56 | 얼음 화살 그림/꼬리 · 화면px |
| Arrow_tail_count | 4 | 얼음 화살 그림/꼬리 · 개 |
| Arrow_tail_sec | 0.15 | 얼음 화살 그림/꼬리 · 초 |
| Arrow_tail_px | 4 | 얼음 화살 그림/꼬리 · 화면px |
| Arrow_tail_alpha | 0.45 | 얼음 화살 그림/꼬리 · 비율 |
| Gate_lead_sec | 1.2 | 보스 등장 게이트 · 초 |
| Gate_px | 220 | 보스 등장 게이트 · 화면px |
| Gate_back_px | 20 | 보스 등장 게이트 · 화면px |
| Gate_center_up_ratio | 0.45 | 보스 등장 게이트 · 비율 |
| Gate_open_sec | 0.6 | 보스 등장 게이트 · 초 |
| Gate_spin_deg | 40 | 보스 등장 게이트 · 초당 회전각(도) |
| Gate_particle_count | 12 | 보스 등장 게이트 · 개 |
| Gate_particle_hz | 1 | 보스 등장 게이트 · Hz |
| Gate_particle_px | 3 | 보스 등장 게이트 · 화면px |
| Gate_emerge_sec | 0.45 | 보스 등장 게이트 · 초 |
| Gate_emerge_scale | 0.55 | 보스 등장 게이트 · 비율 |
| Gate_close_sec | 0.4 | 보스 등장 게이트 · 초 |
| Gate_shake_px | 5 | 보스 등장 게이트 · 화면px |
| Gate_shake_sec | 0.2 | 보스 등장 게이트 · 초 |
| Gate_flash_alpha | 0.35 | 보스 등장 게이트 · 비율 |
| Gate_flash_sec | 0.12 | 보스 등장 게이트 · 초 |
| Player_hit_vignette_alpha | 0.35 | 플레이어 피격 화면 표시 · 비율 |
| Player_hit_vignette_sec | 0.25 | 플레이어 피격 화면 표시 · 초 |
| Player_hit_shake_px | 3 | 플레이어 피격 화면 표시 · 화면px |
| Player_hit_shake_sec | 0.12 | 플레이어 피격 화면 표시 · 초 |
| Player_hp_shake_sec | 0.2 | 발밑 HP 바 표시 흔들림 · 초 |
| Player_hp_shake_px | 3 | 발밑 HP 바 표시 흔들림 · 화면px |
| Player_hp_shake_hz | 24 | 발밑 HP 바 표시 흔들림 · Hz |
| Player_hit_color | #ff3048 | 플레이어 피격 화면 표시 · 색상 |
| Kill_puff_count | 5 | 일반 적 처치 눈 연기 · 개 |
| Kill_puff_sec | 0.25 | 일반 적 처치 눈 연기 · 초 |
| Boss_hit_flash_sec | 0.1 | 보스 흰색 번쩍임 · 초 |
| Boss_kill_slowmo_sec | 0.4 | 보스 처치 화면·그림 시계 · 초 |
| Boss_kill_slowmo_scale | 0.3 | 보스 처치 화면·그림 시계 · 비율 |
| Boss_kill_flash_alpha | 0.6 | 보스 처치 화면·그림 시계 · 비율 |
| Boss_kill_flash_sec | 0.15 | 보스 처치 화면·그림 시계 · 초 |
| Boss_kill_shake_px | 8 | 보스 처치 화면·그림 시계 · 화면px |
| Boss_kill_shake_sec | 0.3 | 보스 처치 화면·그림 시계 · 초 |
| Level_ring_count | 2 | 레벨업 빛 고리 · 개 |
| Level_ring_px | 80 | 레벨업 빛 고리 · 화면px |
| Level_ring_sec | 0.4 | 레벨업 빛 고리 · 초 |
| Level_ring_width | 5 | 레벨업 빛 고리 · 화면px |
| Level_ring_delay | 0.06 | 레벨업 빛 고리 · 초 |
| Shake_max_px | 8 | 겹친 흔들림 최대 화면px · 화면px |
| Fx05_core_ratio | 0.4 | 고정 풀 및 공통 카툰 도형 · 비율 |


## 2026-11-16 UI-01 — 시스템 창과 타이틀·지역 선택

프로젝트 공통 Theme는 assets/ui/ui_theme.tres 하나를 사용한다. 기본 글꼴은 NotoSansKR-Bold-subset.otf, 제목/강조는 Black이며 원본 OTF와 OFL.txt를 그대로 보존한다. 밝은 글씨 #ebf8ff, 하늘색 #96d7ff 외곽/그림자, 보조 #c8e1ff를 사용한다. 텍스처는 밉맵·선형 밉맵 필터이고 창 가운데는 Tile이다.

| UI 자료 | 크기 | 패치/용도 예시 |
|---|---|---|
| ui_window.png | 192×192 | 사방40, 창 가운데 Tile |
| ui_button_normal/hover/pressed/disabled.png | 160×64 | 사방24, 버튼 상태4종 |
| ui_frame_overlay.png | 192×192 | 사방40, 지역 카드 투명 가운데 테두리 |
| ui_icon_frame.png | 96×96 | 사방20, 아이콘 투명 가운데 테두리 |
| ui_bar_bg.png / ui_bar_fill.png | 64×20 | 사방6, 로딩 바/경험치 바 |
| ui_window_crest.png | 96×34 | 늘리지 않음; 큰 창 중앙 상단, 아래 끝이 창 위24px |
| ui_lock.png | 64×64 | 잠금 그림 |
| title_bg.png / logo.png / region_ice.png | 1672×941 / 1394×734 / 960×540 | 배경 비율 유지 가운데 자름 / 가로640·y380 / 중앙560×315 |
| icon_dash / rapid_slash / stealth / dragon_fear | 256×256 | skill_ 접두 Id로 연결 |
| icon_shadow_igris / beru / belion | 256×256 | igrit / charger_test / belion, Icon 빈칸도 Id로 연결 |
| NotoSansKR-Bold/Black-subset.otf, OFL.txt | 사용자 원본 | 기본/제목과 라이선스 동봉 |

로딩 시간·지역 이동 범위/잠금·시작/결과/재시작·선택 카드·쿨타임은 기존 상태값을 표시한다. 옆 카드는60%·알파0.7이며 범위 밖이면 비우고 잠긴 카드는 흑백+잠금 그림이다. 지역 변경은 즉시 확정하되 그림만0.2초 이동한다. 선택 카드의 회복·능력치는 글자만, 스킬/그림자는 Id 아이콘을 사용한다. 기존 도형 타이틀·자물쇠·생성 아이콘을 제거했으며 경고/쿨타임/레벨/+ 등 상태 표시는 유지한다.

논리적 닫힘과 입력 해제/일시정지 해제는 즉시 유지하고, 입력을 받지 않는 표시 사본만0.1초 접고 정리한다. 창 열림0.15초·깜빡임2회·가로 흔들림3px, 버튼 hover1.04/0.08초·press0.97을 사용한다. 활성 UI 전환/광택/먼지/쿨타임만 갱신하고 정지한 UI는 다시 그리지 않는다. 지역 그림의 블러/흑백 재질은 같은 유형 카드끼리 공유하고 UI는 화면 읽기 셰이더를 추가하지 않는다. 전투/생성 RNG를 사용하지 않는다.

팬 공지는 타이틀 하단과 설정 창에 표시한다. 제공한 두 부분집합 글꼴에 「 」가 없어 사용자 승인으로 그 두 글자만 U+2018·U+2019로 바꿨다(시스템 글꼴 대체 없음):

> 본 게임은 웹툰 ‘나 혼자만 레벨업’의 비상업적 팬 게임(포트폴리오)입니다. 원작의 저작권은 각 권리자에게 있습니다. 글꼴: Noto Sans CJK(SIL OFL 1.1)

| combat_presentation.csv 키 | 예시 | 설명 |
|---|---|---|
| Ui_fx_enabled | 1 | 0이면 창/버튼 확대·먼지·광택·카드 이동 연출 없이 즉시 표시 |
| Ui_open_sec | 0.15 | 창 열림 초 |
| Ui_close_sec | 0.1 | 입력/흐름 처리가 끝난 뒤 표시 사본이 접히는 초 |
| Ui_open_scale_y | 0.2 | 열림 시작 세로 배율 |
| Ui_flicker_count | 2 | 열림 중 알파 깜빡임 횟수 |
| Ui_jitter_px | 3 | 열림 가로 흔들림 화면px |
| Ui_hover_scale | 1.04 | 버튼/선택 카드 마우스 진입 배율 |
| Ui_press_scale | 0.97 | 누르는 동안 배율 |
| Ui_hover_sec | 0.08 | 버튼 배율 전환 초 |
| Ui_card_slide_sec | 0.2 | 지역 카드 표시 이동 초; 지역 인덱스/잠금 판단은 즉시 유지 |
| Ui_dust_count | 30 | 타이틀/메뉴 고정 배열 빛 가루 수 |
| Ui_dust_speed | 12 | 가루 상승 px/초 |
| Ui_dust_min_px | 1 | 최소 가루 반경px |
| Ui_dust_max_px | 2 | 최대 가루 반경px |
| Ui_logo_sheen_interval_sec | 3 | 로고 광택 반복 주기초 |
| Ui_logo_sheen_sec | 0.7 | 광택이 왼쪽→오른쪽 이동하는 초 |
| Ui_logo_sheen_width | 0.12 | 광택 UV 폭 |
| Ui_logo_sheen_strength | 0.6 | 알파 마스크 내부 광택 강도 |
| Ui_menu_brightness | 0.35 | 지역 선택 배경 밝기 배율 |
| Ui_menu_blur_px | 4 | 배경/미리보기 텍스처 블러px; 화면 텍스처를 읽지 않음 |
| Ui_side_alpha | 0.7 | 옆 카드 알파 |
| Ui_side_scale | 0.6 | 옆 카드 배율 |
| Ui_color | #ebf8ff | 그린 UI 기본 글씨색; Theme 기본색도 같은 시작값 |
| Ui_glow_color | #96d7ff | 글씨 외곽 번짐색 |
| Ui_secondary_color | #c8e1ff | 보조·팬 공지 색 |
| Ui_notice_alpha | 0.8 | 팬 공지 알파 |
| Ui_dust_color | #96d7ff | 하늘색 빛 가루색(흰색과 교대) |
| Ui_flicker_alpha | 0.45 | 깜빡임 때 최소 알파 |
| Ui_card_slide_px | 200 | 지역 전환 시 표시 이동 시작 거리px |
| Ui_side_brightness | 0.6 | 옆 카드 그림 밝기 |
| Ui_locked_brightness | 0.3 | 잠금 카드 흑백 그림 밝기 |
| Ui_title_dim_alpha | 0.95 | 하단 어두운 그라데이션 끝 알파 |
| Ui_dust_alpha | 0.65 | 하늘색 가루 알파 |
| Ui_logo_tilt | 0.15 | 광택 줄기 기울기 |


## 2026-11-16 FIX-01 — UI 여백·벨리온 타격 표시 제한

ui_window·ui_frame_overlay·ui_button_*·ui_icon_frame의 양쪽 axis_stretch는 Stretch로 통일한다. 주사선 늘어남은 허용하며 모서리 장식 반복을 없앤다. 지역 그림560×315의 바깥으로40px 패치 테두리를 확장하고, 이동 버튼은 중앙/옆 카드 테두리에서16px 이상 떨어뜨린다. 옆 카드는60% 크기를 유지해 화면 가장자리에서 일부 잘린 미리보기로 보인다. 지역 제목은 창 안쪽 세로 중앙, 설정 버튼은112×56이다. 선택 카드의 이름·설명·레벨을 가운데 정렬하고, 레벨 칸과 글자는 테두리 안쪽 여백을 확보한다. 아이콘 없는 능력치/회복 카드는 이름·설명을 세로 가운데로 옮기며 다시 뽑기 버튼은500×64다.

| combat_presentation.csv 키 | 예시 | 설명 |
|---|---|---|
| Belion_burst_max | 3 | 한 쓸기에서 폭발하는 피해 대상 최대 수. 이후 대상은 Igris_star 방식 흰 별만 시도. 쓸기 종료 지점 폭발은 별도로 유지 |
| Impact_spawn_max_per_frame | 40 | 같은 게임 세계의 한 물리 프레임에서 새로 생성하는 타격 불티/별·히트 불꽃·피해 숫자의 공통 최대 수. 초과 표시만 생략하고 피해·신호·판정은 그대로 |

벨리온의 폭발은 기존 파편7·돌5·별1을 사용한다. 활성 쓸기에는 그 종료 폭발13개 몫을 공통 표시 예산에서 확보해 두고, 종료 시 사용한다. 다른 타격 표시는 남은 몫을 사용하므로 프레임 합계는40 이하다. 기존 활성 피해 숫자 합치기는 신규 생성이 아니므로 계속 합산하며, 새 숫자 생성을 생략한 피해량은 전투 HP에서 정상 적용된다. 생성 상한은 피해 신호 이후의 표시 풀과 난도 타격 별에 적용하며 게임 피해 처리/대상 순서는 바꾸지 않는다.

줄무늬 띠의 교대색·조각별 페이드는 정점 색으로 유지하고, 띠·외곽을 삼각형 배열1회로 제출한다. 칼끝 흰 선은 폴리라인1회다. 별도 재질이나 타격별 노드를 추가하지 않는다. 글리프 P0는 Unicode 범위 제한 없이 게임 스크립트 문자열(동적 UI 형식/공지/토스트 포함)과 CSV 표시 열(Name_ko/Desc_ko 등)을 두 제공 글꼴에 대조하며 누락 시 문자·U+코드·출처를 출력한다.


## 2026-11-16 SND-01 — 오디오와 인게임 UI 가시성

GameAudio Autoload 하나와 Master/BGM/SFX 버스를 사용한다. AudioStreamPlayer는 총16개로 고정한다(크로스페이드 BGM2개 예약·SFX14개). 스트림/수치/색은 시작 시 캐시하며 오디오 피치는 전투와 별도 RNG로 ±5% 범위만 사용한다. 같은 소리의 동시/간격 제한 또는 풀 포화 시 그 재생만 생략한다. 게임 이벤트의 성공·피해·시간·RNG는 소리 재생 결과를 읽지 않는다.

로딩/메뉴 title→라운드 stage01→보스 활성 boss→처치 stage01, 결과·사망은1초 페이드아웃한다. BGM 교체는1초 선형 크로스페이드이며 세 곡은 loop한다. 모든 일시정지는 BGM 선형 음량50%·게임SFX 정지다. 사용자 승인으로 레벨업 선택 창의 level_up/ui_click만 예외로 끝까지 재생하며 ESC에서는 이 소리도 멈춘다. 설정의 두 dB 슬라이더는 세션 중 유지하며 저장 파일을 만들지 않는다. CREDITS.txt 원문은 설정 스크롤에 그대로 표시하고 WAV/OGG/원문 바이트를 보존한다.

| data/sound.csv 열 | 형식 | 예시 | 설명 |
|---|---|---|---|
| Id | String | enemy_hit | 아래 이벤트 ID |
| Path | Path | res://assets/audio/sfx/sfx_enemy_hit.wav | 재생 스트림 |
| Volume_db | Float | 0 | 가공된 원본에 더하는 소리별dB |
| Max_concurrent | Int | 4 | 같은 SFX 최대 동시 수 |
| Min_interval_sec | Float | 0.04 | 같은 SFX 실제 재생 사이 최소초 |
| Pitch_random | Float | 0.05 | 1±이 값 피치 범위, BGM0 |

| 소리 Id | 이벤트 | Volume_db 예시 | 동시 | 간격초 | Pitch_random |
|---|---|---:|---:|---:|---:|
| ui_click | 버튼/카드 누름 | 0 | 3 | 0 | 0.05 |
| system_notify | 일반 토스트 | 0 | 3 | 0 | 0.05 |
| level_up | 레벨 업 | 0 | 3 | 0 | 0.05 |
| xp_pickup | XP 획득 | 0 | 3 | 0.05 | 0.05 |
| slash | 일반 공격 홀수 타격 | 0 | 3 | 0 | 0.05 |
| thrust | 일반 공격 짝수 타격 | 0 | 3 | 0 | 0.05 |
| rapid_slash | 난도 시작1회 | 0 | 3 | 0 | 0.05 |
| dash | 질주 시작 | 0 | 3 | 0 | 0.05 |
| stealth | 은신 시작 | 0 | 3 | 0 | 0.05 |
| dragon_fear | 피어 시작 | 0 | 3 | 0 | 0.05 |
| enemy_hit | 적/보스 수락된 양수 피해 | 0 | 4 | 0.04 | 0.05 |
| enemy_die | 일반 적 처치 | 0 | 3 | 0.05 | 0.05 |
| player_hurt | 플레이어 수락된 양수 피해 | 0 | 3 | 0.15 | 0.05 |
| arrow_shot | 엘프3종 투사체 발사 | 0 | 3 | 0.08 | 0.05 |
| shadow_summon | 그림자 소환 | 0 | 3 | 0 | 0.05 |
| igris_slash | 이그리트 피해 시점 | 0 | 2 | 0 | 0.05 |
| beru_claw | 베르 돌진 시작 | 0 | 2 | 0 | 0.05 |
| belion_chain | 벨리온 쓸기 시작 | 0 | 2 | 0 | 0.05 |
| boss_warning | 보스 경고 토스트 | 0 | 3 | 0 | 0.05 |
| gate_open | 게이트 열림 | 0 | 3 | 0 | 0.05 |
| boss_slam | 곰slam/바루카ice_zone 실행 | 0 | 3 | 0 | 0.05 |
| bgm_title | 로딩/메뉴 | 0 | 1 | 0 | 0 |
| bgm_stage01 | 라운드/보스 처치 후 | 0 | 1 | 0 | 0 |
| bgm_boss | 보스 활성 중 | 0 | 1 | 0 | 0 |


스킬 아이콘은1.35배, 쿨타임 덮개 비율은 남은 시간/쿨타임이다. 시계 방향으로 걷히며 가운데 Black 초·모서리 키·아래 레벨 점·사용 가능 순간 흰 테두리·금색 깜빡이는 강화 배지와 강화 포인트N을 사용한다. 정지한 바탕/이름은 다시 그리지 않고 필요한 덮개/배지만 갱신한다. 상단 경험치 바는14px·공유 그라데이션 텍스처+기존 바 그림·빛을 쓰며 좌측Lv24px/우측현재·필요를 표시한다(시간은 우측 아래로 이동). XP 획득/레벨업 번쩍임은 표시 전용이다.

토스트는 최소533~화면폭-80px의 한 줄이다. 초과할 때만 글씨를 줄이며 최소16px에서도 넘는 극단적 문구는 말줄임한다(이벤트 원문은 보관). 알림 제목 아래에 본문 한 줄을 두고 기존88px·개수·쌓기·시간 규칙을 유지한다.

| combat_presentation.csv 키 | 예시 | 설명 |
|---|---|---|
| Sound_bgm_db | -6 | 시작 BGM 버스dB |
| Sound_sfx_db | 0 | 시작 SFX 버스dB |
| Sound_bgm_fade_sec | 1 | BGM 교체/결과·사망 페이드초 |
| Sound_pause_bgm_ratio | 0.5 | 일시정지 BGM 선형 음량 배율 |
| Sound_slider_min_db | -40 | 설정 슬라이더 최소dB |
| Sound_slider_max_db | 6 | 설정 슬라이더 최대dB |
| Skill_icon_scale | 1.35 | 기존56px 아이콘 배율 |
| Skill_cooldown_alpha | 0.6 | 남은 쿨타임 부채꼴 덮개 알파 |
| Skill_ready_flash_sec | 0.25 | 사용 가능 전환 흰 테두리초 |
| Skill_plus_color | #ffd84a | 강화 가능 배지 금색 |
| Skill_plus_blink_hz | 0.6 | 강화 배지 깜빡임Hz |
| Skill_plus_min_alpha | 0.45 | 강화 배지 최소알파 |
| Skill_plus_radius | 15 | 강화 원형 배지 반경px |
| Skill_cooldown_font_size | 28 | 쿨타임 Black 글씨px |
| Skill_level_dot_px | 4 | 레벨 점 반경px |
| Xp_bar_height | 14 | 상단 바 높이px |
| Xp_fill_start | #a68cff | 채움 시작색 |
| Xp_fill_end | #e0d4ff | 채움 끝색 |
| Xp_gain_flash_sec | 0.15 | 획득 시 채움 끝 번쩍임초 |
| Xp_level_flash_sec | 0.3 | 레벨업 전체 바 번쩍임초 |
| Toast_min_width | 533 | 토스트 최소너비px |
| Toast_screen_margin | 80 | 최대너비 계산용 화면 여백px |
| Toast_min_font_size | 16 | 긴 한 줄 토스트 최소글씨px |
| Xp_bar_glow_alpha | 0.3 | 바 바깥빛 알파(기존 XP 결정 키와 별개) |

## 2026-11-17 FX-06 — 드래곤 피어·이동/공격 모션·설정/선택 창·진입 연출

표시·소리 연결만 바꾼다. 판정·피해·시점·이동 속도/거리·AI·생성·전투 RNG·로딩 시간·결과는 유지한다. 새 연출 값은 typed 캐시로 읽고, 빛 더하기 재질(CanvasItemMaterial ADD)은 1개를 공유하며, 눈먼지는 라운드당 고정 풀 1개(활성 없으면 처리·redraw 없음)를 쓴다.

- 드래곤 피어: 굵은 선 파장·할퀴기를 fx_soft_ring 3겹(바깥 Fear_ring_outer_color→안쪽 Fear_ring_inner_color, 세로 Fear_wave_y_scale, 마지막 겹 Fear_wave_max_px)과 각 겹 바깥 fx_thin_ring 가장자리선으로 바꾼다. 실제 공포 범위(Range)는 fx_soft_disk를 캐릭터 아래 바닥에 깔아 Cast_sec+Fear_disk_tail_sec 동안 흐리게 한다. 할퀴기 Fear_claw_count개는 Fear_scratch_width 이하 뾰족한 선+흰 중심선, 불씨 Fear_ember_count개는 fx_soft_dot로 바깥·위로 퍼진다. Fear_bat_count는 40→20으로 바꿨다. 비네트·흔들림은 유지한다. 더 이상 읽지 않는 키: Fear_range_alpha, Fear_range_width, Fear_wave_start_width, Fear_wave_end_width, Fear_outline_color, Fear_claw_width, Fear_claw_sec.
- 이동 모션(그림만): 플레이어는 이동 방향 기울기·출발 눌림·정지 늘어남·좌우 전환 좁아짐을 쓴다(질주 중에는 기울기만). 걷기 칸 구간의 첫 칸과 가운데 칸(플레이어 앞 5·9, 뒤 13·17)에 들어설 때 발밑 눈먼지를 낸다. 그림자 병사·일반 적은 눈먼지만 Move_dust_npc_every 번째 접지마다 낸다.
- 일반 공격 모션(그림만): 예정된 타격 Basic_windup_sec 전부터 반대 방향으로 Basic_windup_px까지 당긴 뒤 기존 내딛기를 쓴다. 칼빛 시작점은 발 기준 손 위치(Basic_hand_x는 좌우 반전, Basic_hand_y)다. 판정 삼각형은 그대로다. 실제로 맞은 첫 타격에 화면을 공격 방향으로 Basic_push_px 민다(Shake_enabled=0이면 생략). 맞고 살아 있는 일반 적(보스 제외)은 그림이 눌렸다 돌아온다.
- 설정 창: 배경음악·효과음 슬라이더는 0~100 숫자를 표시한다. 100은 Sound_bgm_db/Sound_sfx_db, 0은 버스 음소거, 그 사이는 기본dB+linear_to_db(값/100)이다. 남은 문구는 팬 공지와 사운드 출처 한 줄뿐이며 CREDITS 스크롤은 없앴다(CREDITS.txt 파일은 유지). Sound_slider_min_db/Sound_slider_max_db는 더 이상 읽지 않는다.
- 레벨업 선택 창: 창이 열릴 때 level_up 소리를 내지 않는다(카드 선택 ui_click 유지). 제목·카드·다시 뽑기를 창 안에서 같은 간격으로, 카드 안 아이콘·이름·설명·레벨 칸도 같은 간격으로 두며 아이콘 없는 카드도 같은 기준선을 쓴다.
- 진입 연출: 지역 선택의 게임 시작 버튼은 Stage_cover_sec 동안 가장자리부터 그림자로 덮은 뒤 기존 start_region을 호출하고, 라운드가 준비되면 Stage_reveal_sec 동안 가운데부터 걷는다(사용자 승인 2026-11-17: 버튼 입장은 덮기 뒤에 라운드 생성). 다시 하기·메뉴 복귀는 흐름을 그대로 진행하고 걷힘만 쓴다. 전체 화면 ColorRect 셰이더 1개이며 입력을 막지 않고 끝나면 숨긴다. Ui_fx_enabled=0이면 즉시 전환한다.

| combat_presentation.csv 키 | 예시 | 설명 |
|---|---|---|
| Fear_ring_outer_color | #ff2a3c | 첫(바깥) 고리 색 |
| Fear_ring_inner_color | #7a0010 | 마지막(안쪽) 고리 색 |
| Fear_ring_alpha | 0.9 | 고리 최대 알파 |
| Fear_ring_tex_peak | 0.85 | fx_soft_ring 가장 밝은 반경 비율 |
| Fear_edge_color | #ffb3ba | 가장자리선 색 |
| Fear_edge_alpha | 0.6 | 가장자리선 알파 |
| Fear_edge_tex_peak | 0.88 | fx_thin_ring 가장 밝은 반경 비율 |
| Fear_edge_offset | 1.04 | 고리 반경 대비 가장자리선 반경 |
| Fear_disk_color | #5a0010 | 실제 범위 바닥 원 색 |
| Fear_disk_alpha | 0.45 | 바닥 원 시작 알파 |
| Fear_disk_tail_sec | 0.6 | Cast_sec 뒤 바닥 원이 사라지는 초 |
| Fear_scratch_width | 4 | 할퀴기 최대 굵기px |
| Fear_scratch_sec | 0.15 | 할퀴기 수명초 |
| Fear_scratch_draw_ratio | 0.4 | 수명 중 긋는 구간 비율 |
| Fear_scratch_core_color | #ffffff | 할퀴기 중심선 색 |
| Fear_ember_count | 40 | 불씨 수 |
| Fear_ember_min_px | 8 | 불씨 최소 크기px |
| Fear_ember_max_px | 16 | 불씨 최대 크기px |
| Fear_ember_sec | 0.8 | 불씨 수명초 |
| Fear_ember_color | #ff3a2e | 불씨 색 |
| Fear_ember_start_px | 36 | 플레이어 주변 시작 반경px |
| Fear_ember_travel_px | 150 | 바깥으로 퍼지는 거리px |
| Fear_ember_rise_px | 90 | 위로 오르는 거리px |
| Move_lean_deg | 6 | 이동 방향 최대 기울기 |
| Move_lean_sec | 0.12 | 최대 기울기까지 따라가는 초 |
| Move_start_sec | 0.08 | 출발 눌림초 |
| Move_start_scale_x | 1.06 | 출발 눌림 가로 배율 |
| Move_start_scale_y | 0.94 | 출발 눌림 세로 배율 |
| Move_stop_sec | 0.1 | 정지 늘어남초 |
| Move_stop_scale_x | 0.96 | 정지 가로 배율 |
| Move_stop_scale_y | 1.04 | 정지 세로 배율 |
| Move_turn_sec | 0.08 | 좌우 전환 좁아짐초 |
| Move_turn_scale_x | 0.92 | 좌우 전환 가로 배율 |
| Move_dust_count | 3 | 접지 1회 눈먼지 수 |
| Move_dust_sec | 0.3 | 눈먼지 수명초 |
| Move_dust_min_px | 8 | 눈먼지 최소 크기px |
| Move_dust_max_px | 12 | 눈먼지 최대 크기px |
| Move_dust_alpha | 0.5 | 눈먼지 알파 |
| Move_dust_color | #ffffff | 눈먼지 색 |
| Move_dust_spread_px | 10 | 좌우 퍼짐px |
| Move_dust_rise_px | 6 | 위로 오름px |
| Move_dust_pool | 96 | 라운드당 고정 풀 크기 |
| Move_dust_npc_every | 2 | 그림자·일반 적 접지 간격 배수 |
| Basic_windup_sec | 0.04 | 타격 전 당김초 |
| Basic_windup_px | 2 | 당김 거리px |
| Basic_hand_x | 18 | 발 기준 손 가로px(좌우 반전) |
| Basic_hand_y | -40 | 발 기준 손 세로px |
| Basic_push_px | 1 | 타격 화면 밀기px |
| Basic_push_sec | 0.05 | 화면 밀기초 |
| Enemy_hit_squash_sec | 0.08 | 맞은 일반 적 눌림초 |
| Enemy_hit_squash_x | 1.1 | 눌림 가로 배율 |
| Enemy_hit_squash_y | 0.9 | 눌림 세로 배율 |
| Stage_cover_sec | 0.5 | 진입 덮기초 |
| Stage_reveal_sec | 0.6 | 걷힘초 |
| Stage_shade_color | #0b0618 | 그림자 색 |
| Stage_glow_color | #7a5cff | 경계 빛 색 |
| Stage_noise_scale | 6 | 노이즈 크기 |
| Stage_noise_mix | 0.35 | 원형 대비 노이즈 섞음 |
| Stage_glow_band | 0.08 | 경계 빛 폭(임계값 단위) |

## 2026-11-17 FIX-02 — UI 여백·인게임 음량·로딩 5초

판정·전투·흐름 순서는 유지한다. 로딩은 Loading_sec 값만 1.5→5로 바꿨고, 실제 로딩이 먼저 끝나도 5초 동안 로딩 화면을 유지하는 기존 방식 그대로다.

- 시스템 창 여백: ui_window 9분할 그림의 테두리 선은 텍스처 가장자리에서 Ui_window_border_px 안쪽에 있다. 모든 시스템 창(설정·일시정지·결과·레벨업 창, 토스트)의 글자·버튼·슬라이더는 그 선에서 좌우 Ui_window_pad_x, 위아래 Ui_window_pad_y 안에 둔다. 문장(crest)은 위 테두리 선 위쪽에 있어 제목과 겹치지 않는다. 지역 선택 화면의 "지역 선택" 제목 판은 창이 아닌 표지판으로 보고 기존 크기를 유지한다.
- 토스트: 첫 토스트의 테두리 선 위치를 화면 위 Toast_top_px에 둔다. 높이는 위아래 Toast_pad_y + 제목줄("! 알림 !", Toast_title_font_size) + Toast_title_gap_px + 본문 한 줄이다. 테두리 안 너비는 본문 글자 폭 + 좌우 Toast_pad_x이며 Toast_min_width~(화면 폭-Toast_screen_margin) 사이로 맞춘다. 최대를 넘을 때만 글자를 줄인다(Toast_min_font_size까지). 여러 개가 쌓일 때 간격 규칙(Toast_gap_px)은 그대로다.
- 레벨업 선택 창: 창(문장 포함)은 첫 토스트 아래 Choice_toast_gap_px부터 시작한다. 카드 테두리 사이 간격과 창 테두리~바깥 카드 간격은 같다. 카드 안 여백은 좌우 Choice_card_pad_x, 위 Choice_card_pad_top, 아래 Choice_card_pad_bottom이고, Lv 텍스트는 카드 아래 테두리에서 Choice_card_pad_bottom 이상 떨어진다. 다시 뽑기 버튼은 글자 위아래 Choice_reroll_text_pad 이상(버튼 그림 면 기준, 면은 텍스처 가장자리에서 Ui_button_border_px 안쪽)이고, 버튼 면 아래가 창 테두리에서 Choice_reroll_bottom_px 위에 있다.
- 결과·일시정지 창: 너비 580 고정, 높이는 내용에 맞춰 화면 세로 가운데에 둔다. 버튼은 창 좌우 여백 안에서 같은 너비다. ESC 일시정지 창에 메뉴 설정과 같은 배경음악·효과음 슬라이더(0~100)를 두고 같은 값을 쓴다. 한쪽에서 바꾸면 다른 쪽 슬라이더·숫자도 바뀐다. 계속·메인으로 버튼은 그대로다.
- 설정 창·지역 선택 화면: 사운드 출처 문구를 지우고, 팬 공지에서 글꼴 표기를 지웠다(남은 문구: "본 게임은 웹툰 ‘나 혼자만 레벨업’의 비상업적 팬 게임(포트폴리오)입니다. 원작의 저작권은 각 권리자에게 있습니다."). 메뉴 오른쪽 위 "설정" 버튼 글자는 Ui_gear_font_size다. 내보내기 포함 필터(export_presets.cfg include_filter)에 assets/fonts/OFL.txt와 assets/audio/CREDITS.txt를 더해 exe 내보내기에 함께 넣는다.
- 로딩 바: 실제 로딩 진행을 넘지 않는 범위에서 Loading_sec 동안 시간에 맞춰 차오른다.
- 드래곤 피어 색(선택 항목): Fear_glow_additive=0이면 고리·가장자리·할퀴기·불씨를 빛 더하기 대신 일반 합성으로 그린다(재질 없음). 고리 색은 Fear_ring_outer_color #c8102e → Fear_ring_inner_color #3a0008이고, 분홍 가장자리선이 남지 않게 Fear_edge_color도 #c8102e로 바꿨다. 시전 동안 화면 전체를 Fear_dim_color·Fear_dim_alpha로 어둡게 하고 비네트 꼬리(Fear_vignette_tail_sec) 동안 걷는다. 비네트·흔들림은 유지한다.

| combat_presentation.csv 키 | 예시 | 설명 |
|---|---|---|
| Ui_window_pad_x | 32 | 창 테두리 선에서 좌우 안쪽 여백px |
| Ui_window_pad_y | 24 | 창 테두리 선에서 위아래 안쪽 여백px |
| Ui_window_border_px | 30 | ui_window.png 가장자리~테두리 선 안쪽 거리px |
| Ui_button_border_px | 14 | ui_button 그림 가장자리~버튼 면 거리px |
| Ui_gear_font_size | 16 | 메뉴 "설정" 버튼 글자 크기 |
| Toast_top_px | 16 | 첫 토스트 테두리 선의 화면 위 거리px |
| Toast_pad_x | 40 | 토스트 본문 좌우 여백px |
| Toast_pad_y | 12 | 토스트 위아래 여백px |
| Toast_title_gap_px | 6 | 제목줄과 본문 사이px |
| Toast_title_font_size | 16 | "! 알림 !" 글자 크기 |
| Choice_card_pad_x | 20 | 카드 좌우 안쪽 여백px |
| Choice_card_pad_top | 20 | 카드 위 안쪽 여백px |
| Choice_card_pad_bottom | 24 | 카드 아래 안쪽 여백px(Lv 텍스트 아래) |
| Choice_reroll_text_pad | 12 | 다시 뽑기 글자 위아래 여백px |
| Choice_reroll_bottom_px | 28 | 다시 뽑기 버튼 면~창 아래 테두리px |
| Choice_toast_gap_px | 8 | 첫 토스트 아래~레벨업 창 문장 위px |
| Fear_glow_additive | 0 | 1이면 피어 빛 더하기, 0이면 일반 합성 |
| Fear_dim_color | #200008 | 피어 시전 중 화면 어둡게 색 |
| Fear_dim_alpha | 0.25 | 화면 어둡게 알파 |

값을 바꾼 기존 키: Loading_sec 1.5→5, Toast_min_width 533→420(테두리 안 너비 기준), Fear_ring_outer_color #ff2a3c→#c8102e, Fear_ring_inner_color #7a0010→#3a0008, Fear_edge_color #ffb3ba→#c8102e.
