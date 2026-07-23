---
name: pinball-logue-verify-qa
description: Independently verify completed Pinball_Logue work against local specifications, GR acceptance criteria, QA lists, gameplay invariants, and Godot/Web requirements while recording reproducible evidence and bug follow-up. Use when implementation is ready for professional QA, regression, release checks, or bug re-verification.
---

# Verify Pinball_Logue Independently

1. Read root and target rules, SPEC, decisions, active PLAN, `integration/qa/AGENTS.md`, and the handed-off QA list.
2. Confirm branch or commit, Godot version, platform, viewport, inputs, seed, runs, and evidence path.
3. Verify normal, failure, boundary, regression, Godot, and Web cases independently of implementer conclusions.
4. Record each item as `통과`, `수정`, or `재검증` with expected result, actual result, measurements, and evidence.
5. Mark unmeasured values `미측정` and unexecuted cases `미검증`.
6. Record found bugs as `untracked` in QA and daily records, then report them to the user in the session.
7. Ask before creating a Jira `버그`; if approved, link it in PLAN and add a re-verification item.
8. Complete the daily Markdown with implementation result, troubleshooting, user-driven improvements, evidence, and remaining risk.
9. Ask whether to publish to Confluence; update only the user-approved page.

Do not change product behavior while acting as independent QA unless the user separately approves a fix step.

