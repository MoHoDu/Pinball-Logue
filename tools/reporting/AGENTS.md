---
title: reporting tools 에이전트 규칙
summary: 검증 결과와 증거를 로컬 QA·일자별 Markdown 형식으로 구성하는 보고 자동화를 관리한다.
document_type: agent-policy
scope: tools/reporting
status: active
read_when:
  - QA, 일자별 기록 또는 외부 게시용 보고 자동화를 만들 때
---

# reporting tools 에이전트 규칙

- 원본 로그와 측정 결과를 보존하고 보고서에는 출처 파일과 조건을 연결한다.
- 구현 내용, 구현 결과, 트러블슈팅, 사용자 변경으로 개선된 점, 증거와 남은 위험을 포함한다.
- 누락된 값은 추정하지 않고 `미측정` 또는 `미검증`으로 표시한다.
- 로컬 Markdown 생성까지만 자동 수행하며 Jira·Confluence 게시와 외부 메시지는 사용자 승인 후 실행한다.
- 같은 입력에서 항목 누락 없이 재생성되고 사람이 작성한 부분을 덮어쓰지 않는지 검증한다.

