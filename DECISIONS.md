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
