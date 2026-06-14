# Can Cards Free BJNo.2?

**Can Cards Free BJNo.2?** is a turn-based educational card RPG designed for the Chinese Club **(CCFT)** of the International Department of Beijing No.2 High School.

The project combines Chinese language learning with card-based RPG combat. The player commands characters to fight, answers questions about pinyin, vocabulary, and Chinese culture, and uses card abilities to defeat enemies and uncover the mystery behind a missing event in the school.

---

## Backgrounds

Chinese Club For Teachers, or CCFT, is a club for the foreign teachers in the school to learn Chinese and its culture. Here, three students are the teachers, and the real teachers are the students. The title of this game, **Can Cards Free BJNo.2?**, also comes from the abbreviation CCFT (**C**an **C**ards **F**ree beijing-number-**T**wo).

In the game, everyone in the school disappeared mysteriously, and the only clue left is a box of cards in the conversation room, which is exactly where the Chinese Club usually meets. You will go on an adventure inside the school along with the mascots of Chinese Club, who came to life because of the same anomaly. Eventually, you will solve the mystery and free everyone!

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

The player uses two types of cards during battle:

* **Exclusive Cards**
  Cards tied to a specific mascot character. These require the player to answer Chinese-learning questions.

* **Universal Cards**
  Cards usable by all characters. These do not require answering questions and help generate AP.

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

## Planned Features

* More enemies
* More questions
* More cards
* More characters
* Better animations and artworks
* Sound effects and background music
* Bilingual interface support
* ...

---


## Development Notes

Inspired by Angry Birds Epic and also our club activities, the idea of making a game for the Chinese Club came to my mind in February.

(To be honest, now I think it's more like Slay the Spire, but I only heard about this game and knew nothing about the details at that time)

I'd always wanted to see people playing my game, and I thought a card game would be really fun, so I wrote the game design document soon and used AIs to polish that. I thought I could use AIs as well, to help finish the game in the winter vacation, but I was terribly wrong. Initially I used unity, but unity was too complex that it took me days to get familiar, and I wasn't even close to really making MY game. At last I quitted, and the spring semester began.

After the AP exams, I restarted this project. I found out Godot and decided to switch to it, and I planned to finish the game at the end of June. Later I also learned about codex, and it really helped me a lot! So in the middle of June, which is now, I (suppose??? I) completed the basic battle scene, and hopefully I can finish the demo version soon. Currently I'm working with the UI, codex didn't use nodes and I'm trying to fix that.

I do have to say that most jobs were done by codex, but really it would take me months to make the game 100% without AI, so yeah what can I say. Most importantly, I really want the teachers to play the game during our last club activity this semester, so everything's in a hurry. But perhaps I'll make another game next time, and I'll try to participate more!
