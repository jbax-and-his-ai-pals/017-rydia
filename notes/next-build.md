# Next build: choose a roster, give summons distinct roles

Planning review, November 5, 2026. Baseline: `master` at `a19b1a3`.
The user selected **roster control + distinct summons** as the next payoff.
The plan below records the original proposed sequence. Packages A-C and both
branch reviews are complete on `codex/harness-and-branch-integration`. See
[integration-review.md](integration-review.md) for the initial integration and
[roster-state.md](roster-state.md) for expanded ROM, live field Call display,
roster lifecycle, and save/load verification. Next are the roster picker and
signature-ability data work (D-F). **D and F are done** (first ten starters): see
"Signature abilities" in [call-design.md](call-design.md). **E (picker) is done:** see "Roster picker" in
[roster-state.md](roster-state.md).

## Read on the project

The technical vertical slice works: deterministic Pact, permanent collection,
five saved roster slots, a battle-start snapshot, species graphics and names,
scaled damage, and species-dependent MP. The reproducible BPS build and real-menu
Mesen harness make further assembly work practical.

The next milestone should turn that foundation into meaningful player choices.
Currently every pact uses the same neutral magic hit, and collecting a sixth
species rotates an older one out without an in-game way to retrieve it. Those
two limitations matter more to the next playtest than additional acquisition
rules, a larger loadout, or story.

Keep the permanent bitfield, five active slots, vanilla ATB, and battle-start
snapshot. Same-battle summoning remains deferred for this milestone. It needs
separate treatment of cached menus and actions; refreshing the snapshot alone
is not an adequate design.

## Fresh baseline verification

- `python tools/build.py`: passed; BPS re-applies byte for byte. Output is still
  1 MiB, CRC32 `61972134`.
- `call.lua`, default Imp run: `ALL PASS`, including damage and MP.
- `call.lua`, `SLOT=1 SEED=1 BLACK=1`: `ALL PASS`, including Turtle, old-save
  roster fill, oldest-slot replacement, eidolon move-out, and Black MP.
- `persist.lua`: passed the existing two-save-slot pact-bitfield test.
- Artifacts: `build/planning-review/*-unsandboxed/`. Mesen exited before Lua
  initialization inside the sandbox; these successful runs used escalation.

Coverage limits: these runs do not prove all 156 capturable graphics, active
roster persistence, field menu behavior, or full dungeon access. The Call and
Pact scripts record assertion failures but currently do not propagate their
failure counts to the process exit code. Always inspect their result files
until that is fixed.

## Existing work to review first

Both attached worktrees were clean during this review. Neither branch is merged
into this baseline. Review their changes before bringing them in; do not rebuild
their functionality independently.

| Branch | Useful work | Integration concern |
| --- | --- | --- |
| `claude/vibrant-villani-b543b5` (`215e0b9`, `4bbd144`) | Resolves NPC flag banks; opens the Sealed Cave; documents visibility and trigger checks | Changes the starting world state. Rebuild and spot-check actual entry/access. Trap Doors starting hidden is a documented design choice, not a roster dependency. |
| `claude/adoring-shtern-8fb0f8` (`1b680cc`) | Encounter exporter, encounter CSV, generated monster-location guide | Useful input to starter-set curation and later collection reachability. Both branches and master add address notes; integrate those sections deliberately. |

## Work packages and sequence

Complexity describes reasoning and review needs, not a promised duration or a
specific model's price. Give routine tasks to a lower-cost coding agent; keep
engine contracts and final integration with the lead.

| Package | Complexity / owner | Deliverable and acceptance |
| --- | --- | --- |
| A. Reliable regression results | Low / worker | Make assertion failures and incomplete scenarios exit nonzero. Prove this with an intentional failed assertion and a scenario that never completes, then rerun the successful baseline. Own `tools/mesen/lib.lua`, `run.py`, and affected test scripts. |
| B. Expansion and table contract | High / lead, bounded worker implementation | Establish expanded-ROM allocation, symbol/table interfaces, header/checksum handling, and bank-call constraints. Prefer 2 MiB if confirmed sufficient. Clean input validation and BPS reconstruction must still pass; smoke-test boot, Pact, Call, and persistence. Avoid an unrelated rewrite of existing hooks. |
| C. Roster lifecycle and field display | Medium-high / lead contract, worker implementation | Separate roster validation/list projection from the battle snapshot. Synchronize field names and displayed MP after acquisition, roster edits, and load; explicitly initialize pact/roster state on New Game. Preserve eidolons. Test real field-menu display, saved roster order, replacement cursor, old bitfield-only saves, and New Game after loading an existing save. |
| D. Ability data and AI export | Medium / worker, after B's schema | Export spell candidates from parsed AI commands, including conditional/counter paths where applicable. Preserve all curated columns on re-export. Validate IDs, ranges, names, coverage, and allowed effects. Unsupported abilities must produce a visible report and a defined fallback. Own exporter/data generation; coordinate changes to `tools/build.py`. |
| E. In-game roster picker | High / lead spike, worker for established UI pieces | Browse the whole acquired collection with paging/scrolling; choose a pact and one of five slots; confirm or cancel; prevent duplicates. An older pact displaced by later captures must be selectable again. Use existing menu primitives where practical; an NPC entry point still needs a real selection UI. Verify changes survive save/reset/load and appear in the next battle. |
| F. Distinct starter summons | High for first runtime path, then low-medium curation | Wire curated spell data and animation through the summon path, with explicit targeting and effect contracts. Ship 8-12 accessible species with several distinct roles, using verified routines first. Test actual element/target/status behavior, not just names or animation. Keep safe generic behavior for the remaining species. |
| G. Focused playtest | Lead + user | Collect more than five species, retrieve an older favorite, build a useful roster, save/load it, and demonstrate why several summons deserve different slots. Record balance and presentation findings. |

Start A and the read-only review of the two branches independently. B precedes
new tables and substantial menu code. After the shared interfaces are written,
D can run alongside C; E builds on C, and F consumes D. Integrate and rebuild
serially. One agent owns `asm/call.asm` at a time, and only the integrator writes
shared `build/` outputs while integration is underway.

## Roster behavior to implement

Recommended change once the picker exists: new pacts fill empty active slots;
when all five slots are occupied, new pacts join the collection without silently
replacing a chosen summon. This changes the present ring-buffer policy, so update
its tests and documentation in the same change. Existing saves retain their
current five species. Keep the reserved bytes to avoid an unnecessary save-layout
change; do not grow the active roster in this milestone.

The collection is authoritative for ownership; the roster is authoritative for
selection. The field list is derived from the roster. Battle start validates the
roster, builds the battle list, and takes a stable snapshot. Field updates must
not accidentally change what an already queued battle action will summon.

Prototype the picker entry point before committing to a full custom bestiary.
A small field-menu extension is desirable; a town-based picker is an acceptable
first delivery if the field-menu hooks are substantially more expensive. Every
collected species must be reachable through the picker either way.

## Ability behavior to implement

Use the current effect-$00 path first for distinct elements and powers. Choose
the starter species from the encounter guide after confirming in-game access.
Then verify one utility/status effect from Rydia's side before widening the
allowlist. Enemy routines may rely on enemy-only caster state.

Specify separately: species graphic/caption, ability data, animation, target
selection, and MP. A slot's early targeting/menu path may need changes before
copying an ability's data at resolution can implement its behavior correctly.
Do not assume that copying six bytes makes healing, multi-target attacks, or
enemy-only effects safe. Test the resulting action against appropriate targets.

Keep the existing level/MP formulas initially so ability differences can be
evaluated without also changing progression. Tall-monster clipping should get
a representative visual check and an explicit follow-up, rather than being
mistaken for complete bestiary graphics coverage.

## Agent handoff rules

Each assignment names a baseline, owned files, inputs/outputs, non-goals, and an
acceptance command or exact scenario. Ask for a small diff plus evidence and
unresolved questions. Workers should stop and report an unknown engine contract
rather than guess addresses or widen an effect allowlist without verification.

Use isolated checkouts for concurrent writes, and one lead to integrate. Do not
merge two agents' independent edits to the large Call routine without reviewing
their shared state assumptions. Delegate research and implementation against
stable contracts; retain architectural choices and ROM/battle debugging at the
lead level. This keeps extra reasoning concentrated on decisions that can
invalidate several work packages.

## Later

Same-battle summoning; an all-species visual sweep; collection reachability for
story-only areas; a richer bestiary; broader effect support; progression and
encounter balance; acquisition tiers; growth and save migration; story. The
level-60 sandbox remains useful while the roster and abilities are established.
