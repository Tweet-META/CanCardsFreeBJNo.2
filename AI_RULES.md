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
- Enemies: edit `data/enemies.json`; it contains definitions only, never stage lineups. All portrait paths must exist, and the complete information-panel text must use one `description` key.
- Persistent effects: edit `data/effects.json`; every effect needs a stable ID, localization keys, and an icon path under `assets/effects/`.
- Questions: edit `data/questions.json` and add every generated `Q_<ID>_*` localization key.
- Map floors: edit `data/maps.json`; every configured `image_path` must point to an imported texture.
- Map stages: edit `data/stages.json`, then reference their IDs from the owning floor. Store positions as normalized `[x, y]` coordinates and target scenes as `res://` paths.
- Put battle backgrounds and all wave lineups in `data/stages.json`. Every `monster` entry is one position containing one or more random candidate enemy IDs.
- Use unique stable ASCII IDs.
- Store translatable fields as localization keys.
- Never add player or enemy fixed base defense unless the game design explicitly reintroduces it.
- Attribute passives must remain attribute-driven and stack through `BattleState.get_attribute_count()`, not through character-ID checks.
- Enemy behavior must come from weighted `abilities`, not `prototype`, `attack`, or `ability_power` fields. Attribute variants should not duplicate combat code.
- Adding a new enemy ability ID requires `BattleManager` dispatch logic and a focused test.
- Adding a new card `effect_id`, target type, enemy prototype, or attribute requires parser, rule, UI-description, localization, and test updates.
- Do not hardcode status-effect values or durations in UI scripts. Card data supplies runtime values; `effects.json` supplies reusable metadata and icon paths.

## Battle Invariants

- `BattleState` is the authoritative mutable state.
- Team AP is capped at `5`; skills force hard questions and clear AP.
- Exclusive attack/defense cards grant base AP on every answer; difficulty AP is added only for a correct answer or vocabulary-compensation trigger.
- Each living player character acts at most once per player turn.
- General cards belong to the team, are consumable, and use the negative-index encoding documented in `ARCHITECTURE.md`.
- General-card sale value must come from `CardData.get_sell_price()` (`shop_price * 0.6`, rounded upward to one decimal place); UI code must not duplicate the economy formula.
- Each enemy must grant exactly one random general card on first death-reward collection; use `rewards_collected` rather than mutating reward values as the duplicate guard.
- Question/result overlays must lock card interaction.
- Attack and defense cards must enter `DIFFICULTY_SELECTION` before drawing from the selected global difficulty pool.
- Skill cards must bypass difficulty selection and draw directly from the global hard pool.
- Do not filter battle questions by card or character attribute.
- Shuffle every drawn question through a runtime copy and update `correct_index`; never mutate the source question stored in `QuestionBank`.
- Wrong answers do not directly remove HP or AP.
- Current-HP percentage damage must calculate its dynamic base damage from the target's HP before applying attacker bonuses, status multipliers, reductions, shields, and HP loss.
- Damage immunity is consumed only when positive incoming damage reaches `CharacterData.take_damage()` and negates that complete damage instance before reductions or shields.
- Stun is consumed when an enemy would act and skips the complete action.
- Damage-immunity charges stack numerically and one charge is consumed per positive incoming damage instance.
- Hidden cards must set `available_in_pool = false`; `six_seven` may only be granted through developer controls or the `676767` input code.
- Dead enemies must disappear from the battlefield while retaining their original `enemy_team` index semantics.
- Clearing a non-final wave must start the next player turn without resetting player HP, AP, cards, currency, or shop state.
- Victory is allowed only after the final configured wave is cleared.
- No more than eight living enemies may be displayed or added by developer tools.
- Both sides support fixed shields and percentage reduction. Resolve percentage reduction first, then fixed shield, then HP.
- Fixed shields persist until consumed; their shared `ShieldVisual` must disappear when the value reaches zero and no percentage shield remains.
- Persistent effects use `effect_id + source_id` as the stack key: the same source refreshes, while different sources may coexist. Vulnerable effects from different sources stack multiplicatively.
- Status durations advance at the start of player turns. An effect applied for two turns affects the application turn and the following player turn.

## UI and Interaction Invariants

- Players remain on the left; enemies remain on the right.
- Player selection is performed by clicking standees.
- Targeted cards are dragged; the card remains visually represented and an arrow indicates targeting.
- Valid hovered targets must highlight.
- Releasing without a required target, or releasing over `CancelDropArea`, cancels cleanly and restores hover animation state.
- Exclusive and team-general hands remain separate fan layouts.
- Question and answer-result panels render on `QuestionLayer` at layer `100`.
- Shop and log panels must remain usable above normal battle content but below question/result overlays.
- Opening the shop must lock and cancel all hand interaction; closing it must not clear an active question/result flow lock.
- Team general cards must render above enemy standees and below the shop.
- Independent UI panel scenes must set `layout_mode = 1` and explicit root anchors/offsets in their own `.tscn`. Their host-scene instance must repeat the final layout overrides, and export-sensitive overlays must restore the same anchors/offsets in `_ready()`; never rely on implicit root-layout inheritance.

## Localization

- Edit `data/localization/translations.csv`, not generated `.translation` files.
- Register the generated locale-specific `.translation` resources in `project.godot`; keep `translations.csv` as the editable source and do not restore CSV parsing in `LanguageManager`.
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
