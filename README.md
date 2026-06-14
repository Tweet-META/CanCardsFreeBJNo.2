# Can Cards Free BJNo.2?

**Can Cards Free BJNo.2?** is a turn-based educational card RPG designed for the Chinese Club **(CCFT)** of the International Department of Beijing No.2 High School.

The project combines Chinese language learning with card-based RPG combat. Players command three club mascot characters, answer questions about pinyin, vocabulary, and Chinese culture, and use card abilities to defeat enemies and uncover the mystery behind a missing event in the school.

---

## Project Vision

The goal of this project is to create a small but complete educational game that connects language learning with interactive gameplay.

Instead of treating Chinese learning as memorization, the game turns language knowledge into battle power. Correct answers strengthen cards, increase **AP (Accumulated Power, instead of Advanced Placement)**, and allow characters to use stronger abilities. Wrong answers do not punish the player, making the game friendly for Chinese beginners.

---

## Core Gameplay

The core gameplay loop is:

```text
Choose Character
→ Select Card
→ (If using exclusive cards) Answer Question
→ Trigger Card Effect
→ Enemy Turn
```

Players use two types of cards during battle:

* **Exclusive Cards**
  Cards tied to a specific mascot character. These require the player to answer Chinese-learning questions.

* **Universal Cards**
  Cards usable by all characters. These do not require answering questions and help generate AP.

---

## Three Initial Characters (CCFT Mascots)

### βudding

* Attribute: Chinese Culture
* Passive: Increase AP growth

### 天才兔 (Genius Rabbit)

* Attribute: Pinyin
* Passive: Enhance team power

### Lawilim

* Attribute: Vocabulary
* Passive: Compensate for incorrect answers at random

---

## Learning System

The game includes three learning categories:

| Category   | Focus                                  |
| ---------- | -------------------------------------- |
| Pinyin     | Chinese pronunciation and romanization |
| Vocabulary | Chinese words and meanings             |
| Culture    | Chinese cultural knowledge             |

Questions are divided into three difficulty levels:

| Difficulty | Battle Bonus                      |
| ---------- | --------------------------------- |
| Easy       | Small damage / defense / AP bonus |
| Medium     | Medium bonus                      |
| Hard       | Larger bonus and skill activation |

Wrong answers do not cause damage, AP loss, or progress loss. The goal is to encourage participation rather than punish mistakes.

---

## AP System

In this project, **AP** means:

**Accumulated Power**

Characters gain AP mainly by using cards and answering questions correctly. Once AP reaches the required amount, the character can use a powerful skill card.

This system connects learning performance directly to gameplay progression.

---

## TOEFL System

In this project, **TOEFL** means:

**Testify Of Endless Friendship & Learning**

TOEFL is an in-game resource earned by defeating enemies. It can be used to purchase cards during a run and may later be used for unlocking additional content outside battle.

---

## SAT System

In this project, **SAT** means:

**Sino-Ability Total**

SAT represents long-term learning progress. Players earn SAT points after clearing stages, with a total score cap inspired by the real SAT scoring system.

---

## Current Development Status

The project is currently in MVP development.

Current focus:

* Basic battle scene
* Card selection system
* Chinese question system
* AP and skill mechanics
* Enemy turn logic
* Godot scene-based UI refactor
* Consistent hand-drawn paper-style assets

---

## Planned Features

* More enemies
* More question types
* More cards
* Stage progression
* Shop system refinement
* Character unlocks
* Better animations
* Sound effects and background music
* Bilingual interface support
* Improved UI based on Godot scene nodes

---


## Development Notes

This project is being developed as a learning-focused independent project. The current priority is to build a playable and understandable MVP before expanding content and polishing visuals.

The codebase is also being gradually refactored toward a more maintainable Godot workflow based on scene nodes, reusable UI components, and signal-based communication.
