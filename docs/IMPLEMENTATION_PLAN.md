# TD + Match-3 + RPG — Implementation Plan (Lean Status)

This file is intentionally concise. It is the **execution/status index** for agents.
Detailed behavior lives in system docs:

- [docs/systems/tower_defense.md](systems/tower_defense.md)
- [docs/systems/match3.md](systems/match3.md)
- [docs/systems/castle.md](systems/castle.md)

---

## 1) What is already implemented

### Milestone status

| Milestone | Status | Notes |
|---|---|---|
| 1. Foundations (`EventBus`, `GameState`, `SaveManager`) | ✅ Done | Save/state/event backbone is in use. |
| 2. TD core loop vertical slice | ✅ Done | Move/attack loop, spawning, win/loss flow present. |
| 3. Data-driven adventurers/enemies + towers | ✅ Done | `.tres` driven content and combat roles wired. |
| 4. Castle minimal (Tavern + Quarters -> TD roster) | ✅ Done | Recruitment + active roster selection works. |
| 5. Match-3 mine loop | ✅ Done | Matching, cascades, descend, rewards integrated. |
| 6. Remaining Castle buildings | ✅ Done | Smelter, smiths, armoury, upgrade rows implemented. |
| 7. Day/wave progression | ✅ Done | Days 1–3 exist; day discovery is data-driven. |
| 8. Polish (broad umbrella) | 🟡 In progress | Ongoing; see open workstreams below. |
| 9. Match-3 move-to-empty animation clarity | ✅ Done | Dedicated move event + queue ordering added. |
| 10. Top resource bar HUD 2.0 | ✅ Done | `TopResourceBar` replaces compact HUD in Castle/TD/Mine. |
| 11. Castle focus mode + War Room | ✅ Done | Building focus mode and day selection migration complete. |
| 12. Visual/UX continuity after HUD/focus changes | ✅ Done | Layout continuity and docs updates applied. |

### Recent completions (important for future agents)

1. Mine empty-space moves now animate explicitly before gravity.
2. Shared full-width `TopResourceBar` is the active HUD pattern.
3. Castle uses focus-mode panel entry and a dedicated War Room for day start flow.
4. Documentation in `docs/systems/` was updated to match current behavior.

---

## 2) Open workstreams (next priorities)

These replace older “immediate steps” that are now complete.

### A. Gameplay balancing (highest ROI)
- Rebalance Day 1–3 pacing/reward curves.
- Tune mine material income against crafting/upgrade costs.
- Validate “battle -> mine -> castle spend” loop feels consistently rewarding.

### B. Content expansion (data-first)
- Add more adventurers/enemies/spells under `data/`.
- Add Day 4+ wave data (`data/waves/day_<n>.tres`).
- Keep script changes minimal unless new mechanics require them.

### C. Castle progression depth
- Improve upgrade differentiation (not just cost gates).
- Clarify long-term progression choices across buildings.
- Improve in-panel “what unlocks next” readability.

### D. TD tactical depth
- Add limited new status interactions (for example: slow, armour break, anti-swarm).
- Ensure effects are readable in combat feedback and primarily data-driven.

### E. UX readability and feedback
- Refine top bar context emphasis/order.
- Improve high-signal UI feedback (descend available, wave transitions, day result).
- Re-check overlay/input blocking risks at 1280x720.

### F. Audio + VFX pass
- Add missing SFX hooks (combat, mine events, day outcomes).
- Add lightweight VFX for key events, consistent with pixel-fantasy tone.

### G. Robustness workflow
- Keep mandatory parse gate:
  - `godot --headless --path "D:\td-m3-game" --check-only --quit`
- Keep compact smoke checks for Castle/TD/Mine after behavior changes.

### H/I. Completed milestone archive (condensed)

- ✅ **H. Guided progression loop** delivered:
  - Day 1 -> Mine onboarding lock flow,
  - reusable gate state model (`introduced/active/resolved`),
  - Workshop + Dynamite/Shovel/Barrier Trinket loops,
  - gate-aware Mine blockers and Castle/Mine objective surfacing.
- ✅ **I. TD combat UI readability** delivered:
  - compact HP/action bars (no enemy numeric HP fallback),
  - per-adventurer action storage cap model,
  - hover/tap unit info cards with range previews.
- ✅ Validation for these deliveries used the mandatory parse gate:
  - `godot --headless --path "D:\td-m3-game" --check-only --quit`
- See as-built behavior in:
  - [docs/systems/castle.md](systems/castle.md)
  - [docs/systems/match3.md](systems/match3.md)
  - [docs/systems/tower_defense.md](systems/tower_defense.md)

### J. Castle Library + Bestiary roadmap (new priority)

Goal: add a new Castle building (**Library**) that acts as the player’s bestiary, tracking encountered enemies and exposing clear stat/attack information.

#### J1. Building role and progression fit
- Library is a Castle-side knowledge/progression building, not a combat power spike by itself.
- Primary function: convert enemy encounters into persistent knowledge entries.
- Unlock timing should align with early-mid progression so the feature is useful before enemy roster grows too large.

#### J2. Bestiary discovery rules
- Enemy entries unlock when that enemy has been fought (encountered in TD), not only when killed.
- Entry state model:
  1. **Unknown** (not encountered),
  2. **Discovered** (basic info visible),
  3. **Detailed** (full stats/attack profile visible; optional future upgrades can expand detail depth).
- Discovery state persists in save data.

#### J3. Entry content scope
- Per enemy bestiary entry should include:
  - Name, portrait/sprite reference, and category tags.
  - Core combat stats (HP, movement speed, resistances/armour if applicable).
  - Attack profile (attack type, interval/rate, damage style, notable special effects).
  - Drop hints/known rewards where applicable (consistent with progression gating design).
- Keep terminology identical to TD combat UI labels to avoid confusion.

#### J4. Library UX expectations
- Library appears as a selectable Castle building/panel.
- Bestiary list supports quick scan:
  - Locked/unknown entries are visually distinct.
  - Discovered entries show summary row + expandable/openable details.
- Entry details should be readable at 1280x720 and remain controller/mobile-friendly.

#### J5. Delivery slices (small, implementable packets)

Packet 1 — Building scaffold
- Add Library building data and Castle panel routing.
- Add placeholder panel with empty-state messaging.

Packet 2 — Encounter tracking backend
- Track “enemy encountered” events from TD flow.
- Persist encountered enemy IDs in save-compatible progression state.

Packet 3 — Bestiary data binding
- Define bestiary-facing enemy metadata (data-first, sourced from enemy resources where possible).
- Build entry state resolution (unknown/discovered/detailed).

Packet 4 — List + detail UI
- Implement bestiary list view with locked/discovered states.
- Implement detail card/page with stats + attacks breakdown.

Packet 5 — Progression integration + polish
- Wire unlock timing/requirements for Library access.
- Add subtle “new entry discovered” feedback after battles.
- Tune readability and navigation flow.

#### J6. Data-first and architecture notes
- Prefer storing bestiary presentation data in `data/` resources or in enemy resource fields (avoid duplicate hardcoded tables).
- Reuse existing enemy stat sources; bestiary should reflect authoritative combat data.
- Keep encounter tracking event-driven via existing battle/event systems.
- Preserve save compatibility using additive fields/default empty collections for discovered entries.

#### J7. Validation per packet
- Mandatory:
  - `godot --headless --path "D:\td-m3-game" --check-only --quit`
- Smoke checks:
  - Entering Library from Castle panel is stable and input-safe.
  - First encounter with an enemy creates/updates the corresponding bestiary state.
  - Save/load retains discovered entries and detail level correctly.
  - Bestiary stats/attack info match live enemy behavior in TD.
  - Unknown/discovered/detailed visuals are clearly distinguishable.

---

## 3) Agent execution guidance

When implementing new work:

1. Read this file + relevant system doc(s) first.
2. Prefer **data-first** changes in `data/*.tres` where possible.
3. Keep edits tightly scoped to one system per packet unless coupling demands otherwise.
4. Update the matching system doc whenever behavior changes.
5. Always run the headless check and report exact validation performed.

---

## 4) Outdated sections removed on purpose

Prior versions of this file included full architecture/folder/data-model detail and completed milestone
checklists that duplicated current as-built docs. Those sections were intentionally removed to reduce
reading overhead and make implemented vs. pending work obvious for future agents.
