# AI Development Rules

## Non-Negotiable Constraints

1. Preserve Godot `4.6` compatibility and typed GDScript.
2. Treat warnings as build failures. Do not rely on inferred types from `Variant`; declare explicit types after JSON, dictionary, array, `load()`, and node operations.
3. Do not put combat rules in UI scripts. Rule changes belong in `BattleManager`, `BattleState`, or typed data classes.
4. Do not let `BattleManager` access UI nodes. Communicate through signals.
5. Do not hardcode card, character, enemy, or question definitions in UI code.
6. Keep static UI structure in `.tscn` scenes. Do not reconstruct panels with large blocks of `Button.new()`, `Label.new()`, `Control.new()`, or `TextureRect.new()`.
7. Runtime collections may instantiate reusable packed scenes such as `CardButton`, `ShopCardItem`, `CharacterStandee`, and `EnemyStandee`.
8. Bind existing scene nodes with typed `@onready` paths. If a node path changes, update its bound script and instantiate the scene before considering the change complete.
9. Preserve current UI appearance and battle values unless the requested task explicitly changes them.
10. Add concise Chinese comments for non-obvious state transitions, data contracts, formulas, and interaction recovery logic. Do not narrate trivial assignments.

## Before Editing

- Inspect the relevant `.tscn`, attached script, data source, and existing tests.
- State the scene-tree change before any scene or UI edit. If no scene tree changes, say so.
- Check `git status`; do not revert unrelated user changes or generated files.
- Do not edit or delete `项目日志.docx`.
- Prefer extending existing scenes, databases, signals, and controllers over introducing parallel systems.

## Data Changes

- Cards: edit `data/cards.json`; add translation keys to `data/localization/translations.csv`.
- Characters: edit `data/characters.json`; card references must resolve through `CardDatabase`, and the complete information-panel text must use one `description` key.
- Enemies: edit `data/enemies.json`; all portrait paths must exist, and the complete information-panel text must use one `description` key.
- Questions: edit `data/questions.json` and add every generated `Q_<ID>_*` localization key.
- Use unique stable ASCII IDs.
- Store translatable fields as localization keys.
- Never add player or enemy fixed base defense unless the game design explicitly reintroduces it.
- Attribute passives must remain attribute-driven and stack through `BattleState.get_attribute_count()`, not through character-ID checks.
- Enemy prototype behavior must remain prototype-driven. Attribute variants should not duplicate combat code.
- Adding a new card `effect_id`, target type, enemy prototype, or attribute requires parser, rule, UI-description, localization, and test updates.

## Battle Invariants

- `BattleState` is the authoritative mutable state.
- Team AP is capped at `5`; skills force hard questions and clear AP.
- Each living player character acts at most once per player turn.
- General cards belong to the team, are consumable, and use the negative-index encoding documented in `ARCHITECTURE.md`.
- Question/result overlays must lock card interaction.
- Wrong answers do not directly remove HP or AP.
- Dead enemies must disappear from the battlefield while retaining their original `enemy_team` index semantics.
- No more than eight living enemies may be displayed or added by developer tools.
- Both sides support fixed shields and percentage reduction. Resolve percentage reduction first, then fixed shield, then HP.
- Fixed shields persist until consumed; their shared `ShieldVisual` must disappear when the value reaches zero and no percentage shield remains.

## UI and Interaction Invariants

- Players remain on the left; enemies remain on the right.
- Player selection is performed by clicking standees.
- Targeted cards are dragged; the card remains visually represented and an arrow indicates targeting.
- Valid hovered targets must highlight.
- Releasing without a required target, or releasing over `CancelDropArea`, cancels cleanly and restores hover animation state.
- Exclusive and team-general hands remain separate fan layouts.
- Question and answer-result panels render on `QuestionLayer` at layer `100`.
- Shop and log panels must remain usable above normal battle content but below question/result overlays.

## Localization

- Edit `data/localization/translations.csv`, not generated `.translation` files.
- Maintain both `zh_CN` and `en` columns for every new key.
- UI scripts use `tr(key)` and refresh on `LanguageManager.language_changed`.
- Do not embed user-facing Chinese or English strings in battle/UI scripts unless they are non-display identifiers.

## Required Verification

Run at minimum after code or scene changes:

```powershell
.\Godot_v4.6.3-stable_win64.exe --headless --editor --path . --quit
.\Godot_v4.6.3-stable_win64.exe --headless --path . --script res://scripts/SmokeTest.gd
```

Run the focused smoke test for every affected subsystem. Common commands:

```powershell
.\Godot_v4.6.3-stable_win64.exe --headless --path . --script res://scripts/ActorDatabaseSmokeTest.gd
.\Godot_v4.6.3-stable_win64.exe --headless --path . --script res://scripts/CardDatabaseSmokeTest.gd
.\Godot_v4.6.3-stable_win64.exe --headless --path . --script res://scripts/QuestionBankSmokeTest.gd
.\Godot_v4.6.3-stable_win64.exe --headless --path . --script res://scripts/LocalizationSmokeTest.gd
.\Godot_v4.6.3-stable_win64.exe --headless --path . --script res://scripts/PassiveStackSmokeTest.gd
.\Godot_v4.6.3-stable_win64.exe --headless --path . --script res://scripts/EnemyAbilitySmokeTest.gd
.\Godot_v4.6.3-stable_win64.exe --headless --path . --script res://scripts/EnemyLayoutSmokeTest.gd
```

For battle UI changes, also instantiate the real scene:

```powershell
.\Godot_v4.6.3-stable_win64.exe --headless --path . res://scenes/BattleScene.tscn --quit-after 3
```

Validate edited JSON and run `git diff --check`. A successful parse without the focused regression test is not sufficient.
