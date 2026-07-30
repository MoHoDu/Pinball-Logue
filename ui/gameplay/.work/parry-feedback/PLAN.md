---
title: 웨이브 패링 텍스트 피드백 작업 계획
summary: 현재 발사의 패링 성공을 오른쪽 HUD에 0.4초 동안 표시하는 승인 구현 범위를 기록한다.
document_type: work-plan
scope: ui/gameplay
status: active
read_when:
  - 패링 텍스트 피드백을 구현하거나 검증할 때
---

# 웨이브 패링 텍스트 피드백 작업 계획

- 작업 ID: parry-feedback
- 주 책임 기능: `ui/gameplay`
- 상태: completed
- 사용자 지시: 현재 발사의 패링 성공 시 오른쪽 HUD에 `PARRY!`를 표시하고 마지막 패링부터 0.4초 뒤 숨긴다.
- 관련 SPEC·결정·GR: `ui/gameplay/SPEC.md`, GR-03, GR-04
- 승인 범위: 기존 `flipper_parry_applied` 신호 연결, 전용 라벨·타이머, 지연 신호 차단, 기존 테스트 보강
- 제외 범위: 물리·입력·발사·낙하·점수·아트·사운드·파티클·화면 흔들림과 전역 구조 변경

## 영향 범위

- `ui/gameplay/SPEC.md`
- `app/navigation/screens/wave_play_screen.gd`
- `app/navigation/screens/wave_screen.tscn`
- `integration/scenarios/flipper_physics_2d_smoke.gd`
- `integration/scenarios/wave_play_loop_smoke.gd`

## 단계와 단계별 검증

| 단계 | 작업 | 검증 | 상태 |
| --- | --- | --- | --- |
| 1 | 승인 UI 기준을 SPEC에 반영 | 승인 문구·시간·제외 범위 확인 | completed |
| 2 | 전용 라벨·타이머와 현재 발사 신호 연결 | 프로젝트 파싱, 현재·지연 발사 경계 | completed |
| 3 | 기존 패링·웨이브 테스트 보강 | 지정 스모크 테스트 4개 | completed |
| 4 | 최종 범위와 Git 상태 확인 | 허용 파일과 필수 기록 외 변경 없음 | completed |

## 최종 검증 흐름

1. Godot 4.7.1 헤드리스 프로젝트 파싱
2. `flipper_physics_2d_smoke.gd`
3. `wave_play_loop_smoke.gd`
4. `launch_shot_contract_smoke.gd`
5. `wave_input_router_smoke.gd`

## 미확정 사항과 가정

- 일반 패링과 정확한 패링은 구분하지 않는다.
- `action_id`와 `anchor_id`는 이번 UI에 표시하지 않는다.
- 1280×720 실제 HUD 배치 가독성은 수동 확인 대상으로 남긴다.

## 사용자 피드백 기록

- 2026-07-30: 사용자가 제안 계획을 승인하고 이 단계만 구현하도록 지시했다.
