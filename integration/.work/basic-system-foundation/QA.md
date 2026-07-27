---
title: 기본 시스템 1단계 전문 QA 결과
summary: Godot 4.7.1 앱·화면 기반의 런타임, Web 내보내기, 브라우저 회귀와 한국어 글리프 수정 재검증 결과를 기록한다.
document_type: qa-handoff
scope: integration
status: passed
read_when:
  - 기본 시스템 1단계 통과 여부와 검증 증거를 확인할 때
  - Web 한국어 글리프 수정 결과를 재검증할 때
---

# QA 인수 및 결과

- 작업 ID: `basic-system-foundation` 1단계 및 1A QA 보완
- 기준 브랜치·커밋: `test/test-shot`, `5d97392` 기반 미커밋 작업 트리
- Godot·플랫폼·뷰포트: `4.7.1.stable.official.a13da4feb`, Windows, Chromium WebGL 2.0, 1280×720
- 입력·시드·실행 횟수: 헤드리스 화면 6개×3회; 브라우저 포인터 입력 전체 주기 1회; 랜덤 시드 해당 없음
- QA 담당: Codex 전문 QA·구현
- 수정 전 증거: `integration/.work/basic-system-foundation/evidence/web-browser/`
- 수정 후 증거: `integration/.work/basic-system-foundation/evidence/web-browser-after-pretendard/`

## 검증 목록

| ID | 유형 | 조건 | 기대 결과 | 실제 결과 | 상태 | 증거 |
| --- | --- | --- | --- | --- | --- | --- |
| QA-01 | 정상 | Godot 4.7.1 헤드리스 편집기 스캔 | 프로젝트와 신규 리소스가 오류 없이 로드된다. | Pretendard를 `FontFile`로 임포트했으며 종료 코드 0. | 통과 | 실행 로그 |
| QA-02 | 정상·경계 | 화면 6개를 3회 순환하고 현재 화면·알 수 없는 화면을 재요청 | 활성 화면은 항상 하나이며 거부된 요청이 현재 화면을 보존한다. | `SCENE_NAVIGATION_SMOKE: PASS`, 종료 코드 0. | 통과 | 실행 로그 |
| QA-03 | Web | 4.7.1 release Web export | HTML, JS, PCK와 WASM 산출물이 생성되고 폰트가 패키징된다. | 종료 코드 0, 필수 산출물 9개 생성. 폰트 `.fontdata`와 공용 Theme 패킹 확인. | 통과 | export 로그 |
| QA-04 | Web | Chromium에서 로컬 HTTP로 `index.html` 로드 | WASM·PCK가 로드되고 브라우저 콘솔 오류가 없다. | `.wasm`·`.pck` HTTP 200, 오류 0건·경고 0건. | 통과 | `browser-console.log` |
| QA-05 | 회귀 | 메인 로비→스테이지 선택→웨이브→보상→보스→결과→메인 로비 | 한 주기 전환과 3D 웨이브·보스 렌더링이 완료된다. | 1/1 주기 성공, 3D 플레이스홀더 정상 렌더링. | 통과 | `main-lobby-readable.png`, `wave-3d-readable.png`, `boss-3d-readable.png`, `main-lobby-after-cycle-readable.png` |
| QA-06 | UI 가독성 | Desktop과 Web의 한국어 제목·설명·버튼 확인 | 모든 한국어가 읽을 수 있는 글리프로 표시된다. | 공용 Theme의 Pretendard Regular로 여섯 화면의 현재 한국어가 네모 글리프 없이 표시된다. | 통과 | 수정 후 화면 캡처 전체 |
| QA-07 | 패키징 경계 | Web export 로그와 제외 필터 확인 | `integration/**`, `.agents/**`, `**/.work/**`가 제품 패키지에 포함되지 않는다. | 앱 리소스와 폰트·Theme만 추가 패킹됐고 검증·작업 문서는 패킹되지 않았다. | 통과 | export 로그, `export_presets.cfg` |

## 성능과 수치

- Web 산출물: `index.html` 5,443 bytes, `index.pck` 800,696 bytes, `index.js` 279,815 bytes, `index.wasm` 39,513,091 bytes.
- 폰트 적용 전 PCK 39,712 bytes 대비 760,984 bytes 증가했다.
- 브라우저 엔진: Chromium WebGL 2.0, Godot Compatibility renderer, Emscripten 4.0.20 single-threaded.
- 로드 시간, FPS와 메모리: 미측정. 1단계 최종 수용 기준에는 포함하지 않고 12단계 Web 최종 QA에서 측정한다.

## 발견 버그

### BUG-UNTRACKED-01 — Web에서 한국어가 네모 글리프로 표시됨

- 추적 상태: fixed-and-reverified
- 수정 전 재현율: 1/1 브라우저 실행, 모든 한국어 화면에서 확인
- 확정 원인: 제품에 한국어 글리프를 제공하는 번들 폰트와 공용 Theme가 없었다.
- 해결: `Pretendard-Regular.woff2`와 SIL OFL 1.1 전문을 제품 리소스에 포함하고 단일 공용 Theme를 여섯 화면에 적용했다.
- 재검증: Chromium 전체 주기 1/1에서 여섯 화면의 현재 한국어를 읽을 수 있었고 콘솔 오류·경고는 0건이었다.
- 수정 전 증거: `evidence/web-browser/`
- 수정 후 증거: `evidence/web-browser-after-pretendard/`
- Jira: 로컬에서 수정·재검증됐으며 사용자 요청이 없어 생성하지 않음

## 재검증과 남은 위험

- 1단계와 승인된 1A 보완의 정상·경계·회귀·Godot·Web 수용 기준은 모두 통과했다.
- 실제 Desktop 런타임도 종료 코드 0이며 Web과 동일한 번들 폰트를 사용한다.
- 로드 시간, FPS와 메모리는 아직 미측정이며 12단계 Web 최종 QA에서 검증한다.
- 2단계 진행 도메인은 아직 승인되지 않았으므로 시작하지 않는다.
