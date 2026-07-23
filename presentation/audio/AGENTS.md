---
title: presentation audio 에이전트 규칙
summary: 충돌, 콤보, 코인, 유물, 보스와 UI 이벤트의 구분 가능한 음향 재생을 관리한다.
document_type: agent-policy
scope: presentation/audio
status: active
read_when:
  - 효과음, 배경음, 믹싱 또는 동시 재생 정책을 변경할 때
---

# presentation audio 에이전트 규칙

- 스코어 충돌, 코인 획득, 유물 발동과 보스 타격을 소리만으로도 구분 가능하게 한다.
- 버스, 음량, 피치 범위, 동시 재생 수와 우선순위를 설정으로 관리한다.
- 연쇄 충돌에서 음향이 잘리거나 과도하게 커지지 않도록 제한과 보이스 재사용을 적용한다.
- 게임 이벤트를 재생할 뿐 점수, 구매와 진행 상태를 변경하지 않는다.
- 무음·저음량에서도 필수 정보가 시각적으로 남는지 함께 확인한다.

