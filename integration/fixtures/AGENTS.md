---
title: integration fixtures 에이전트 규칙
summary: 보드, 입력, 랜덤 시드와 시작 상태를 고정해 기능 간 문제를 반복 재현하는 데이터를 관리한다.
document_type: agent-policy
scope: integration/fixtures
status: active
read_when:
  - 통합 테스트 데이터나 버그 재현 상태를 만들 때
---

# integration fixtures 에이전트 규칙

- 픽스처는 목적, Godot·데이터 버전, 시작 상태, 시드와 기대 종료 상태를 명시한다.
- 제품 데이터와 구분되는 이름과 경로를 사용하고 Web 제품 내보내기에는 포함하지 않는다.
- 실제 계약과 유효성 검사를 우회하지 않으며 불가능한 상태는 오류 검사용으로 표시한다.
- 개인 경로, 외부 링크와 민감한 데이터를 포함하지 않는다.
- 같은 픽스처 반복 실행의 결과 편차와 오래된 참조를 검증한다.

