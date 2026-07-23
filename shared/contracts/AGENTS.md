---
title: shared contracts 에이전트 규칙
summary: 기능 경계를 넘는 명령, 조회와 결과의 최소 인터페이스를 관리한다.
document_type: agent-policy
scope: shared/contracts
status: active
read_when:
  - 기능 사이 명령·결과 계약을 추가하거나 변경할 때
---

# shared contracts 에이전트 규칙

- 계약은 의도, 입력, 성공 결과와 실패 이유를 화면·장면·노드와 무관하게 표현한다.
- 호출자는 구현 내부가 아니라 계약에만 의존하고 구현 세부 타입을 노출하지 않는다.
- 재시도 가능한 명령은 요청 식별자와 멱등성 기대를 포함한다.
- 소유 기능, 소비 기능과 호환성 영향을 문서화하고 파괴적 변경은 통합 검증한다.
- 정상, 거부, 중복, 지연과 알 수 없는 버전 입력을 검증한다.

