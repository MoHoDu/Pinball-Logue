---
title: Pinball_Logue
summary: NAN AI 해커톤 사전 과제용 핀볼 로그라이트 프로젝트의 사람 대상 개요와 로컬 기준 문서 목록이다.
document_type: project-overview
scope: repository
status: active
read_when:
  - 프로젝트 소개 또는 온보딩 정보를 확인할 때
---

# Pinball_Logue

NAN AI 해커톤 사전 과제 제출을 위한 다각형 외곽 플리퍼 보드 기반 핀볼 로그라이트 게임 프로젝트입니다.

## 프로젝트 기준 문서

- [에이전트 작업 규칙](AGENTS.md)
- [게임 표준 용어](GAME_TERMS.md)
- [게임 그라운드룰 및 QA 기준](GROUND_RULES.md)
- [작업·기획 변경·인수인계 규약](WORKFLOW.md)
- [바이브 코딩 사용자 가이드](.agents/VIBE_CODING_GUIDE.md)
- [프로젝트 작업자·스킬·템플릿 안내](.agents/AGENTS.md)

## 기능 디렉토리

| 경로 | 책임 |
| --- | --- |
| `app/` | 시작, 기능 조립과 화면 전환 |
| `game_flow/` | 런·스테이지·웨이브 진행 상태 |
| `pinball/` | 공, 발사, 플리퍼, 충돌과 스코어링 |
| `stages/` | 보드, 목표, 일반·보스 웨이브 콘텐츠 |
| `relics/` | 유물 보유, 배치, 발동과 위치 기반 효과 |
| `rewards/` | 카드 제안, 코인, 구매와 패시브 |
| `ui/` | 로비·준비·플레이·보상·결과 화면 |
| `presentation/` | 카메라, 시각효과, 음향과 타격 피드백 |
| `shared/` | 둘 이상의 기능이 공유하는 중립 계약 |
| `integration/` | 전체 시나리오, 회귀와 전문 QA |
| `tools/` | 생성·검증·증거·보고 자동화 |

각 디렉토리의 작업자는 루트부터 대상까지의 `AGENTS.md`를 순서대로 읽습니다. 세부 기획은 승인 시 해당 기능의 `SPEC.md`로, 작업 상태와 QA 증거는 해당 기능의 `.work/`로 추가합니다.

## 협업 시작

1. 사용자는 원하는 결과와 변경 이유를 설명합니다.
2. 작업 조정자는 로컬 문서를 기준으로 단계와 검증 계획을 제시합니다.
3. 사용자가 승인한 단계만 구현하고 자체 검증합니다.
4. 전체 구현 뒤 전문 QA가 독립 검증하고 결과를 로컬 Markdown에 기록합니다.
5. Jira, Confluence와 Git 작업은 각각 사용자 승인 후 수행합니다.
