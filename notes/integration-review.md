# Harness fix and branch integration

November 5, 2026. Task branch: `codex/harness-and-branch-integration`.
Started from `a19b1a3`; lower-cost agents implemented the bounded harness work and
reviewed each branch. The lead reviewed the changes, handled state-policy
decisions, resolved integration conflicts, and ran emulator verification.

## Integrated work

- Harness fix: assertion failures now affect process status. Pact requires a
  resolved Pact in every requested battle and no unfinished Pact action. Call
  requires a finished summon, and save/load requires the loaded-pattern check.
- `H.finish` runs all finish callbacks, preserves assertion and callback errors,
  and handles nested failure requests without recursion. The Python runner
  requires a fresh passing completion marker in addition to emulator success,
  rejects timeouts, and removes stale diagnostics before launch.
- NPC branch `claude/vibrant-villani-b543b5` (`215e0b9`, `4bbd144`): event-source
  decoding selects the correct NPC bank, restoring shop NPCs and opening the
  Sealed Cave. No new Tellah-slot writes are introduced.
- Encounter branch `claude/adoring-shtern-8fb0f8` (`1b680cc`): exports encounter
  locations and odds, with 2,816 rows across 193 areas and a generated guide for
  all 156 currently capturable species.
- Both branches added address notes beside Call's section. The merge retains
  Call as L13 and numbers random encounters/map exits L14.

The encounter review identified an unsupported inference: maps with no
map-trigger records were called likely unused and their monsters probably not
intended to be capturable. The report now describes only the evidence, since
scripts/scenes/warps could still load those maps. Regeneration changes 42 area
labels in the CSV; all numerical and species/formation data is unchanged.

The snapshot deliberately includes event `$9D`'s effects. This is a historical
post-Giant snapshot: an event's condition being false now
does not mean its past NPC effects should be omitted. The Giant cutscene remains
counted as completed. Trap Doors remain hidden, consistent with the branch's
documented state policy and the current `capturable=n` data. Making them available
would be a separate gameplay change.

## Verification

- Build passed and the BPS re-applies byte for byte. Integrated ROM CRC32:
  `150D066B`; size 1,048,576 bytes; BPS 1,507 bytes.
- Through actual Mesen, the probe's pass mode exits 0; deliberate assertion,
  incomplete-scenario, finish-error, and nested-failure modes all exit nonzero.
  Later finish callbacks still run after earlier callback failures.
- Python boundary tests cover missing/stale completion markers, successful fresh
  completion, nonzero emulator exit despite a pass marker, and subprocess timeout.
  Audit-caller tests cover runner failures even when result text looks quiet.
- On the integrated build, Imp Call and seeded Turtle Call pass, including roster
  fill/replacement, eidolon move-out, and unchanged Black MP. The Pact refusal
  run (`FORMS=ED,82`, `ACTIONS=P,P,F;P`, 5,200 frames) and save/reset/load pass.
- A deliberately short save/load run fails as incomplete. A wrong NPC visibility
  assertion fails. The observational smoke script still succeeds at its frame
  limit.
- NPC visibility checks assert shop NPCs `042/043` shown on map `00C`, Trap Doors
  `13D/13E` hidden on `14A`, and guardian `1DD` shown on `169`.
- All 44 access-audit runs completed with no new event, fight, or party-change
  notes. Results reproduce the integrated branch's `notes/access.csv`, including
  the Sealed Cave transition `144 -> 14A`. The 12 rows marked `check` record map
  transitions, not harness failures; the remaining 32 are quiet.
- Repeating the encounter exporter produces byte-identical CSV and report.

Emulator artifacts: `build/harness-integration/` and `build/audit/` (ignored).
Mesen requires escalation in this environment to initialize its normal user-data
directories. The original source worktrees remain intact.

## Limits and next work

The access audit checks arrivals and a few steps, not complete dungeon traversal.
The snapshot still uses a documented historical ordering heuristic, including
an assumption about the retained map-property bit on surface world-map events.
The persistence test still proves pact bits, not active-roster persistence.
Field Call display and same-battle summons are unchanged.

**Subsequent update:** ROM expansion/allocation, roster initialization, live field
display and explicit roster save/load checks are now implemented and verified;
see [roster-state.md](roster-state.md). The limits above describe this initial
integration review's baseline. The detailed sequence remains in
[next-build.md](next-build.md).
