## Code exploration

Use `ast-grep` for structural code searches. Use `rg` for literal text, identifiers, paths, and error messages. Use `ast-grep outline` when a file overview will help. Read only the context needed for the task.

## Task completion

For implementation requests, complete the authorized change and the relevant checks. Continue without approval for each routine step. Ask when missing information could materially change the result. For audit, review, or proposal requests, do not change files unless asked.

## Worktrees

Use Worktrunk (`wt`) for worktree management; consult the `worktrunk` skill before creating, switching, or removing worktrees.

## Code Quality Standards

- Write code for humans to read.
- Make minimal, surgical changes.

## Comments

- Default to no comment. Add one only when it records information the code cannot show: a reason, a constraint, a workaround, a link to an external bug or spec, or a non-obvious invariant that callers must keep.
- Never write a comment that restates what the code does, names what a field or variable holds, or describes the next line. If a reader can get the same information from names, types, or the code nearby, delete the comment.
- Do not add comments to test code, fixtures, or fakes unless the setup has a hidden reason.
- Before finishing, check each added comment: "If I delete this, does a reader lose information they cannot get from the code?" If the answer is no, delete it.
- If a comment seems necessary to explain _what_ code does, rename or restructure the code instead.

## Pull Request Preferences

Do not include tests, linting, type checks, or verification commands in PR descriptions unless explicitly requested.

## Diagrams

Include Mermaid diagrams in plan and design documents and PR descriptions whenever there is a systematic or mechanical aspect to explain.
Examples include component relationships, data and control flow, protocols, state transitions, and processing stages.
Show how the mechanism works, with clearly labeled participants, connections, and steps; choose the diagram type that best explains it.
Keep diagrams consistent with the accompanying prose and update them when the design or change evolves.
