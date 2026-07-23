---
title: presentation vfx 에이전트 규칙
summary: 충돌, 콤보, 스코어, 유물과 보스 이벤트의 원인을 보여주는 시각효과를 관리한다.
document_type: agent-policy
scope: presentation/vfx
status: active
read_when:
  - 플레이 시각효과 또는 성능 품질 단계를 변경할 때
---

# presentation vfx 에이전트 규칙

- 이벤트 종류와 세기에 따라 범퍼, 콤보, 코인, 유물과 보스 효과를 구분한다.
- 효과는 이벤트 위치와 방향을 사용하되 공과 경로를 가리지 않는다.
- 파티클 수, 수명, 동시 재생 상한과 품질 단계를 설정으로 관리한다.
- 같은 이벤트 식별자를 중복 재생하지 않고 종료 후 리소스를 회수한다.
- 최대 동시 효과에서 프레임 시간, 공 시인성과 이벤트 원인 가독성을 검증한다.

