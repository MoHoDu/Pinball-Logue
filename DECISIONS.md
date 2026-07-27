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

- 상태: approved
- 요청자: 사용자
- 변경 전: 임시 메인 씬은 `Node2D`이며 외부 조준·발사 상세안은 Physics2D 노드와 API를 전제로 했다.
- 변경 후: 현재 플레이 공간은 3D로 구현하고, 도메인 상태·명령·결과는 장면 차원과 분리한다. 메뉴 UI는 `Control`, 웨이브·보스 플레이 공간은 `Node3D`를 사용한다. 미래 2D 구현은 동일한 공개 계약을 사용하는 별도 어댑터로 교체할 수 있게 한다.
- 변경 이유: 현재 3D 플레이 요구를 충족하면서 이후 2D↔3D 전환 비용과 기능 간 결합을 제한하기 위해서다.
- 영향받는 기능: `app/`, `pinball/`, `stages/`, `ui/`, `presentation/`, `integration/`
- 갱신 문서: `app/SPEC.md`, `integration/.work/basic-system-foundation/PLAN.md`
- 검증 기준: 3D 웨이브·보스 씬의 독립 로드, UI 화면과 플레이 공간의 분리, 도메인 코드의 2D·3D 노드 타입 비의존, Web 내보내기
- 승인 기록: 2026-07-27 사용자가 마스터 계획과 1단계 구현을 승인함.
