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
scripts/*Test.gd        Headless smoke and regression tests
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
- Damage, AP, defense-card, enemy-prototype, reward, and victory/defeat rules.
- Shop purchases and developer test actions.

It must not manipulate UI nodes. It publishes:

- `state_changed`
- `question_requested`
- `result_requested`
- `log_added`

### Wiring

`BattleScene.gd` is only the signal connection layer between `BattleManager`, `BattleUI`, `QuestionPanel`, and `ResultPanel`.

### UI

`BattleUI` owns transient presentation state: selected indices, hover state, drag state, card interaction locks, and panel refresh coordination. It emits user intentions and must not resolve combat.

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

`BattlefieldController` creates standee scene instances, performs hit testing, and calculates layouts for one to eight enemies. Dead enemies are omitted when the battlefield is refreshed.

`ShieldVisual` receives a fixed shield value and a percentage reduction value. It is visible when either is positive and uses additive blending for `assets/effects/shield.png`.

`BattleUI` creates `CardButton` instances because hand contents are runtime data. `ShopPanel` similarly creates `ShopCardItem` instances. Static panel structure belongs in `.tscn`; repeated data-driven items are allowed to be instantiated from reusable scenes.

## Important Data Contracts

### Card IDs and Effects

Characters reference card IDs from `characters.json`. `effect_id` is dispatched by `BattleManager`; adding an unknown effect requires a corresponding rule implementation.

Current effects:

- `gain_team_ap`
- `attack_single`
- `defend_single`
- `skill_attack_single`
- `skill_attack_all`

All `type = general` cards automatically enter both the starting-hand and shop random pools.

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

`translations.csv` is the source of truth. Generated `.translation` files are imported artifacts.

Display names, descriptions, logs, and question text use translation keys. When adding a question with ID `example`, localization keys must follow:

```text
Q_EXAMPLE_PROMPT
Q_EXAMPLE_O0 ... Q_EXAMPLE_ON
Q_EXAMPLE_EXPLANATION
```

## Tests

Headless tests cover:

- Main battle flow: `SmokeTest.gd`
- Character/enemy databases: `ActorDatabaseSmokeTest.gd`
- Cards and pools: `CardDatabaseSmokeTest.gd`
- Questions: `QuestionBankSmokeTest.gd`
- Localization: `LocalizationSmokeTest.gd`
- Attribute stacking: `PassiveStackSmokeTest.gd`
- Enemy abilities: `EnemyAbilitySmokeTest.gd`
- Enemy layouts: `EnemyLayoutSmokeTest.gd`
- Developer mode and UI information panel behavior.
