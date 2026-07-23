---
name: pinball-logue-implement-step
description: Implement exactly the user-approved Pinball_Logue plan step, preserve unrelated changes, update documentation first when design changes, run planned self-validation, and record daily evidence. Use after a PLAN step has explicit user approval and code, data, scene, UI, or local documentation must be changed.
---

# Implement an Approved Step

1. Confirm the exact approved PLAN step and stop if approval or scope is ambiguous.
2. Read root and target `AGENTS.md`, relevant SPEC and DECISIONS, the active PLAN, and related QA criteria.
3. Inspect Git status and preserve unrelated or user-owned changes.
4. If approved behavior changed, update SPEC and decision records before implementation.
5. Implement only the approved step through the feature’s public boundaries.
6. Run the step’s normal, failure, boundary, regression, Godot, and Web checks as applicable.
7. On failure or scope conflict, stop implementation, record the problem, and return to planning.
8. Update PLAN status and `.work/<task>/daily/YYYY-MM-DD.md` from the daily template with exact results and evidence.
9. Report changed files, commands, measured results, warnings, and remaining risk; wait for user feedback before the next unapproved step.

Do not commit, push, create issues, or publish reports without separate user approval.

