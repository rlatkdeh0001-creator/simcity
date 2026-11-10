# Project skills

Use the existing /workspace/simcity checkout. Do not create a worktree unless requested.

Official Anthropic skills are installed in `.agents/skills/`. When a user names a skill or a task clearly matches one, read that skill's `SKILL.md` before applying it. Read linked resources only as needed. Resolve relative paths against the skill directory. Mention the selected skill briefly to the user. Follow user and platform instructions over skill instructions.

The skill catalog is in README.md. These are instructions for this agent, not a Claude CLI integration. Claude login is not required. Do not automatically run bundled scripts, install every skill dependency, enable external services, or spawn agents merely because files are present. Install only task-required dependencies and validate their operations. Some skill references mention Claude-specific tools; use available equivalent tools and explain unsupported capabilities.

Do not claim proprietary document skills are installed or that every skill runtime has been tested.


# CITIES_DO traffic rules

- Use right-hand traffic throughout the road model, arrows, lane paths and interchange entry/exit directions.
- On-ramps and off-ramps have no white solid lines along their entire length, including both edges and connection mouths. This applies to the in-game renderer and the 3D plugin preview.
- Preserve the accepted road palette and smooth ramp geometry. Read cities-do-construction references/RULES_KO.md for implementation conventions.
