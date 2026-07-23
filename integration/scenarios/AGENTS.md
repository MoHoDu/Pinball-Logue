---
title: integration scenarios 에이전트 규칙
summary: 실제 사용자 관점의 전체 정상·실패·재시도 흐름과 기대 결과를 관리한다.
document_type: agent-policy
scope: integration/scenarios
status: active
read_when:
  - 전체 플레이 시나리오 또는 기능 간 인수 기준을 작성할 때
---

# integration scenarios 에이전트 규칙

- 각 시나리오는 사전 상태, 사용자 행동, 관찰 지점, 기대 결과와 관련 GR ID를 포함한다.
- 정상 흐름뿐 아니라 입력 연타, 잔액 부족, 중복 이벤트, 낙하와 리트라이를 포함한다.
- 화면 이름 대신 사용자 행동과 공개 상태로 단계를 표현하되 실제 UI 표준 용어를 유지한다.
- 시나리오 하나가 실패하면 최초 불일치 기능과 재현 가능한 최소 단계를 기록한다.
- 최소 전체 스테이지 정상 흐름과 각 주요 단계의 실패·재시도 흐름을 유지한다.

