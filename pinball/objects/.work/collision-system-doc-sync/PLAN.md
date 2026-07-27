---
title: 충돌 시스템 로컬 문서 동기화 계획
summary: 사용자 지정 Confluence 충돌 시스템 기획을 로컬 SPEC과 표준 용어에 반영하기 위한 승인 전 계획이다.
document_type: work-plan
scope: pinball/objects
status: draft
read_when:
  - 충돌 시스템 기획 문서 동기화 작업을 승인하거나 이어서 수행할 때
---

# 작업 계획

- 작업 ID: `collision-system-doc-sync`
- 주 책임 기능: `pinball/objects`
- 상태: draft
- 사용자 지시: 지정한 Confluence `충돌 시스템` 페이지를 읽고 프로젝트 디렉토리의 충돌 시스템 문서를 갱신한다.
- 외부 기준: 사용자 지정 Confluence `충돌 시스템` v22, 2026-07-27 갱신본
- 관련 SPEC·결정·GR: 신규 `pinball/objects/SPEC.md`; GR-01~06, GR-15~17, GR-20, GR-29, GR-36, GR-38; D-02, D-07
- 승인 범위: 충돌·타격·범퍼 타입·상태·안전 복구·목업 검증 기준을 로컬 문서에 반영한다.
- 제외 범위: 코드·씬·리소스 구현, 물리 수치 확정, 스코어 계산식 확정, Jira·Confluence 쓰기, Git 작업

## 영향 범위

- `pinball/objects/SPEC.md`: 첫 세부 기획 문서로 생성한다.
- `GAME_TERMS.md`: 접촉, 타격, 지속 접촉, 효과 제어와 분리의 표준 정의를 추가한다.
- `pinball/objects/.work/collision-system-doc-sync/PLAN.md`: 승인 상태와 사용자 피드백을 기록한다.
- `pinball/objects/AGENTS.md`, `pinball/ball/AGENTS.md`, `pinball/flippers/AGENTS.md`, `pinball/scoring/AGENTS.md`: 책임 경계 대조 대상으로만 사용하며 현재 규칙과 충돌하지 않으면 수정하지 않는다.
- 기존 사용자 변경인 `example_2d.tscn`은 읽거나 수정하지 않는다.

## 단계와 단계별 검증

| 단계 | 작업 | 검증 | 상태 |
| --- | --- | --- | --- |
| 1 | `pinball/objects/SPEC.md`를 템플릿에서 생성하고 목적·범위, 오브젝트 역할표, Normal/Bounce/Track/Shot 범퍼, 충돌과 타격 분리, 경로 Shape 선행 검사와 기본 접촉, 공·범퍼 상태, 안전 복구를 기록한다. | Confluence v22의 각 확정 규칙이 한 번씩 반영됐는지 대조하고 `objects`가 최종 스코어·UI·스테이지 배치를 소유하지 않는지 확인한다. | pending |
| 2 | 목업 후보값과 확정 규칙을 분리하고 `GAME_TERMS.md`의 점수와 충돌 절에 새 표준 용어를 추가한다. | 22px±10px, 4~8px, 복구 3/4/5초, 성공률·반복 횟수·주관 평가 기준이 확정값이 아닌 후보·검증값으로 표시됐는지 확인한다. | pending |
| 3 | 문서 간 일관성과 미확정 사항을 검증하고 계획 상태를 갱신한다. | YAML 프론트매터, 표준 표현, GR 참조, 외부 링크 미보관, 코드·씬 무변경, `git diff --check`를 확인한다. | pending |

## 최종 검증 흐름

1. 제공된 Confluence v22의 절별 요구사항과 신규 SPEC의 대응 절을 대조한다.
2. `GAME_TERMS.md`와 SPEC에서 같은 용어가 같은 의미로 사용되는지 확인한다.
3. 기존 기능 경계를 대조해 물리 오브젝트, 공 상태, 플리퍼 타격, 스코어 계산의 소유권이 뒤섞이지 않았는지 확인한다.
4. `rg`로 후보값과 미확정 표현을 찾아 확정 규칙처럼 서술되지 않았는지 검토한다.
5. `git diff --check`와 `git status --short`로 문서 형식과 변경 파일 범위를 확인한다.

## 미확정 사항과 가정

- `Normal`을 `BumperType` 열거형에 포함할지, 특수 반응이 없는 공통 기본 동작으로 둘지는 원문 표와 예시 코드가 일치하지 않아 미확정으로 남긴다.
- 범퍼 생명주기의 `DESTROYED`·`RESPAWN_TIMER`와 `DESTROYED_TIMER` 표기 통합은 구현 전 결정이 필요하다.
- 한 타격에서 범퍼 효과, 스코어, 콤보와 내구도를 적용하는 정확한 순서는 미확정이다.
- 여러 범퍼에 거의 동시에 충돌할 때 동일 시점 묶음과 처리 우선순위는 미확정이다.
- 충돌 반지름, 안전 여백, 최대 속도, 복구·유예·예고 시간과 확률 기준은 목업 후보값이며 측정 전 최종값으로 확정하지 않는다.
- 코인의 구매 용도, 공 수량·초기화 범위와 공격력 패시브 적용 대상은 각각 기존 보상 문서, D-02와 D-07의 소유 범위로 남긴다.

## 사용자 피드백 기록

- 2026-07-27: 지정 Confluence 페이지를 읽고 로컬 문서 갱신을 요청받음. 계획 승인 대기.
