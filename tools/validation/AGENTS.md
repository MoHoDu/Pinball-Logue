---
title: validation tools 에이전트 규칙
summary: 문서, 의존성, Godot 프로젝트, Web 내보내기와 게임 데이터의 반복 검증 도구를 관리한다.
document_type: agent-policy
scope: tools/validation
status: active
read_when:
  - 정적 검사, 테스트 실행기 또는 빌드 검증 도구를 만들 때
---

# validation tools 에이전트 규칙

- 검증 도구는 변경보다 탐지와 명확한 종료 코드를 우선하고 자동 수정은 별도 승인 옵션으로 둔다.
- 검사 항목, 입력 경로, 제외 규칙, 기대 결과와 실패 메시지를 문서화한다.
- YAML 프론트매터, 외부 링크, 기능 의존성, Godot 로드, Web 내보내기와 문서 제외를 기본 검사로 유지한다.
- 실패 메시지는 파일, 항목, 실제값과 기대값을 포함하고 개인 절대 경로는 보고서에서 상대 경로로 바꾼다.
- 정상·오류 픽스처와 중단 시 종료 코드를 검증한다.

