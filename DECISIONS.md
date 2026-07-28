---
title: Pinball_Logue 로컬 의사결정 기록
summary: 사용자 승인으로 확정된 저장소 구현 방향의 변경 전후, 이유와 영향 범위를 기록한다.
document_type: decision-log
scope: repository
status: active
read_when:
  - 중요한 구현 방향이나 게임 기획이 변경됐는지 확인할 때
  - 기능 SPEC과 코드의 결정 근거를 추적할 때
---

# 로컬 의사결정 기록

## DEC-20260727-01 — 3D 런타임과 차원 독립 경계 채택

- 상태: superseded by `DEC-20260728-02`
- 요청자: 사용자
- 변경 전: 임시 메인 씬은 `Node2D`이며 외부 조준·발사 상세안은 Physics2D 노드와 API를 전제로 했다.
- 변경 후: 현재 플레이 공간은 3D로 구현하고, 도메인 상태·명령·결과는 장면 차원과 분리한다. 메뉴 UI는 `Control`, 웨이브·보스 플레이 공간은 `Node3D`를 사용한다. 미래 2D 구현은 동일한 공개 계약을 사용하는 별도 어댑터로 교체할 수 있게 한다.
- 변경 이유: 현재 3D 플레이 요구를 충족하면서 이후 2D↔3D 전환 비용과 기능 간 결합을 제한하기 위해서다.
- 영향받는 기능: `app/`, `pinball/`, `stages/`, `ui/`, `presentation/`, `integration/`
- 갱신 문서: `app/SPEC.md`, `integration/.work/basic-system-foundation/PLAN.md`
- 검증 기준: 3D 웨이브·보스 씬의 독립 로드, UI 화면과 플레이 공간의 분리, 도메인 코드의 2D·3D 노드 타입 비의존, Web 내보내기
- 승인 기록: 2026-07-27 사용자가 마스터 계획과 1단계 구현을 승인함.

## DEC-20260728-02 — 2D 목업과 2D·3D 교체 가능 보드 채택

- 상태: approved
- 요청자: 사용자
- 변경 전: 플레이 공간은 `Node3D` 목업으로 고정하고 2D는 미래 별도 어댑터 후보로만 두었다. 일반 웨이브 수는 코드 상수 3으로 고정했고 단계마다 Web export·Chromium 검증을 수행했다.
- 변경 후: 최종 2D·3D 그래픽은 미확정으로 유지하고 현재 목업은 `Node2D`로 제공한다. 보드 데이터와 진행 도메인은 차원에 의존하지 않으며 2D·3D 표현 어댑터가 같은 설정을 소비한다. 레퍼런스의 상단이 좁고 하단이 넓은 경사 원근을 기본 58° 시점으로 사용한다. 보드 시점과 웨이브 수는 `.tres`에서 수정·커스텀·테스트한다. 단계별 Web 빌드 검증은 생략하고 Web 최종 QA 또는 사용자 명시 요청 때만 수행한다.
- 변경 이유: 그래픽 차원을 성급히 고정하지 않고 2D 목업으로 빠르게 검증하면서, 반복 조정이 필요한 시점·콘텐츠 수치를 코드 변경 없이 비교하기 위해서다.
- 영향받는 기능: 루트 기준, `app/`, `game_flow/`, `stages/`, `presentation/`, `integration/`
- 갱신 문서: `AGENTS.md`, `GAME_TERMS.md`, `GROUND_RULES.md`, `app/SPEC.md`, `game_flow/SPEC.md`, `integration/.work/basic-system-foundation/PLAN.md`
- 검증 기준: 기본 `.tres` 로드, 보드 각도 변경 시 2D 목업 형상 변화, 웨이브 수 변경 시 보스 진입 시점 변화, 도메인·보드 데이터의 2D·3D 노드 비의존, Godot 프로젝트·Desktop 실행
- 승인 기록: 2026-07-28 사용자가 첨부 핀볼 레퍼런스와 함께 다섯 변경 사항을 명시하고 현재 구현과 후속 단계 계획에 적용하도록 요청함.

## DEC-20260728-03 — 기획자용 보드 제작 도구와 배치 계층 분리

- 상태: approved
- 요청자: 사용자
- 변경 전: 기획자는 `.tres` 인스펙터 배열에서 보드 외곽선과 앵커 좌표를 직접 입력하며, 배치 지점과 실제 오브젝트 원형이 연결되지 않았다. 보드 목업은 범퍼·플리퍼·유물 슬롯과 공을 코드로 직접 그렸다.
- 변경 후: 기획자는 Godot 2D 제작 화면에서 보드 외곽선 정점, 배치 지점과 플리퍼를 마우스로 이동한다. 보드 템플릿은 외곽선과 빈 배치 지점을, 웨이브 배치는 지점과 오브젝트 원형의 연결을, 각 기능은 범퍼·플리퍼·유물 원형을 소유한다. 오브젝트 원형의 규칙 데이터와 현재 2D 디자인·미래 3D 디자인을 분리한다. 플리퍼는 웨이브마다 1~4개를 외곽선에 부착한다. 공은 보드 설정과 편집 미리보기에서 제외하고 발사 지점만 남긴다.
- 변경 이유: Godot·GDScript·좌표 체계를 모르는 비개발자도 보드를 복제하고 마우스로 구성하며, 같은 보드 형태에 서로 다른 웨이브 콘텐츠와 디자인을 안전하게 적용할 수 있게 하기 위해서다.
- 영향받는 기능: `stages/boards`, `stages/waves`, `pinball/objects`, `pinball/flippers`, `relics/catalog`, `integration`, Godot 편집기 플러그인
- 갱신 문서: `GAME_TERMS.md`, `stages/boards/SPEC.md`, `stages/waves/SPEC.md`, `pinball/objects/SPEC.md`, `pinball/flippers/SPEC.md`, `relics/catalog/SPEC.md`, `integration/.work/basic-system-foundation/PLAN.md`, `integration/.work/basic-system-foundation/QA.md`
- 검증 기준: GDScript·파일 직접 편집·좌표 계산 없이 보드 복제→외곽선 편집→지점 추가·이동→원형 지정·교체→플리퍼 1~4개 외곽선 이동→저장·실행 확인, Undo/Redo, 한국어 오류 안내, 공 참조 부재, 차원 독립 계약, 기존 진행 회귀
- 승인 기록: 2026-07-28 사용자가 여덟 가지 제작 요구를 제시하고 3B-1~7 전체 구현, 서브 에이전트 활용, 독립 QA와 지정 Confluence 가이드 갱신을 승인함.

## DEC-20260729-01 — 차원 독립 발사 명령과 교체 가능한 조준 방식

- 상태: approved
- 요청자: 사용자
- 변경 전: 4단계는 단일 표준 공과 조준·발사 반복만 계획했으며 공 목록 수량, 상태별 키 입력, 조준 장치 교체와 미래 3D 물리 연결 방식이 확정되지 않았다.
- 변경 후: 목업 웨이브는 공 1~3개를 가져가며 `1`·`2`·`3` 또는 방향키로 남은 공을 선택한다. `Space`로 선택을 확정하고, `.tres` 설정에서 `방향키 조준`과 `마우스 조준` 중 하나를 선택한 뒤 `Space`로 발사한다. 공 진행 중에는 방향키가 보드 상대 위치에 따라 고유 지정된 플리퍼를 선택하고 `Space`가 선택 플리퍼를 작동한다. 발사 명령은 차원 독립 보드 평면의 방향·세기를 전달하며 현재 `RigidBody2D`와 미래 `RigidBody3D`는 별도 물리 어댑터 전략으로 소비한다. 내부 GDScript·`.tres` 속성명은 영문으로 유지하고 Godot 인스펙터와 미래 개발자 모드에는 한국어 이름·설명·단위를 표시한다.
- 변경 이유: 동일한 키를 공 선택·조준·발사·플리퍼 조작에 안전하게 재사용하고, 기획자가 입력 방식과 물리 수치를 코드 없이 비교하면서 최종 2D·3D 방향을 미확정으로 유지하기 위해서다.
- 영향받는 기능: `pinball/ball`, `pinball/launcher`, `pinball/shot`, `pinball/flippers`, `stages/boards`, `ui/gameplay`, `shared/contracts`, Godot 편집기 플러그인, `integration`
- 갱신 문서: `GROUND_RULES.md`, `GAME_TERMS.md`, `pinball/ball/SPEC.md`, `pinball/launcher/SPEC.md`, `pinball/shot/SPEC.md`, `pinball/flippers/SPEC.md`, `stages/boards/SPEC.md`, `integration/.work/basic-system-foundation/PLAN.md`, `integration/.work/basic-system-foundation/QA.md`
- 검증 기준: 공 목록 1~3개, 숫자·방향키 선택 일치, 두 조준 방식의 동일 발사 명령, 상태별 `Space` 중복 없음, 활성 공 0/1, 낙하 결과 1회, 플리퍼 방향 중복 거부, 2D 어댑터 외 차원 노드 역참조 없음, 인스펙터 한국어 표시와 영문 직렬화 속성 보존
- 승인 기록: 2026-07-29 사용자가 두 조준 방식을 설정으로 교체 가능하게 하고 나머지 확정 계획대로 3B 보완과 4단계를 진행하도록 승인함.
