# Architecture

## Runtime Entry Points

- Engine: Godot `4.6`, GDScript, GL Compatibility renderer.
- Main scene: `res://scenes/MainMenu.tscn`.
- Viewport: `1280 × 720`, `canvas_items`, aspect `expand`.
- Autoloads:
  - `LanguageManager`: builds translations from CSV and persists locale.
  - `SettingsManager`: persists developer-mode state in `user://settings.cfg`.

## Development Tooling

Codex has access to a Godot MCP server for this project. The MCP is configured
against the project-local Godot executable:

```text
Godot_v4.6.3-stable_win64.exe
```

Use MCP for editor-aware inspection and simple scene operations:

- Confirm Godot version and project metadata.
- Read current debug output after the user reproduces an issue.
- Create or save scenes when needed.
- Add straightforward scene nodes and load Sprite2D textures.

The MCP is not a runtime dependency and does not change the architecture rules.
Scene structure should remain editor-owned, combat rules should remain outside
UI scripts, and gameplay validation remains manual unless explicitly requested.

## Directory Responsibilities

```text
assets/                 Runtime textures
data/                   Editable JSON content and localization CSV
scenes/                 Main scenes and reusable UI scenes
scenes/ui/              Independent visual UI panels and standees
scripts/battle/         Battle orchestration and rules
scripts/data/           Runtime data models, databases, and factories
scripts/localization/   Translation loading and locale persistence
scripts/settings/       Global settings persistence
scripts/ui/             UI behavior and interaction coordination
scripts/map/            Map scene presentation and map switching
images/                 References and non-runtime source images
```

## Battle Scene Tree

```text
BattleScene (Node2D, BattleScene.gd)
├── BattleManager (Node, BattleManager.gd)
├── CanvasLayer
│   └── BattleUI
├── QuestionLayer (CanvasLayer, layer 100)
│   ├── QuestionPanel
│   └── ResultPanel
```

`QuestionLayer` deliberately renders above battle cards, units, the shop, and developer controls.

## Map

New saves enter `OpeningSequence.tscn`, which plays the optional configured SpriteFrames once and then starts `MapScene.tscn`; an empty story path currently skips the opening. Existing saves with `opening_completed` enter the map directly. `MapDatabase` loads ordered map definitions
from `data/maps.json`; `MapScene` displays the selected map image and keeps an
extensible `LevelLayer`. Maps reference level IDs; `LevelDatabase` loads marker,
localization keys, unlock state, and target scene from `data/levels.json`.
`MapScene.tscn` contains editor-positioned `LevelNode.tscn` instances whose
exported `level_id` values bind them to data and emit the selected `LevelData`.

`LevelDatabase` keeps the active level ID across the map-to-battle scene
change. `MapScene` opens an in-scene preparation panel before entering battle;
the selected player character IDs and optional Learning Goal source are stored
transiently through `LevelDatabase`. `GameDataFactory` resolves the team and
goal without coupling the preparation UI to battle rules. `BattleManager` loads
that level and generates each wave through `GameDataFactory.create_level_wave()`.
Wave changes replace only the enemy team; player HP, AP, cards, currency, shop
state, and the selected Learning Goal persist.

### First-Level Tutorial and Unlocks

`LevelData` parses `tutorial_id`, `requires_learning_goal`, and a derived `general_cards_enabled` flag. Level 1 references `first_battle` and requires a Learning Goal before its start button or map entry can proceed. Other levels retain optional goals. `general_cards_unlock_order` in level JSON is 5; active levels with lower orders disable the complete general-card/shop pipeline, including initial hands, enemy drops, purchases/sales, developer buttons, and the hidden code.

`TutorialDatabase` creates typed `TutorialData` from `data/tutorials.json`. `MapScene` hosts an editor-owned `TutorialGuide` showing the configured speaker and room/party/goal/entry messages. Preparation changes advance it; the guide hides while the goal drawer is open. Tutorial battle messages are emitted once per step and attempt by `BattleManager` through the existing log, with `BattleState.tutorial_log_unread` driving `TutorialLogHint`. Opening the log clears the reminder, and newly arriving hints are considered read while it stays open. Tutorial mode uses an Inspector-adjustable larger log panel for complete instructions.

Save version 2 stores `opening_completed` and `tutorial_completed`. Old saves skip the new opening; those already past level 1 default to a completed tutorial. First-level victory persists completion along with ordinary level advancement. Loss/retry leaves it unfinished. Opening story art is not implemented: configure `opening_sequence.sprite_frames_path` and its animation name when the real sequence is ready.

Level battle data uses this shape:

```json
"id": "level1",
"map_id": "map1",
"battle_background": "res://assets/ui/conversation_room.png",
"wave": [
  {
    "monster": [
      ["pinyin_bun", "culture_bun"],
      ["vocab_slime"],
      ["culture_mask", "pinyin_mask"]
    ]
  }
]
```

Each nested candidate array is one battlefield position. One enemy is randomly
chosen per position when the wave starts, with a maximum of eight positions.

`QuestionPanel` has two modes: difficulty selection for normal attack/defense
cards, and four-option question display. Skills bypass difficulty selection.

`BattleUI.tscn` contains:

```text
BattleUI
├── Background
├── Wash
├── Root
│   ├── BattleTopBar
│   ├── Battlefield
│   │   ├── PlayerLayer
│   │   ├── EnemyLayer
│   │   ├── ArrowLayer
│   │   └── CancelDropArea
│   └── Bottom
│       ├── InfoSpace
│       ├── CardsArea
│       │   ├── ExclusiveCards
│       │   ├── CardGroupGap
│       │   └── GeneralCards
│       └── BattleLogPanel
├── BattleInfoPanel
├── ShopPanel
└── DeveloperControls
```

## Layer Boundaries

### Data

`CharacterData`, `EnemyData`, `CardData`, and `QuestionData` are typed runtime objects. `BattleState` is the single mutable battle-state container.

Database classes parse JSON lazily and create fresh runtime instances:

- `CharacterDatabase`
- `EnemyDatabase`
- `CardDatabase`
- `QuestionBank`

`GameDataFactory` is the battle-facing construction facade. Database caches retain raw dictionaries, not mutable `Resource` instances.

### Rules

`BattleManager` owns:

- Battle initialization and retries.
- Phase validation and turn progression.
- Card target and AP validation.
- Question result processing.
- Card `effect_id` dispatch.
- Damage, AP, defense-card, weighted enemy-ability, reward, and victory/defeat rules.
- Shop purchases, general-card sales, and developer test actions.

It must not manipulate UI nodes. It publishes:

- `state_changed`
- `question_requested`
- `result_requested`
- `log_added`

### Wiring

`BattleScene.gd` is only the signal connection layer between `BattleManager`, `BattleUI`, `QuestionPanel`, and `ResultPanel`.

### UI

`BattleUI` owns transient battle-screen presentation state: selected indices, target highlights, card interaction locks, and panel refresh coordination. It emits user intentions and must not resolve combat.

`BattlefieldView` is the battle-field node attached inside `BattleUI.tscn`. It retains `CharacterStandee` and `EnemyStandee` instances across refreshes, performs hit testing, and reads editor-owned slot nodes for player and enemy placement. It removes defeated enemies and replaces identities on retries or wave changes, without restarting surviving units' animations.

### Battle Presentation

Characters reference editor-owned `SpriteFrames` through `battle_animation_path` in `data/characters.json`. `CharacterMotion.tscn` fits the full transparent canvas into the existing portrait area, loops idle, and plays attack/hurt once. Missing animation resources fall back to static portraits. The three current characters use 256 × 256 sequences at 60 fps.

Selection moves only `CharacterMotion/VisualRoot` along a constant-gravity jump. The standee and HP bar stay at their slot baseline; the portrait lands at its original position. Jump height and gravity are exported Inspector properties. The previous persistent elevation and blue foot marker have been removed.

`PortraitHitButton` caches an alpha mask and tight opaque bounds from each body's texture. Player masks use the idle body texture rather than attack composites; enemies use their static portrait. The child button, selection style, and target outline share these bounds under the moving visual layer. Both native selection and `BattlefieldView` card hit tests use the same mask, excluding HP bars, status UI, transparent margins, and attack effects. Standee roots are passive layout Controls.

Answer submission stores its correctness and compensation result in `BattleState` and enters `ANSWER_RESULT`. Closing the explanation starts `ACTION_RESOLUTION`: damaging cards play the actor's attack sequence, then resolve their existing effects. Completing the party's actions starts `ENEMY_TURN`.

`BattleManager.presentation_requested(request_id, kind, actor_index, targets)` requests visual steps. `BattleScene` routes them to `BattleUI` and acknowledges completion through `complete_presentation(request_id)`. Only the manager advances combat. Retry/scene-exit generation guards prevent old callbacks from advancing a new battle.

The enemy turn starts with `TurnBanner`. Each living enemy selects its weighted ability once, plays an attack or support placeholder, resolves the ability, refreshes HP, and waits for player hurt sequences before the next enemy acts. Group hits animate all affected players together. Stunned enemies skip their entire action. Existing shields, charge progression, target locks, status durations, rewards, and wave rules remain in the rules layer.

Enemy attack placeholders live in `EnemyStandee.tscn`: `AttackAnimation` contains an editor-adjustable lunge; `Content/Portrait/VisualRoot/AttackOrigin/AttackSprite` reserves a position and SpriteFrames slot for future art. Non-attacking abilities use a visual pulse. Turn-banner duration, character speed, and enemy recovery delay are Inspector properties. Card and shop inputs are blocked during action resolution and enemy turns.

`BattleHandView` is the hand node attached to `CardsArea` in `BattleUI.tscn`. It owns the runtime hand UI only: `CardButton` instancing, exclusive/general fan layouts, hover recovery, drag visual state, negative team-card index encoding on the UI side, and the general-card consume particle animation. It does not apply card rules. Its layout tuning values are exported so the Godot editor can adjust them without editing script constants.

Focused UI scenes own their own visuals and local behavior:

- `BattleTopBar`
- `BattlefieldView`
- `BattleHandView`
- `BattleInfoPanel`
- `BattleLogPanel`
- `QuestionPanel`
- `ResultPanel`
- `PreparationPanel`
- `ShopPanel` / `ShopCardItem`
- `SettingsPanel`
- `DeveloperControls`
- `CancelDropArea`
- `CardButton`
- `CharacterSelectButton`
- `CharacterStandee`
- `EnemyStandee`
- `ShieldVisual`, shared by both standees for fixed and percentage shields
- `StatusEffectIcon`, instantiated inside a standee for each persistent effect

`ShieldVisual` receives a fixed shield value and a percentage reduction value. It is visible when either is positive and uses additive blending for `assets/effects/shield.png`.

`EnemyStandee` reads `EnemyData.active_effects` and instantiates one `StatusEffectIcon` per effect. Effect icons load their configured texture only when the asset exists, allowing effect logic to be implemented before final art is imported.

`BattleHandView` creates `CardButton` instances because hand contents are runtime data. `ShopPanel` similarly creates `ShopCardItem` instances. Static panel structure belongs in `.tscn`; repeated data-driven items are allowed to be instantiated from reusable scenes.

## Important Data Contracts

### Card IDs and Effects

Characters reference card IDs from `characters.json`. `effect_id` is dispatched by `BattleManager`; adding an unknown effect requires a corresponding rule implementation.

Current effects:

- `gain_team_ap`
- `attack_single`
- `attack_single_apply_effect`
- `attack_primary_splash`
- `damage_current_hp_percent`
- `apply_status_ally`
- `apply_status_enemy`
- `heal_max_hp_percent`
- `gall_of_goujian`
- `apply_dual_status_ally`
- `direct_hp_loss`
- `defend_single`
- `skill_attack_single`
- `skill_attack_all`

All `type = general` cards automatically enter both the starting-hand and shop random pools.
The same pool also supplies one random card whenever an enemy's death rewards
are collected.

### Persistent Effects

Static effect metadata lives in `data/effects.json` and is loaded by `EffectDatabase`. Cards supply the runtime value and duration through `status_effect_id`, `status_effect_value`, and `status_effect_duration`.

`EnemyData.apply_status_effect()` uses `effect_id + source_id` as its stack key. Card effects encode the actor ID and card ID into `source_id`, while `source_name` is the localized card or skill name shown in the UI. The same actor/source refreshes its existing effect; different sources retain separate instances. Vulnerable instances from different sources multiply together. Durations advance at the start of each player turn. Incoming-damage effects are resolved by `EnemyData.take_damage()` before percentage reduction and fixed shields.

### Attributes

JSON uses stable ASCII IDs: `pinyin`, `vocabulary`, `culture`, `none`.

`LearningAttribute.from_id()` converts these to the project's internal Chinese values. Attribute comparisons must use `LearningAttribute` constants or converted runtime values.

Matching player and enemy attributes have no intrinsic combat interaction. Do not add same-attribute attack bonuses or damage reduction to shared damage calculations.

### Learning Goals

Automatic character passives and attribute-count stacking do not exist. Before a battle, `PreparationPanel` selects one unlocked character as the Learning Goal source, required for the level-1 tutorial and optional elsewhere. This selection is independent from the active party and is stored transiently by `LevelDatabase`; it is not save data.

`GameDataFactory.create_active_learning_goal()` resolves the source character's attribute through `LearningGoalDatabase` and `data/learning_goals.json`. `BattleState` owns the resulting single `LearningGoalData` for the full battle, so the bonus remains active regardless of party composition or character deaths. No selection uses neutral multipliers and does not block level entry.

The preparation UI is split into `LearningGoalButton`, `LearningGoalDrawer`, and reusable `LearningGoalEntry` scenes. The drawer must list every character currently unlocked by the active save, not only selected party members or hardcoded character IDs.

### General-Card UI Indices

Exclusive card indices are non-negative character-card indices. Team general cards are encoded as:

```text
encoded_index = -team_card_index - 1000
```

Both `BattleUI` and `BattleManager` depend on `TEAM_GENERAL_CARD_INDEX_OFFSET = 1000`. Change both sides together or replace the signal contract entirely.

### Localization

BattleManager formats concise outcome logs with localization keys. Damage lines name the attacker and target; healing, direct HP loss, defense, and status lines describe the affected unit only. `_emit_status_effect_result` includes configured percentages, charges, durations, and delayed timing without sources. Answer feedback remains in the result panel; the log has no card/question/answer narration or damage calculations. AP logs report actual capped gains. Tutorial messages and concise round/action feedback remain available.

Question data uses only `id`, `difficulty`, `prompt`, `options`, `correct_index`, and `explanation`. `QuestionData`, JSON parsing, fallback definitions, and `QuestionPanel` do not carry category/attribute metadata. `QuestionBank` pools solely by difficulty, including every topic; historical question ID prefixes have no filtering role. The panel header displays difficulty and prompt only.

`translations.csv` is the source of truth. Its generated locale-specific `.translation` resources are registered through `project.godot`; `LanguageManager` only switches and saves locales and does not parse the CSV.

Display names, descriptions, logs, and question text use translation keys. When adding a question with ID `example`, localization keys must follow:

```text
Q_EXAMPLE_PROMPT
Q_EXAMPLE_O0 ... Q_EXAMPLE_ON
Q_EXAMPLE_EXPLANATION
```

## Level Loading

`MapScene` confirms preparation, then calls the `SceneTransition` scene autoload (CanvasLayer 200). Its persistent iris closes from the edges to the center, reveals `LoadingScreen` with the conversation-room placeholder, closes again when loading completes, and reveals the initialized battle. UI layout and shader settings live in reusable scenes; closing/reveal durations are exported.

`LevelResourceManifest` gathers the target PackedScene, background, selected characters' SpriteFrames and portraits, card art/effect icons, and every wave's candidate enemy portrait. General-card art is included only when enabled for that level. This covers resources referenced indirectly in JSON that the PackedScene alone cannot preload.

`SceneTransition` submits sequential threaded requests and polls real Godot progress each frame. The overall fraction weights each request by its dependency count plus one. It retrieves only completed resources and keeps strong references through the battle, including future waves. After switching beneath black, it waits for `BattleScene.loading_ready` and layout before revealing combat. Failed requests offer retry or return to the intact map.


## Verification

Automated smoke-test scripts were removed. Developers should validate gameplay
manually in Godot after data, scene, or rule changes. AI-assisted changes should
prefer static checks and editor parsing only when useful, and should not run
gameplay smoke scripts unless new ones are explicitly requested.

## Locker and Level Clear Stories

Level 5 is Locker in the upper-left room of map1. It contains only David with 240 HP and equally weighted copy_player_card/use_general_card abilities, with a 6 New TOEFL reward. Enemy JSON supplies separate body and magic SpriteFrames paths; EnemyStandee reuses CharacterMotion and independently plays ambient/burst magic. Only the body determines targeting. All these resources are included in the threaded level manifest.

`data/story_events.json` supplies optional full-screen sequence slots and localized fallback dialogue. MapScene opens pending StoryPanel events after a victory return. The empty level-3 slot immediately shows Budding announcing Tiancaitu. The level-5 dialogue uses a clean David portrait, announces his stall, and describes permanent card unlocks. Save version 3 persists cleared levels, acknowledged events, and general-card ownership; legacy progress conservatively infers preceding clears and restores character rewards. Replayed clears do not repeat acknowledged stories.

General-card features require the level-5 clear plus active level order >=5; the first David fight remains locked. After clearing, the Locker node opens VendorPanel, with an explicit replay button. It reuses ShopCardItem to display permanent unlock prices and ownership. SaveManager validates and deducts Old TOEFL once per unlock. Existing normal general cards have `initially_unlocked: true`; new cards omit it or set false, appear in the stall, and enter all normal battle pools only after purchase. Hidden cards remain excluded by available_in_pool. Victory converts remaining battle New TOEFL into saved integer Old TOEFL at 1:5.

## Revised Budding and Tiancaitu Cards

CardData owns hit_count, AP switch threshold, distinct extra-target count, explicit chain_damage_sequence, compact summary keys, and typed CardStatusOption entries. BattleManager dispatches multi-hit single-target skills, AP-selected patterns, and chain skills. AP is paid before skill hits. All player attack packets pass through _deal_player_hit for preexisting attack_ap marks and duplicate-safe death rewards. Each chain hit rolls its status after dealing damage.

CharacterData combines active damage_reduction statuses with ordinary turn defense under the existing 85% cap. EnemyData now supplies an outgoing weakness/strength multiplier. All enemy damage goes through _resolve_enemy_hit, which resolves HP loss first, grants hurt_ap for positive actual loss, then returns that amount with counterattack. Reflection uses enemy defenses and no player amplification; a reflected kill cancels remaining group hits. Counterattack and AP-mark duration defaults are one turn, while Budding defense lasts two. Status icons support fractional AP values and reuse existing effect textures. No scene structure changes are required.

## Enemy Card Actions and Currency Settlement

EnemyAbilityData owns explicit card_ids for enemy-only draw pools. BattleManager chooses copied cards before presentation, then mirrors attacks onto living player targets and self-targets support. Anomaly David samples living player attack/defense cards or seven fixed general cards with equal ability weights; Tiancaitu copies use the player team AP snapshot. EnemyData supports timed reduction, immunity charges, healing, weakness, copied retaliation and capped local AP. Retaliation on either side grants actual-HP-loss AP without recursively triggering the other counter.

StatusEffectData.skip_next_turn_tick protects enemy-phase casts from immediate expiration at the upcoming player boundary. Player stuns mark the next character action used; an entirely stunned team queues a generation-guarded enemy turn. Slime support grants max shields and logs only actual increases. Card question magnitudes are fixed: the only answer/difficulty reward is AP, including hard-question skills.

BattleState caps New TOEFL at 120 and resets a per-battle currency_settled guard. Final victory deposits floor(remaining New TOEFL * 5) Old TOEFL through SaveManager before advancing progression. Duplicate final checks cannot deposit again. The victory panel displays the converted amount; defeat does not deposit.
