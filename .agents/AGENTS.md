---
title: 프로젝트 에이전트 자원 규칙
summary: Pinball_Logue 작업자 역할, 전용 스킬, 기록 템플릿과 사용자 가이드의 라우팅을 정의한다.
document_type: agent-policy
scope: agent-resources
status: active
read_when:
  - 작업 계획·구현·QA 역할을 선택할 때
  - 프로젝트 스킬이나 템플릿을 추가·변경할 때
---

# 프로젝트 에이전트 자원 규칙

## 역할과 스킬

| 작업자 | 스킬 | 완료 조건 |
| --- | --- | --- |
| 작업 조정자 | `skills/pinball-logue-plan-work/SKILL.md` | 영향·단계·검증·미확정 사항을 기록하고 사용자 승인 대기 |
| 구현자 | `skills/pinball-logue-implement-step/SKILL.md` | 승인된 한 단계 구현, 자체 검증과 일자 기록 완료 |
| 전문 QA | `skills/pinball-logue-verify-qa/SKILL.md` | 독립 QA, 증거·버그·재검증 결과 보고 완료 |

- 한 에이전트가 여러 역할을 수행해도 각 역할의 시작 조건과 결과물을 섞지 않는다.
- 계획 승인 전에는 구현자 역할로 넘어가지 않는다.
- 구현자의 자체 검증과 전문 QA의 독립 검증을 별개로 기록한다.
- Jira, Confluence, Git 작업은 각 절차의 사용자 승인을 별도로 받는다.

## 템플릿 라우팅

| 템플릿 | 사용 시점 |
| --- | --- |
| `templates/SPEC_TEMPLATE.md` | 첫 세부 기획 승인 |
| `templates/DECISIONS_TEMPLATE.md` | 중요한 기획 변경 승인 |
| `templates/PLAN_TEMPLATE.md` | 실제 작업 계획 시작 |
| `templates/QA_TEMPLATE.md` | 최종·전문 QA 인수 준비 |
| `templates/HANDOFF_TEMPLATE.md` | 작업자 교체 또는 PR 인수인계 |
| `templates/DAILY_TEMPLATE.md` | 구현·검증을 수행한 날짜 |

템플릿을 대상 기능에 복사한 뒤 대상 경로, 작업 ID와 기준을 채운다. 빈 예시를 완료 기록처럼 남기지 않는다.

## 스킬 작성 규칙

- `SKILL.md` YAML은 `name`, `description`만 사용한다.
- 본문은 필수 절차만 유지하고 상세 기획은 루트 및 기능 문서를 참조한다.
- 스킬 이름과 폴더는 소문자·숫자·하이픈만 사용한다.
- 변경 후 각 스킬을 공식 빠른 검증기로 검사한다.

