---
title: generation tools 에이전트 규칙
summary: 승인된 스키마와 시드를 사용하는 AI·규칙 기반 콘텐츠 초안 생성 도구를 관리한다.
document_type: agent-policy
scope: tools/generation
status: active
read_when:
  - 보드, 카드, 유물, 테스트 또는 문서 생성 자동화를 만들 때
---

# generation tools 에이전트 규칙

- 생성 목적, 입력 스키마, 출력 스키마, 시드와 성공·중단 조건을 먼저 정의한다.
- 생성물은 초안 상태와 생성 메타데이터를 가지며 사용자 승인 없이 SPEC이나 확정 데이터가 되지 않는다.
- 미확정 `D-01`~`D-09`를 임의 값으로 영구 고정하지 않는다.
- 기존 파일 덮어쓰기 전 차이와 검증 결과를 미리보기로 제공한다.
- 같은 입력·시드 재현, 잘못된 참조, 범위 밖 수치와 편향된 결과 분포를 검증한다.

