---
name: pinball-logue-plan-work
description: Plan and coordinate Pinball_Logue feature work using local repository rules, approval gates, documentation-first changes, validation criteria, and handoff records. Use when a user requests a new feature, design change, bug plan, experiment, task breakdown, or implementation plan before code changes.
---

# Plan Pinball_Logue Work

1. Read the user’s latest instruction, root `AGENTS.md`, target-directory `AGENTS.md`, and routed local documents.
2. Do not open external sources unless the current request explicitly supplies and authorizes them.
3. Inspect the target directory, current implementation, active `.work/` records, and local issue references.
4. Classify the request as clarification, feature change, global change, or experiment using `WORKFLOW.md`.
5. Identify affected features, files, UI, data, QA, relevant GR IDs, and unresolved `D-01`–`D-09` items.
6. Create or update the target `.work/<task>/PLAN.md` from `.agents/templates/PLAN_TEMPLATE.md`.
7. Define ordered steps, per-step validation, final QA flow, exclusions, assumptions, and rollback or stop conditions.
8. Present the plan to the user and wait for explicit approval before implementation.
9. If rejected or revised, record the feedback, update the plan, and request approval again.

Do not implement, commit, publish externally, or silently resolve missing design decisions while acting as the planner.

