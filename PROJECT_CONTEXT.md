# Project Context

## Product

**Can Cards Free BJNo.2?** is a Godot 4.6 turn-based educational card RPG for foreign teachers learning Chinese through the Beijing No.2 High School Chinese Club.

The current deliverable is a single-stage MVP with:

- Main menu, language selection, settings, battle, shop, questions, battle log, and result flow.
- Three fixed player characters: βudding (culture), 天才兔 (pinyin), and Lawilim (vocabulary).
- Three learning attributes: `pinyin`, `vocabulary`, and `culture`.
- Character-exclusive cards and a team-owned consumable general-card hand.
- Bilingual Chinese/English UI and question content.
- One battle containing a configurable enemy team of up to eight visible enemies.

Do not treat the narrative and planned systems in `README.md` as implemented unless supported by current code. SAT progression, multiple stages, persistent collections, and story progression are not implemented.

## Core Battle Flow

1. Select a living player character.
2. Use one exclusive or team general card.
3. Drag targeted cards to an applicable player or enemy.
4. Answer a question when required.
5. Resolve the card and mark the acting character as used.
6. After every living character has acted, all living enemies act in array order.
7. Start the next player turn, restoring action availability and clearing temporary player damage reduction.

Question and result overlays lock card interaction. Wrong answers have no direct penalty.

## Current Rules

### Team AP

- AP belongs to the team, not individual characters.
- AP starts at `0` and is capped at `5`.
- Skill cards require their configured `skill_ap_cost`, currently `5`.
- Skills always request a hard question and clear all AP after use.
- General cards do not ask questions and are removed from the team hand after use.
- The starting general hand contains three cards randomly drawn with replacement.

### Questions

- Source: `data/questions.json`.
- Categories match the three learning attributes.
- Difficulties: `easy`, `medium`, `hard`.
- Normal cards use the requested difficulty; skill cards force `hard`.
- If no exact category/difficulty question exists, `QuestionBank` falls back to the same category, then the first loaded question.
- Question text stored in JSON is converted to stable localization keys at runtime.

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

Prototype behavior is implemented once in `BattleManager`; attribute variants are data entries in `data/enemies.json`.

### Shop and Currency

- Defeated enemies award `New TOEFL`.
- Battle currency is capped at `6`.
- Shop displays four random general cards drawn with replacement from all `type = general` definitions.
- Refresh costs `0.5`.
- Purchased cards are added to the shared team general hand.

## Content Sources

- Cards and card values: `data/cards.json`
- Player characters and default team: `data/characters.json`
- Enemies and default enemy team: `data/enemies.json`
- Questions: `data/questions.json`
- Chinese and English text: `data/localization/translations.csv`
- Runtime art: `assets/`
- Reference/source art not used directly by runtime: `images/`

Localization keys, not display strings, are stored in character, enemy, and card data.

The lower-left battle information panel is data-driven. Every player and enemy
entry provides one complete localized `description`; its lines and wording are
not assembled by UI code.
