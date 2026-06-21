# Can Cards Free BJNo.2? Gameplay Guide

> This document records the gameplay systems, rules, and values currently implemented in the project.  
> Systems that are still in the design stage, such as levels, stage ratings, and Old TOEFL, are not included.

## 1. Game Overview

*Can Cards Free BJNo.2?* is a 2D turn-based card RPG designed for Chinese-language learners.

The player commands three members of the Chinese Club and defeats enemies by selecting characters, playing cards, answering Chinese questions, and combining status effects.

The current core gameplay loop is:

1. Select a stage from the map.
2. Enter the player turn.
3. Click a character who can still act.
4. Select or drag a card.
5. If the card requires a question, select a difficulty and answer it.
6. Resolve the card effect and AP gain.
7. After all three surviving characters have acted, enter the enemy turn.
8. Enemies act one by one.
9. Begin the next player turn and continue until one side is defeated.

## 2. Basic Controls

### 2.1 Selecting a Character

- Click a character portrait on the left to select that character.
- The selected character moves upward and displays a blue selection marker.
- The information panel in the bottom-left displays the currently inspected character's description.
- Characters who have already acted are grayed out, but can still be clicked for inspection.
- Each surviving character may use only one card per player turn.

### 2.2 Selecting an Enemy

- Click an enemy on the right to view its description in the bottom-left information panel.
- Cards that require an enemy target must be dragged onto an enemy.
- While dragging, the card remains in the hand area and an arrow is drawn toward the target.
- Valid targets are highlighted.

### 2.3 Targeting an Ally

The following cards must be dragged onto a surviving allied character:

- The defense card belonging to each of the three characters.
- Impenetrable Shield.
- Elixir of Huatuo.
- Gall of Goujian.
- Smashed Cauldron.

### 2.4 Canceling a Card

- A cancel area appears at the bottom of the screen while a card is being dragged.
- Drag the card into the cancel area and release it to cancel the play.
- A card that requires a target is also canceled automatically if it is released without a valid target.

### 2.5 Selling a General Card

- While dragging a general card, the Shop button in the top-right changes to “Sell.”
- The card's selling price appears below the button.
- Drag the card onto the Sell button and release it to sell the card.
- Selling a card does not consume a character's action.
- The selling price is `60%` of the purchase price, rounded up to one decimal place.

## 3. Turn Rules

### 3.1 Player Turn

- During each player turn, every surviving character has one action.
- The player may choose the acting order of the three characters freely.
- Playing either an exclusive card or a general card consumes the selected character's action.
- After all surviving characters have acted, the enemy turn begins automatically.
- There is currently no manual End Turn button.

### 3.2 Enemy Turn

- All surviving enemies act one by one in team order.
- A stunned enemy skips its action.
- After all enemies have acted, the next player turn begins automatically.

### 3.3 Wave Transitions

- A stage may contain multiple waves.
- When all enemies in the current wave are defeated, the next wave is spawned automatically.
- Changing waves does not reset allied HP, AP, general cards, New TOEFL, or the shop.
- The player always acts first in a new wave.
- Victory is achieved only after every enemy in the final wave has been defeated.

## 4. Attribute System

The game has three learning attributes:

- Pinyin
- Vocabulary
- Culture

### 4.1 Matching-Attribute Advantage

When an allied character attacks an enemy with the same attribute:

- The damage multiplier is increased by an additional `20%`.

When an enemy attacks an allied character with the same attribute:

- That character gains `20%` damage reduction.

### 4.2 Attribute Passives

Passives are tied to attributes rather than specific character IDs. If more characters with the same attribute are added in the future, their passives can stack.

#### Pinyin Passive

Each Pinyin character provides:

- The team's maximum HP is increased by `20%` at the start of battle.
- While that Pinyin character is alive, the effects of allied damage cards are increased by `20%`.

Multiple Pinyin characters can stack this passive.

#### Vocabulary Passive

Each surviving Vocabulary character provides:

- After an incorrect answer, there is a `25%` chance that the card's correct-answer bonus will still trigger.

Multiple Vocabulary characters can stack this passive, up to a maximum chance of `100%`.

#### Culture Passive

Each surviving Culture character provides:

- Gain an additional `0.25 AP` whenever AP is gained.

Multiple Culture characters can stack this passive.

## 5. Allied Characters

The current team always consists of three characters.

### 5.1 βudding

- Attribute: Culture
- Base maximum HP: `110`
- Because the current team contains one Pinyin character, the actual maximum HP at the start of battle is `132`
- Passive source: Culture; all AP gains receive an additional `+0.25`

#### Culture Card

- Type: Attack card
- Base damage: `24`
- Target: One enemy
- Applies `20%` Vulnerability for two turns before dealing damage.
- Damage is then resolved, so this attack immediately benefits from the Vulnerability.
- The recorded source of the Vulnerability is “Culture Card.”

#### Club Guardian

- Type: Defense card
- Target: One allied character
- Base damage reduction: `15%`
- A correct answer further increases the damage reduction based on difficulty.
- The damage reduction lasts until the enemy turn following the current player turn has been fully resolved.

#### Qingming Spring Breeze

- Type: Skill card
- AP cost: `5`
- Base damage: `40`
- Target: All surviving enemies
- Always uses a Hard question.
- An incorrect answer still triggers the base effect.
- A correct answer grants an additional `25%` damage multiplier.
- Sets the team's AP to zero after use.

### 5.2 Genius Rabbit

- Attribute: Pinyin
- Base maximum HP: `95`
- After applying the Pinyin passive, the actual maximum HP at the start of battle is `114`
- Passive source: Pinyin; increases the team's maximum HP and damage-card effects by `20%`

#### Pinyin Combo

- Type: Attack card
- Target: One enemy
- Uses `26` base damage against the selected target.
- Uses `13` base damage against every other surviving enemy.
- Attributes, answer bonuses, character modifiers, and target statuses are calculated separately for each target.

#### Tone Shield

- Type: Defense card
- Target: One allied character
- Base damage reduction: `12%`
- A correct answer further increases the damage reduction based on difficulty.

#### Four-Tone Burst

- Type: Skill card
- AP cost: `5`
- Base damage: `92`
- Target: One enemy
- Always uses a Hard question.
- An incorrect answer still triggers the base effect.
- A correct answer grants an additional `25%` damage multiplier.
- Sets the team's AP to zero after use.

### 5.3 Lawilim

- Attribute: Vocabulary
- Base maximum HP: `100`
- After applying the Pinyin passive, the actual maximum HP at the start of battle is `120`
- Passive source: Vocabulary; after an incorrect answer, there is a `25%` chance to trigger the correct-answer bonus

#### Vocabulary Impact

- Type: Attack card
- Base damage: `43`
- Target: One enemy

#### Idiom Barrier

- Type: Defense card
- Target: One allied character
- Base damage reduction: `12%`
- A correct answer further increases the damage reduction based on difficulty.

#### Sea of Words Echo

- Type: Skill card
- AP cost: `5`
- Base damage: `28`
- Target: All surviving enemies
- Always uses a Hard question.
- An incorrect answer still triggers the base effect.
- A correct answer grants an additional `25%` damage multiplier.
- Sets the team's AP to zero after use.

## 6. Question System

### 6.1 Question Categories

The question bank contains:

- Pinyin questions
- Vocabulary questions
- Culture questions

Each question has four options. Whenever a question is drawn, the options are shuffled and the correct-answer index is updated accordingly.

### 6.2 Attack and Defense Cards

When using an exclusive attack or defense card, the player may select:

| Difficulty | Correct-Answer Damage Bonus | Additional Damage Reduction | Additional AP |
| --- | ---: | ---: | ---: |
| Easy | `+5%` | `+10%` | `+0.5` |
| Medium | `+7%` | `+15%` | `+0.7` |
| Hard | `+10%` | `+20%` | `+1.0` |

Rules:

- Questions are drawn from all attribute categories at the selected difficulty.
- The question does not have to match the current character's attribute.
- Attack and defense cards always grant a base `0.5 AP`, regardless of whether the answer is correct.
- A correct answer then grants the additional difficulty AP shown in the table.
- A successful Vocabulary passive compensation also triggers the correct-answer bonus.
- An incorrect answer does not deal damage to the player or remove existing AP.

### 6.3 Skill Cards

- Skill cards unlock when AP reaches `5`.
- Skill cards always draw a Hard question and do not display a difficulty selection.
- An incorrect answer still triggers the skill's base effect.
- A correct answer grants the skill an additional `25%` damage multiplier.
- AP is reset to zero after using a skill.

## 7. AP System

- AP is a shared team resource.
- AP starts at `0`.
- The AP limit is `5`.
- The three characters do not have individual AP values.
- The AP bar at the top displays current AP.
- When AP reaches `5`, the AP bar turns gold and skill cards are no longer grayed out or locked.

Sources of AP include:

- The base `0.5 AP` from exclusive attack and defense cards.
- Difficulty AP awarded for correct answers.
- Potion of Confucius.
- The Culture attribute passive.

All AP gains are affected by the Culture passive, but AP can never exceed `5`.

## 8. Damage Calculation

### 8.1 Allied Damage

Regular allied damage is generally resolved in the following order:

1. Read the card's base damage.
2. Add the damage-card multipliers provided by surviving Pinyin characters.
3. If the character and enemy share an attribute, add `20%`.
4. Add the answer-difficulty or correct-skill-answer multiplier.
5. Apply the attacker's outgoing-damage modifiers, such as Weakness and Strength.
6. Apply all Vulnerability effects on the target.
7. Apply the target's percentage-based damage reduction.
8. Let fixed-value shields absorb the remaining damage.
9. Finally, subtract HP.

Pinyin, matching-attribute, and answer bonuses are added together within the same attack multiplier. The attacker's outgoing-damage statuses and the target's Vulnerability are then applied multiplicatively.

### 8.2 Vulnerability Stacking

- Reapplying the same Vulnerability from the same source refreshes the effect instead of adding another stack.
- Vulnerability from different sources may coexist.
- Vulnerability from different sources stacks multiplicatively.

For example, two `20%` Vulnerability effects from different sources:

```text
1.2 × 1.2 = 1.44
```

The final damage increase is `44%`, not `40%`.

### 8.3 Direct HP Loss

The HP loss caused by ??? is direct HP loss:

- It does not calculate attribute-based damage reduction.
- It does not trigger Impenetrable Shield.
- It is not absorbed by fixed-value shields.

## 9. Defense, Shields, and Status Effects

### 9.1 Percentage-Based Damage Reduction

- Defense cards provide percentage-based damage reduction for the current turn.
- An additional `20%` damage reduction is applied when attacked by an enemy with the same attribute.
- Total percentage-based damage reduction is capped at `85%`.

### 9.2 Fixed-Value Shields

- A fixed-value shield has a specific shield value.
- Incoming damage consumes the fixed shield before reducing HP.
- Fixed shields can stack.
- The shield visual effect disappears when the shield value reaches zero.

### 9.3 Damage Immunity

- Completely blocks one instance of positive damage.
- Triggers before percentage-based damage reduction and fixed shields.
- Consumes one stack when triggered.
- Gaining Impenetrable Shield multiple times adds more stacks.
- Damage Immunity does not expire naturally over time.

### 9.4 Stun

- Stun causes an enemy to skip its next action.
- Menghan Toxin cannot stack.
- Using Menghan Toxin on an already stunned enemy consumes the card without refreshing or adding Stun.

### 9.5 Weakness

- Reduces damage dealt by the affected character.
- Gall of Goujian currently applies `50%` Weakness.

### 9.6 Strength

- Increases damage dealt by the affected character.
- Gall of Goujian and Smashed Cauldron can each provide `30%` Strength.

## 10. General Cards

General cards belong to a shared team deck:

- Any currently selected character may use them.
- A general card disappears from the deck after use.
- Using a general card consumes the selected character's action.
- The starting hand contains three cards drawn randomly with replacement from the general card pool, so duplicates are possible.
- The shop displays four cards drawn randomly with replacement from the general card pool.
- Defeating an enemy grants one random card from the general card pool.

### 10.1 Potion of Confucius

- Effect: Gain `2.5 AP`.
- Target: Team AP.
- Purchase price: `1.8 New TOEFL`
- Selling price: `1.1 New TOEFL`

The Culture passive further increases this AP gain.

### 10.2 Dagger of Jing Ke

- Target: One enemy.
- First reads the target's current HP before the card is used.
- Calculates `30%` of the current HP and rounds it to produce the dynamic base damage.
- Then applies modifiers from the acting character's Pinyin passive, matching attribute, Strength, and Weakness, as well as the target's Vulnerability and other effects.
- Purchase price: `1.8`
- Selling price: `1.1`

As a result, the final HP loss will usually not equal exactly `30%` of the target's current HP. The battle log displays the current HP, calculated base damage, and final damage.

### 10.3 Impenetrable Shield

- Target: One allied character.
- Completely blocks the next instance of incoming damage.
- Can be gained repeatedly to accumulate multiple stacks.
- One stack is consumed whenever positive damage is received.
- Does not expire over time.
- Purchase price: `1.8`
- Selling price: `1.1`

### 10.4 Menghan Toxin

- Target: One enemy.
- Stuns the enemy, causing it to skip its next action.
- Cannot stack.
- If used again on an already stunned target, the card is consumed but Stun is not refreshed.
- Purchase price: `1.5`
- Selling price: `0.9`

### 10.5 Elixir of Huatuo

- Target: One allied character.
- Immediately restores `40%` of that character's maximum HP.
- Healing cannot exceed maximum HP.
- Purchase price: `1.4`
- Selling price: `0.9`

### 10.6 Gall of Goujian

- Target: One allied character.
- First phase: Damage dealt is reduced by `50%` for the current turn.
- Second phase: Damage dealt is increased by `30%` for the following two player turns.
- Reusing it during the Weakness phase has no effect, but the card is still consumed.
- Reusing it during the Strength phase resets the Strength duration to two turns.
- Purchase price: `1.5`
- Selling price: `0.9`

### 10.7 Insight of Paoding

- Target: One enemy.
- Applies `30%` Vulnerability.
- Lasts for two turns.
- Can stack multiplicatively with the Vulnerability from Culture Card or other sources.
- Purchase price: `1.6`
- Selling price: `1.0`

### 10.8 Smashed Cauldron

- Target: One allied character.
- Increases damage received by `100%`.
- Increases damage dealt by `30%`.
- Both effects last for two turns.
- Vulnerability and Strength are displayed as separate status icons.
- Purchase price: `1.7`
- Selling price: `1.1`

### 10.9 ???

- A hidden Easter egg card.
- Does not appear in the starting hand, enemy drops, or the shop.
- Target: ???.
- Directly removes `???` HP from the target.
- It can also be obtained by entering the following sequence during battle:

```text
???
```

After the sequence is entered successfully, the team gains one ???.

## 11. Enemies

Enemies are formed from combinations of an attribute and an archetype, producing nine variants:

- Pinyin Bun, Vocabulary Bun, Culture Bun
- Pinyin Slime, Vocabulary Slime, Culture Slime
- Pinyin Mask, Vocabulary Mask, Culture Mask

### 11.1 Bun

- Maximum HP: `70`
- Behavior: Deals `11` base damage to every surviving allied character.
- Reward: `1.0 New TOEFL`

Matching-attribute reduction, statuses, shields, and Damage Immunity are calculated separately for each character.

### 11.2 Slime

- Maximum HP: `80`
- Has no attack ability.
- Behavior: Grants every surviving enemy `8` points of fixed shield.
- The shield can stack.
- Reward: `1.0 New TOEFL`

### 11.3 Mask

- Maximum HP: `90`
- Behavior: Randomly selects one surviving allied character and deals `13` base damage.
- Reward: `1.5 New TOEFL`

## 12. New TOEFL and the Shop

### 12.1 New TOEFL

- New TOEFL is awarded when an enemy is defeated.
- The current in-battle New TOEFL limit is `6`.
- Any amount beyond the limit is not accumulated.

### 12.2 Shop

- Click the Shop button in the top-right during battle to open the shop.
- The shop displays four random general cards at a time.
- Shop cards are drawn with replacement, so duplicate cards may appear together.
- Purchased cards are added to the team's shared general-card deck.
- Cards in the player's hand cannot be used while the shop is open.
- Refreshing the shop costs `0.5 New TOEFL`.
- When there is not enough New TOEFL, the Refresh button is grayed out and disabled.

## 13. Rewards and Drops

When an enemy dies for the first time:

1. Award that enemy's New TOEFL reward.
2. Grant one random general card from the complete general card pool.

The same enemy cannot grant its rewards more than once.

The hidden ??? card is not part of the random general card pool and therefore cannot appear as a drop.

## 14. Map and Current Stage

The first-floor map is shown when the game begins.

The first stage is currently connected to the map:

- Stage background: Chinese Club activity room.
- Current number of waves: `1`
- The current wave contains three enemy positions.
- Each position randomly selects one enemy from its corresponding candidate list.

The three current positions select:

1. One Bun of any attribute.
2. One Slime of any attribute.
3. One Mask of any attribute.

The status panel in the top-right displays:

- The current phase.
- The current player-turn number.
- The current wave, such as `1/1` or `1/3` in a future stage.

## 15. Victory and Defeat

### Victory

- Defeat every enemy in the final wave.

### Defeat

- All three allied characters are defeated.

Defeat currently has no additional penalty, and the stage can be challenged again.

## 16. Features Not Yet Implemented

The following features have been discussed and designed, but are not yet part of the implemented gameplay:

- Allied and enemy level systems.
- Progression curves up to level 10.
- Old TOEFL as an upgrade resource.
- Stage ratings from A to F.
- Rating-based conversion multipliers from New TOEFL to Old TOEFL.
- A complete multi-floor map flow.
- Additional characters and enemies with multiple-skill combinations.

When these systems are implemented, this document should be updated to reflect the actual code and data.
