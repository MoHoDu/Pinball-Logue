---
title: integration regression 에이전트 규칙
summary: 기능 변경의 직접 영향과 핵심 게임 불변 규칙을 반복 검증하는 회귀 묶음을 관리한다.
document_type: agent-policy
scope: integration/regression
status: active
read_when:
  - 회귀 테스트 범위를 추가·변경하거나 실행할 때
---

# integration regression 에이전트 규칙

- 빠른 필수 묶음과 전체 묶음을 구분하고 각 항목의 예상 시간과 환경을 기록한다.
- 모든 변경에서 단일 공, 진행 순서, 구매 원자성, 배치·발동 정합성과 Web 빌드를 빠른 묶음에 포함한다.
- 물리 변경은 터널링, 끼임, 무한 반복, 과속, 플리퍼 관통과 필승 조합을 포함한다.
- 실패 결과에는 최초 실패, 재현 횟수, 로그와 영향 기능을 기록한다.
- 불안정 테스트를 통과로 취급하지 않고 시드·타이밍·환경 원인을 분리한다.

