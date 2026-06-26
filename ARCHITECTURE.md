# Architecture

## Runtime Entry Points

- Engine: Godot `4.6`, GDScript, GL Compatibility renderer.
- Main scene: `res://scenes/MainMenu.tscn`.
- Viewport: `1280 × 720`, `canvas_items`, aspect `expand`.
- Autoloads:
  - `LanguageManager`: builds translations from CSV and persists locale.
  - `SettingsManager`: persists developer-mode state in `user://settings.cfg`.

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
├── PlayerTeam
└── EnemyTeam
```

`QuestionLayer` deliberately renders above battle cards, units, the shop, and developer controls.

## Map

`MainMenu` starts `MapScene.tscn`. `MapDatabase` loads ordered map definitions
from `data/maps.json`; `MapScene` displays the selected map image and keeps an
extensible `LevelLayer`. Maps reference level IDs; `LevelDatabase` loads
position, marker, localization keys, unlock state, and target scene from
`data/levels.json`. `LevelNode.tscn` emits the selected `LevelData`.

`LevelDatabase` keeps the active level ID across the map-to-battle scene
change. `BattleManager` loads that level and generates each wave through
`GameDataFactory.create_level_wave()`. Wave changes replace only the enemy
team; player HP, AP, cards, currency, and shop state persist.

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

`BattleHandController` owns the runtime hand UI only: `CardButton` instancing, exclusive/general fan layouts, hover recovery, drag visual state, negative team-card index encoding on the UI side, and the general-card consume particle animation. It does not apply card rules.

Focused UI scenes own their own visuals and local behavior:

- `BattleTopBar`
- `BattleInfoPanel`
- `BattleLogPanel`
- `QuestionPanel`
- `ResultPanel`
- `ShopPanel` / `ShopCardItem`
- `SettingsPanel`
- `DeveloperControls`
- `CancelDropArea`
- `CardButton`
- `CharacterStandee`
- `EnemyStandee`
- `ShieldVisual`, shared by both standees for fixed and percentage shields
- `StatusEffectIcon`, instantiated inside a standee for each persistent effect

`BattlefieldController` creates standee scene instances, performs hit testing, and calculates layouts for one to eight enemies. Dead enemies are omitted when the battlefield is refreshed.

`ShieldVisual` receives a fixed shield value and a percentage reduction value. It is visible when either is positive and uses additive blending for `assets/effects/shield.png`.

`EnemyStandee` reads `EnemyData.active_effects` and instantiates one `StatusEffectIcon` per effect. Effect icons load their configured texture only when the asset exists, allowing effect logic to be implemented before final art is imported.

`BattleHandController` creates `CardButton` instances because hand contents are runtime data. `ShopPanel` similarly creates `ShopCardItem` instances. Static panel structure belongs in `.tscn`; repeated data-driven items are allowed to be instantiated from reusable scenes.

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

### General-Card UI Indices

Exclusive card indices are non-negative character-card indices. Team general cards are encoded as:

```text
encoded_index = -team_card_index - 1000
```

Both `BattleUI` and `BattleManager` depend on `TEAM_GENERAL_CARD_INDEX_OFFSET = 1000`. Change both sides together or replace the signal contract entirely.

### Localization

`translations.csv` is the source of truth. Its generated locale-specific `.translation` resources are registered through `project.godot`; `LanguageManager` only switches and saves locales and does not parse the CSV.

Display names, descriptions, logs, and question text use translation keys. When adding a question with ID `example`, localization keys must follow:

```text
Q_EXAMPLE_PROMPT
Q_EXAMPLE_O0 ... Q_EXAMPLE_ON
Q_EXAMPLE_EXPLANATION
```

## Verification

Automated smoke-test scripts were removed. Developers should validate gameplay
manually in Godot after data, scene, or rule changes. AI-assisted changes should
prefer static checks and editor parsing only when useful, and should not run
gameplay smoke scripts unless new ones are explicitly requested.
