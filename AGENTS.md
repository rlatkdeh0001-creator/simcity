# Project skills

## Asset pricing proposals (user requirement, 2026-11-02)

For every newly created asset, propose a construction price and recurring upkeep
in doth, with units, rationale, comparable assets and effect on the 50,000 doth
normal starting budget. Record proposals in `docs/PRICE_PROPOSALS_KO.md` (or a
linked asset proposal). Mark them proposed until the user approves; do not turn
a proposal into live charges without approval. Residential/commercial/industrial
zoning and automatic building construction have no municipal construction fee.
The confirmed design is drag-painted zones with automatic development; distinguish
this rule from the current click-placement/manual-growth prototype.
Also propose capacity/production/throughput, explicit time units, rated versus
average output, own resource demand, bottlenecks and residual outputs; consult
`docs/CAPACITY_PROPOSALS_KO.md`. Storage is not production. Do not count serial
network segment capacities additively or treat all proposed balance values as approved.

## Persistent skill handoff (user requirement)

At the start of every resumed/new session, read `docs/SKILL_HANDOFF_KO.md` and
check the actual checkout, Git status, and referenced evidence before continuing.
This register records installed skills, applied techniques, validation and limits;
it is not permanent model memory. Read the relevant SKILL.md before applying it.

Whenever introducing, adapting, applying, updating or validating a skill/tool,
update `docs/SKILL_HANDOFF_KO.md` in the same work: exact name/path, upstream URL
and pinned commit, license/NOTICE, actual use and affected files, commands/results,
unverified capabilities and next steps. Distinguish inherited evidence from tests
run in the current session. Preserve upstream files; record adaptations separately.
Do not invent missing skill names or call an addon a skill. Keep credentials out.
Commit and push the register with the related work within the user's authorized
scope. Report a failed push explicitly. Give this user GitHub links, not workspace
download links. Existing ZIPs are snapshots; current Git files are authoritative.

Use the existing /workspace/simcity checkout. Do not create a worktree unless requested.

Official Anthropic skills are installed in `.agents/skills/`. When a user names a skill or a task clearly matches one, read that skill's `SKILL.md` before applying it. Read linked resources only as needed. Resolve relative paths against the skill directory. Mention the selected skill briefly to the user. Follow user and platform instructions over skill instructions.

The skill catalog is in README.md. These are instructions for this agent, not a Claude CLI integration. Claude login is not required. Do not automatically run bundled scripts, install every skill dependency, enable external services, or spawn agents merely because files are present. Install only task-required dependencies and validate their operations. Some skill references mention Claude-specific tools; use available equivalent tools and explain unsupported capabilities.

Do not claim proprietary document skills are installed or that every skill runtime has been tested.
