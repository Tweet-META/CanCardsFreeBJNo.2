# Project Context

## Product

**Can Cards Free BJNo.2?** is a Godot 4.6 turn-based educational card RPG for foreign teachers learning Chinese through the Beijing No.2 High School Chinese Club.

The current deliverable is a small level-based MVP with:

- Main menu, language selection, settings, battle, shop, questions, battle log, and result flow.
- Main menu enters a data-driven map scene before any battle.
- Three fixed player characters: βudding (culture), 天才兔 (pinyin), and Lawilim (vocabulary).
- Three learning attributes: `pinyin`, `vocabulary`, and `culture`.
- Character-exclusive cards and a team-owned consumable general-card hand.
- Bilingual Chinese/English UI and question content.
- One battle containing a configurable enemy team of up to eight visible enemies.

The current map contains `map1` and level nodes near the meeting
table. Selecting a level enters the existing battle scene. The map image is
`assets/ui/map1.png`.

All levels reuse `BattleScene.tscn`. `data/levels.json` defines the battle
background and ordered waves. Each wave contains monster positions, and each
position randomly chooses one enemy from its candidate ID list.

Planned level extensions: the first level is expected to become the tutorial
level, and some levels may trigger story content after victory. Do not hardcode
level entry flow in a way that prevents future tutorial or post-clear story
hooks.

Do not treat the narrative and planned systems in `README.md` as implemented unless supported by current code. SAT progression, persistent collections, and story progression are not implemented.

## Core Battle Flow

1. Select a living player character.
2. Use one exclusive or team general card.
3. Drag targeted cards to an applicable player or enemy.
4. Answer a question when required.
5. Resolve the card and mark the acting character as used.
6. After every living character has acted, all living enemies act in array order.
7. Clearing a non-final wave generates the next wave and starts a fresh player turn.
8. Clearing the final wave resolves victory.

Question and result overlays lock card interaction. Wrong answers have no direct penalty.

## Current Rules

### Team AP

- AP belongs to the team, not individual characters.
- AP starts at `0` and is capped at `5`.
- Skill cards require their configured `skill_ap_cost`, currently `5`.
- Skills always request a hard question and clear all AP after use.
- Exclusive attack and defense cards always grant their configured base AP, currently `0.5`, even after a wrong answer.
- Correct answers add `0.5` / `0.7` / `1.0` AP for easy / medium / hard. Vocabulary compensation also triggers this difficulty bonus.
- General cards do not ask questions and are removed from the team hand after use.
- The starting general hand contains three cards randomly drawn with replacement.
- Defeating each enemy grants one random general card drawn with replacement from the same complete general-card pool.
- The general-card pool includes `potion_of_confucius`, `dagger_of_jingke`, `impenetrable_shield`, `menghan_toxin`, and `elixir_of_huatuo`.
- `impenetrable_shield` negates the next damage instance, `menghan_toxin` skips an enemy's next action, and `elixir_of_huatuo` heals one ally for 40% maximum HP.
- `gall_of_goujian` targets one ally and applies one turn of 50% Weakness followed by two turns of 30% Strength. Reuse during Weakness does nothing; reuse during Strength resets Strength to two turns.
- `insight_of_paoding` applies 30% Vulnerable for two turns and can coexist with Vulnerable from other sources.
- `smashed_cauldron` targets one ally and applies 100% Vulnerable and 30% Strength for two turns.
- `six_seven` directly removes 67 HP from a selected ally and is excluded from all random pools; it is granted only by developer tools or the `676767` battle input code.

### Questions

- Source: `data/questions.json`.
- Categories match the three learning attributes.
- Difficulties: `easy`, `medium`, `hard`.
- Attack and defense cards open a difficulty choice before drawing a question.
- Skills skip the choice and immediately draw from the `hard` pool.
- Battle questions are selected by difficulty across all three categories; card and character attributes do not constrain the category.
- If no exact category/difficulty question exists, `QuestionBank` falls back to the same category, then the first loaded question.
- Question text stored in JSON is converted to stable localization keys at runtime.
- Every drawn question is copied and its options are shuffled; the source question and correct-answer mapping remain unchanged.

### Damage and Defense

- Player characters and enemies have no fixed base defense stat.
- Player attack damage originates only from card `base_damage`.
- Player damage multiplier includes:
  - `+20%` per living pinyin character.
  - `+20%` when attacker and enemy attributes match.
  - The card's correct-answer difficulty bonus, when triggered.
- Incoming enemy damage is reduced by:
  - `20%` when the target character and attacking enemy share an attribute.
  - Temporary percentage reduction granted by defense cards.
- Both sides support fixed-value shields and percentage damage reduction.
- Percentage reduction resolves first; fixed shields absorb the remaining damage before HP.
- Fixed shields stack, persist until consumed, and lose their visual effect immediately at zero.
- The current playable content grants player percentage shields and enemy fixed shields; the inverse data paths already exist for future cards and skills.
- Persistent status effects are defined in `data/effects.json` and stored as runtime `StatusEffectData` instances.
- βudding's attack applies `20%` Vulnerable before damage, so the triggering hit is amplified. It lasts for the application turn and the following player turn.
- Genius Rabbit's attack deals `26` base damage to the selected enemy and `13` base damage to every other living enemy.
- Reapplying a status from the same actor and card/skill refreshes its duration and keeps the stronger value. The same status from different actor/source pairs is stored separately; Vulnerable from different sources stacks multiplicatively. UI source text displays the card or skill name, not the actor name.

### Attribute Passives

Passives belong to attributes, not named characters. Multiple living characters with the same attribute stack:

- Pinyin: team maximum HP and damage-card effects `+20%` each.
- Vocabulary: wrong answers have a cumulative `25%` chance per character to trigger the card bonus anyway, capped at `100%`.
- Culture: every AP gain receives `+0.25` per character.

The pinyin maximum-HP multiplier is calculated once when battle setup completes. Other passive counts use living characters.

### Enemy Prototypes

Nine enemy definitions exist as every combination of three attributes and three prototypes:

- `bun`: attacks every living player character.
- `slime`: has no attack; grants `ability_power` shield to every living enemy.
- `mask`: attacks one random living player character.

`prototype` identifies the enemy family, while combat behavior comes from its
weighted `abilities` array. Every ability has an `id`, `power`, and `weight`;
an enemy with multiple entries randomly selects one each turn.

### Shop and Currency

- Defeated enemies award `New TOEFL`.
- Battle currency is capped at `6`.
- Shop displays four random general cards drawn with replacement from all `type = general` definitions.
- Refresh costs `0.5`.
- Purchased cards are added to the shared team general hand.
- During the player turn, a general card can be dragged onto the top-right shop button and sold for `shop_price * 0.6`, rounded upward to one decimal place; selling does not consume a character action.
- General cards can therefore enter the hand through the starting draw, enemy drops, developer tools, or shop purchases.

## Content Sources

- Cards and card values: `data/cards.json`
- Player characters and default team: `data/characters.json`
- Enemy definitions: `data/enemies.json`
- Persistent effect definitions and icon paths: `data/effects.json`
- Level backgrounds, waves, and enemy lineups: `data/levels.json`
- Questions: `data/questions.json`
- Chinese and English text: `data/localization/translations.csv`
- Runtime art: `assets/`
- Reference/source art not used directly by runtime: `images/`

Localization keys, not display strings, are stored in character, enemy, and card data.

`translations.csv` remains the editable source. Its generated
`translations.zh_CN.translation` and `translations.en.translation` resources
are registered in `project.godot` for runtime and exported builds.

The lower-left battle information panel is data-driven. Every player and enemy
entry provides one complete localized `description`; its lines and wording are
not assembled by UI code.
