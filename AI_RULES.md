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
9. Prefer editor-adjustable scene nodes for positions, layer order, panel size, slot placement, and animation tuning values that designers will likely tweak. Do not hide frequently adjusted UI layout constants in parent scripts when a `.tscn` node, slot, marker, theme, or exported property would make the value editable in Godot.
10. Preserve current UI appearance and battle values unless the requested task explicitly changes them.
11. Add concise English comments before new or modified functions explaining their purpose. Keep extra inline comments for non-obvious state transitions, data contracts, formulas, and interaction recovery logic; do not narrate trivial assignments.

## Before Editing

- Inspect the relevant `.tscn`, attached script, and data source.
- State the scene-tree change before any scene or UI edit. If no scene tree changes, say so.
- Check `git status`; do not revert unrelated user changes or generated files.
- Do not edit or delete `项目日志.docx`.
- Prefer extending existing scenes, databases, signals, and node components over introducing parallel systems.
- Before changing UI layout code, ask whether the same value should become an editor-owned node, slot, marker, theme resource, or exported property instead.

## Godot MCP Usage

- Godot MCP is available as a development tool for this project. Use it to inspect Godot version, project metadata, scene validity, debug output, and simple scene-node operations when that is safer than editing `.tscn` text directly.
- Prefer `mcp__godot.get_project_info` and `mcp__godot.get_godot_version` for environment checks instead of guessing the active Godot version or project structure.
- Prefer MCP scene operations such as adding nodes, saving scenes, and loading Sprite2D textures when changing straightforward scene structure. Manual `.tscn` edits are still allowed for small, reviewable text changes, but avoid hand-writing large scene trees.
- Use `mcp__godot.get_debug_output` when investigating editor/runtime errors after the user has reproduced an issue.
- Do not launch the Godot editor with MCP unless the user explicitly asks for a visible editor action.
- Do not run gameplay smoke tests or long play sessions through MCP unless the user explicitly asks. The user performs manual gameplay validation by default.
- MCP is an editing and inspection aid, not an architecture exception: UI still belongs in `.tscn`, battle rules still belong outside UI scripts, and data still belongs in JSON/localization files.

## Data Changes

- Cards: edit `data/cards.json`; add translation keys to `data/localization/translations.csv`.
- Characters: edit `data/characters.json`; card references must resolve through `CardDatabase`, and the complete information-panel text must use one `description` key.
- Enemies: edit `data/enemies.json`; it contains definitions only, never level lineups. All portrait paths must exist, and the complete information-panel text must use one `description` key.
- Persistent effects: edit `data/effects.json`; every effect needs a stable ID, localization keys, and an icon path under `assets/effects/`.
- Questions: edit `data/questions.json` and add every generated `Q_<ID>_*` localization key.
- Learning Goals: edit `data/learning_goals.json`; goals are resolved by character attribute and must not be embedded in character or UI scripts.
- Map maps: edit `data/maps.json`; every configured `image_path` must point to an imported texture.
- Map levels: edit `data/levels.json`, reference their IDs from the owning map, and place matching `LevelNode` instances in `MapScene.tscn`. Level positions belong to those editor-authored nodes; target scenes remain `res://` paths in level data.
- Put battle backgrounds and all wave lineups in `data/levels.json`. Every `monster` entry is one position containing one or more random candidate enemy IDs.
- Use unique stable ASCII IDs.
- Store translatable fields as localization keys.
- Never add player or enemy fixed base defense unless the game design explicitly reintroduces it.
- Attribute passives no longer exist. Pre-battle Learning Goals are battle-only and limited to one active goal. Level 1 explicitly requires a choice for its tutorial; other levels keep goals optional. The chosen unlocked character supplies its attribute goal even when absent from the party or defeated; goals never stack.
- Preserve the current Learning Goal values: Pinyin grants team maximum HP and damage-card effects `+20%`, Vocabulary grants `25%` wrong-answer compensation, and Culture grants `+0.25` AP growth.
- Matching player and enemy attributes must never grant attack or defense modifiers. Attributes remain classification data only unless a named card, effect, ability, or Learning Goal explicitly uses them.
- Enemy behavior must come from weighted `abilities`, not `prototype`, `attack`, or `ability_power` fields. Attribute variants should not duplicate combat code.
- Adding a new enemy ability ID requires `BattleManager` dispatch logic and manual battle verification.
- Adding a new card `effect_id`, target type, enemy prototype, or attribute requires parser, rule, UI-description, localization, and manual verification updates.
- Do not hardcode status-effect values or durations in UI scripts. Card data supplies runtime values; `effects.json` supplies reusable metadata and icon paths.

## Battle Invariants

- `BattleState` is the authoritative mutable state.
- Team AP is capped at `5`; skills force hard questions and clear AP.
- Exclusive attack/defense cards grant base AP on every answer; difficulty AP is added only for a correct answer or vocabulary-compensation trigger.
- Each living player character acts at most once per player turn.
- General cards belong to the team, are consumable, and use the negative-index encoding documented in `ARCHITECTURE.md`.
- General-card sale value must come from `CardData.get_sell_price()` (`shop_price * 0.6`, rounded upward to one decimal place); UI code must not duplicate the economy formula.
- General cards and the shop unlock by the active level's order: `data/levels.json.general_cards_unlock_order` is 5. Orders 1-4 must not grant starting cards, enemy card drops, purchases, or developer/hidden-code cards; do not merely hide the shop button.
- After general cards unlock, each enemy must grant exactly one random general card on first death-reward collection; use `rewards_collected` rather than mutating reward values as the duplicate guard. Locked levels still award their existing currency rewards.
- Question/result overlays must lock card interaction.
- Answer results enter `ANSWER_RESULT`; dismissing the explanation starts `ACTION_RESOLUTION`. Never resolve enemy turns behind a visible answer panel.
- Battle visuals use request IDs through `presentation_requested` and completion acknowledgements. BattleManager must await visuals without accessing UI nodes; retries and scene exit invalidate stale requests.
- Enemy turns show the turn banner and resolve living enemies one at a time. Wait for attacked player hurt sequences before advancing or showing defeat; group-hit animations play together.
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
- Selection plays one gravity-based portrait-layer jump. Keep standee slots and HP bars fixed, return the portrait to its baseline, and do not add a persistent elevation or a foot selection marker.
- Targeted cards are dragged; the card remains visually represented and an arrow indicates targeting.
- Valid hovered targets must highlight.
- Unit selection and card targeting share a portrait-body alpha mask. HP bars, status icons, transparent padding, and attack effects are not hit areas. Target/selection outlines bound only the portrait body and follow its visual movement.
- Releasing without a required target, or releasing over `CancelDropArea`, cancels cleanly and restores hover animation state.
- Exclusive and team-general hands remain separate fan layouts.
- Question and answer-result panels render on `QuestionLayer` at layer `100`.
- Shop and log panels must remain usable above normal battle content but below question/result overlays.
- Opening the shop must lock and cancel all hand interaction; closing it must not clear an active question/result flow lock.
- Team general cards must render above enemy standees and below the shop.
- Things users commonly drag or tune in the editor, such as battle standee slots, card hand anchors, panel positions, cancel-drop areas, and overlay layers, should live in `.tscn` scene structure rather than only in script constants.
- Retain standee nodes across UI refreshes; replace only stale character/enemy identities or defeated enemies. Refreshing HP or hover highlights must not restart character animation.
- Character battle animations come from `battle_animation_path` in character JSON and editor-owned SpriteFrames resources. Preserve static portraits for non-battle UI and characters without animations.
- Tutorial definitions and localization keys belong in `data/tutorials.json`. Map guidance advances from real preparation choices; battle guidance belongs in the existing log, with a reminder to open it. Save tutorial completion only after victory and repeat the hints on failed retries.
- `OpeningSequence.tscn` is the new-save handoff before the map. Its future SpriteFrames path comes from tutorial JSON; an empty path skips straight to the map without displaying fake story content.
- Independent UI panel scenes must set `layout_mode = 1` and explicit root anchors/offsets in their own `.tscn`. Their host-scene instance must repeat the final layout overrides, and export-sensitive overlays must restore the same anchors/offsets in `_ready()`; never rely on implicit root-layout inheritance.

## Localization

- Enter levels through the persistent `SceneTransition` overlay. Keep transition layout in its scene and `LoadingScreen.tscn`; iris durations are exported. Loading progress must come from `ResourceLoader.load_threaded_get_status`, never a simulated timer. Include JSON-referenced animations through `LevelResourceManifest`, retain the loaded resources for the battle, and reveal combat only after `BattleScene.loading_ready`.

- Edit `data/localization/translations.csv`, not generated `.translation` files.
- Register the generated locale-specific `.translation` resources in `project.godot`; keep `translations.csv` as the editable source and do not restore CSV parsing in `LanguageManager`.
- Maintain both `zh_CN` and `en` columns for every new key.
- UI scripts use `tr(key)` and refresh on `LanguageManager.language_changed`.
- Do not embed user-facing Chinese or English strings in battle/UI scripts unless they are non-display identifiers.

## Required Verification

Automated smoke-test scripts have been removed. Do not recreate or run smoke
tests unless the user explicitly asks for them.

For code, data, or scene changes, prefer these lightweight checks:

```powershell
.\Godot_v4.6.3-stable_win64.exe --headless --editor --path . --quit
git diff --check
```

For battle UI changes, the user performs gameplay validation manually. If the
user asks the AI to verify scene boot specifically, instantiate the real scene:

```powershell
.\Godot_v4.6.3-stable_win64.exe --headless --path . res://scenes/BattleScene.tscn --quit-after 3
```

Validate edited JSON when JSON files change. A successful parse is not a
substitute for the user's manual gameplay check.
