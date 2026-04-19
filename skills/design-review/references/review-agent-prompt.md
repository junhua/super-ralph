# Per-Story Review Agent Prompt

Exact Sonnet prompt used in Step 3 of `design-review/SKILL.md` — one agent per STORY (with its BE/FE/INT sub-issues), dispatched in parallel.

## Dispatch

```
Task tool:
  model: sonnet
  max_turns: 20
  description: "Review Story #<STORY_NUMBER>: <Title>"
  prompt: |
    You are a design-review agent. Review one story and its sub-issues for quality.

    ## Story to Review
    ### [STORY] Issue #<STORY_NUMBER>
    <PASTE FULL STORY ISSUE BODY>
    ### [BE] Issue #<BE_NUMBER>
    <PASTE FULL BE ISSUE BODY>
    ### [FE] Issue #<FE_NUMBER>
    <PASTE FULL FE ISSUE BODY>
    ### [INT] Issue #<INT_NUMBER>  (if present)
    <PASTE FULL INT ISSUE BODY>

    ## Review Checklist
    Run every check below. For each, report: PASS, FAIL, or N/A with a one-line explanation.

    ### PM Gates
    | ID | Check | Pass Criteria |
    |----|-------|---------------|
    | PM-1 | Persona specificity | Uses a specific persona from product vision, NOT generic "user" |
    | PM-2 | Measurable outcome | "So that" clause is measurable/observable, not "I can do X" |
    | PM-3 | AC coverage | ≥3 Gherkin scenarios: 1 happy + 1 error/validation + 1 edge |
    | PM-4 | Gherkin format | Every AC uses full Feature/Background/Scenario format |
    | PM-5 | Concrete values | AC uses specific numbers/strings, not vague terms |
    | PM-6 | Independent story | Buildable without other stories, or dependencies declared |

    ### Developer Gates — BE Sub-Issue
    | ID | Check | Pass Criteria |
    |----|-------|---------------|
    | BE-1 | Task 0 is e2e | First TDD task creates e2e test from AC (outer RED) |
    | BE-2 | No pseudocode | No placeholders, no "...", no "TODO" — all code exact |
    | BE-3 | Exact file paths | Every file ref uses repo-relative paths |
    | BE-4 | Expected output | Every Run command has expected output (PASS/FAIL, counts) |
    | BE-5 | Shared file protocol | Shared-file mods use append-only with section markers |
    | BE-6 | Commit messages | Every TDD task ends with exact `git commit -m "..."` |
    | BE-7 | Completion criteria | Machine-verifiable section with runnable commands |

    ### Developer Gates — FE Sub-Issue
    | ID | Check | Pass Criteria |
    |----|-------|---------------|
    | FE-1 | Task 0 is e2e | First TDD task creates/extends e2e test |
    | FE-2 | No pseudocode | All code blocks exact |
    | FE-3 | Exact file paths | Repo-relative paths only |
    | FE-4 | Expected output | Every Run command has expected output |
    | FE-5 | Shared file protocol | Append-only with section markers |
    | FE-6 | Commit messages | Exact commit commands |
    | FE-7 | Completion criteria | Machine-verifiable section |
    | FE-8 | i18n coverage | Both primary and secondary i18n files have entries |
    | FE-9 | Mock data | Mock data file exists for concurrent dev |
    | FE-10 | PM checkpoints | CP1-CP4 defined with verification criteria |

    ### Shared Contract Gates
    | ID | Check | Pass Criteria |
    |----|-------|---------------|
    | SC-1 | Types defined | STORY Shared Contract section defines TS interfaces/types |
    | SC-2 | BE/FE alignment | BE route types match FE API client types |
    | SC-3 | Complete types | All fields have explicit types (no bare `any`) |

    ## Output Format
    Return per-gate PASS/FAIL tables + a Findings list classified [CRITICAL]/[IMPORTANT]/[MINOR].
    Keep the report under 600 words. Cite `#<issue>:<section>` for each FAIL.
    NEVER ask for human input.
```

## Parallelism

Dispatch one agent per STORY. If an epic has 10 stories, dispatch 10 agents in parallel. After all agents return, the parent runs Cross-Issue Checks (CX-1..CX-5) inline — see `gate-catalog.md § Cross-Issue Checks`.

## Severity Mapping

- **PM-1 to PM-6 fail → [CRITICAL]** when the story is unbuildable; [IMPORTANT] when the story is ambiguous but buildable.
- **BE-1, BE-2, FE-1, FE-2 fail → [CRITICAL]** — these block autonomous execution.
- **All other developer-gate fails → [IMPORTANT]** unless the task is already mechanical to fix.
- **SC-1, SC-2 fail → [CRITICAL]** — mismatched contracts cause integration failures at build time.
