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

- [ ] **PLAT-001 — Resolution/aspect strategy**
  - Choose and configure a `stretch/aspect` mode (e.g. `expand`) so layouts work across desktop 16:9 and taller mobile aspect ratios instead of assuming a fixed 1280x720 canvas.

- [ ] **PLAT-002 — Responsive layout pass**
  - Replace hardcoded pixel positions/offsets (castle building panels, mine HUD labels, TD HUD labels) with anchors/containers and safe-area-aware layout.
  - Replace hardcoded board/grid draw origins and cell sizes (`BOARD_ORIGIN`, `CELL_SIZE` in `mine_controller.gd`, `cell_size` in `grid_map.gd`) with viewport-relative sizing.
  - Replace the hardcoded `Rect2(0, 0, 1280, 720)` background draw in `mine_controller.gd` with a viewport-relative rect.

- [ ] **PLAT-003 — Touch input support**
  - Add `InputEventScreenTouch`/`InputEventScreenDrag` handling alongside mouse input in `grid_map.gd` and `mine_controller.gd`.
  - Increase tap target sizes for touch ergonomics and verify tap-to-pin fully substitutes for mouse-hover affordances (e.g. `unit_info_card.gd`).

- [ ] **PLAT-004 — Platform export setup**
  - Add PC (Windows/Linux) and mobile (Android, optionally iOS) export presets, including Android keystore/export template configuration.
  - Verify `renderer/rendering_method="mobile"` is acceptable on desktop or set rendering method per-platform.

- [ ] **PLAT-005 — Mobile lifecycle handling**
  - Add pause-on-background/save-on-pause handling for mobile app suspend/resume via `save_manager.gd`.
  - Review `_draw()`-heavy custom rendering (match-3 board, TD grid) for mobile GPU performance.

- [ ] **AV-001 — Missing SFX hooks**
  - Add missing SFX triggers for combat, mine events, and day outcomes.

- [ ] **AV-002 — Lightweight gameplay VFX**
  - Add key-event VFX aligned with the pixel-fantasy tone.
