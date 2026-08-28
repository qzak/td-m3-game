# TD + Match-3 + RPG — Pending Backlog Only

> **Agent policy (planning + execution):**
> - Keep this file as a **pending-features-only** backlog.
> - When a feature is implemented, **remove it from this file in the same change**.
> - Move shipped behavior details to the appropriate system doc (`docs/systems/*`) instead of keeping completion history here.

This document lists **only unimplemented features**.  
If a feature ships, remove it from this file and document as-built behavior in:

- [docs/systems/tower_defense.md](systems/tower_defense.md)
- [docs/systems/match3.md](systems/match3.md)
- [docs/systems/castle.md](systems/castle.md)

---

## Tower Defense

- [ ] **TD-003 — Additional status interactions beyond current set**
  - Extend combat interaction depth with new status mechanics beyond currently shipped effects.
  - Keep combat readability clear in HUD/feedback.

- [ ] **TD-004 — Expand unit/enemy/spell content**
  - Add more adventurers, enemies, and spells using data-first resources under `data/`.

- [ ] **TD-005 — Add Day 6+ wave content**
  - Add new `day_<n>.tres` wave sets beyond Day 5.

- [ ] **TD-006 — Rebalance day pacing/rewards**
  - Re-tune day pacing and reward curves for better moment-to-moment flow.

## Match-3 + Economy Loop

- [ ] **LOOP-001 — Mine income vs upgrade-cost tuning**
  - Rebalance mine material income against crafting and upgrade costs.

- [ ] **LOOP-002 — End-to-end loop feel pass**
  - Validate and tune `battle -> mine -> castle spend` cadence to feel consistently rewarding.

## Castle Progression

- [ ] **CASTLE-001 — Stronger upgrade identity**
  - Improve upgrade differentiation so choices are strategic, not only cost-gated.

- [ ] **CASTLE-002 — Long-term progression clarity**
  - Clarify how building choices impact longer-run progression.

- [ ] **CASTLE-003 — Better unlock readability in panels**
  - Improve in-panel communication of what unlocks next.

- [ ] **CASTLE-004 — Library building scaffold**
  - Add Library building data and Castle panel routing.
  - Add placeholder Library panel with empty-state messaging.

- [ ] **CASTLE-005 — Bestiary encounter tracking**
  - Track enemy encountered events from TD.
  - Persist encountered enemy IDs in save-compatible state.

- [ ] **CASTLE-006 — Bestiary data binding + state model**
  - Build bestiary entry states: Unknown, Discovered, Detailed.
  - Source metadata from existing enemy resources where possible.

- [ ] **CASTLE-007 — Bestiary list + detail UI**
  - Implement scan-friendly list with locked/discovered states.
  - Implement detail view with stats and attack profile.

- [ ] **CASTLE-008 — Bestiary progression integration + polish**
  - Wire Library unlock timing/requirements into progression.
  - Add subtle "new entry discovered" post-battle feedback.

## UX / Presentation

- [ ] **UX-001 — Top resource bar context refinement**
  - Refine emphasis/order for higher-signal context display.

- [ ] **UX-002 — High-signal feedback pass**
  - Improve feedback for descend availability, wave transitions, and day results.

- [ ] **UX-003 — 1280x720 overlay/input safety pass**
  - Re-check and fix any HUD overlay/input-blocking risks at target resolution.

## Cross-Platform (PC + Mobile)

- [ ] **AV-001 — Missing SFX hooks**
  - Add missing SFX triggers for combat, mine events, and day outcomes.

- [ ] **AV-002 — Lightweight gameplay VFX**
  - Add key-event VFX aligned with the pixel-fantasy tone.
