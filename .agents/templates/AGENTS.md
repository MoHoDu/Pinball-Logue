---
title: 작업 문서 템플릿 규칙
summary: 기능별 SPEC, 결정, 계획, QA, 인수인계와 일자 기록 템플릿의 사용 원칙을 정의한다.
document_type: agent-policy
scope: agent-templates
status: active
read_when:
  - 작업 문서를 템플릿에서 생성하거나 템플릿을 변경할 때
---

# 작업 문서 템플릿 규칙

- 대상 기능의 `AGENTS.md`와 `WORKFLOW.md`를 읽고 필요한 템플릿만 복사한다.
- 복사본의 YAML과 본문에 대상 기능, 작업 ID, 날짜와 상태를 실제 값으로 바꾼다.
- 해당하지 않는 항목은 삭제보다 `해당 없음`과 이유를 기록한다.
- 측정하지 않은 값은 `미측정`, 실행하지 않은 검증은 `미검증`으로 쓴다.
- 템플릿 자체를 작업 완료 증거로 사용하지 않는다.

