# Lineage 2 Interlude (Chronicle 6) Server Formulas

Everything on this page is how our server actually calculates things. No guesswork, no "it feels like" — these are the real numbers behind every hit, crit, heal and level-up. You don't need any maths background: each section gives the formula, then a plain explanation of what it means for you.

> **Original Retail Mechanics**  
> These are the **Lineage 2 Interlude (Chronicle 6) official formulas** — identical to the original retail game. Nothing here is invented for our server; this is how Interlude has always worked under the hood. If you learned these numbers on official years ago, they still hold true here.

---

## 1. How Every Stat Is Built

Every stat in the game is built the same way, in this order:

1. **Base value** — from your class and level
2. **Flat bonuses** — added on (gear, some buffs)
3. **Multipliers** — your attributes, level, buffs, shots
4. **A hard cap** — some stats simply cannot go higher, no matter what

That last step matters more than people expect. Several stats have a ceiling, and once you hit it, every point you spend past it is completely wasted. Those caps are listed throughout this page.

### Level Bonus

Two things scale almost everything: your **attributes** and your **level**. Level shows up as a multiplier we'll call the *level bonus*:

$$\text{Level bonus} = \frac{89 + \text{your level}}{100}$$

| Your level | Level bonus |
|:---:|:---:|
| 1 | $\times 0.90$ |
| 20 | $\times 1.09$ |
| 40 | $\times 1.29$ |
| 60 | $\times 1.49$ |
| 76 | $\times 1.65$ |
| 80 | $\times 1.69$ |
| 85 | $\times 1.74$ |

This is why a level-85 character with the same gear as a level-40 character hits far harder than the raw gear difference suggests. Monsters and NPCs do **not** get this bonus — only players.

---

## 2. Your Six Attributes

| Attribute | What it does |
|:---|:---|
| **STR** | Physical attack power, physical skill crit chance, resistance to Disarm |
| **DEX** | Accuracy, evasion, attack speed, run speed, critical rate, dagger blow chance, shield block rate |
| **CON** | Max HP, max CP, HP and CP regeneration, **resistance to Stun, Bleed, Poison and Paralyze** |
| **INT** | Magic attack power |
| **WIT** | Casting speed, magic critical rate |
| **MEN** | Max MP, magic defence, MP regeneration, **resistance to Sleep, Root, Fear, Mute, Petrification and stat debuffs** |

Each attribute value converts to a **multiplier**. Here's the shape of the curve:

| Value | STR | INT | CON | MEN | DEX | WIT |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| 1 | $\times 0.30$ | $\times 0.55$ | $\times 0.46$ | $\times 1.01$ | $\times 0.85$ | $\times 0.40$ |
| 20 | $\times 0.59$ | $\times 0.80$ | $\times 0.80$ | $\times 1.22$ | $\times 1.01$ | $\times 1.00$ |
| 40 | $\times 1.20$ | $\times 1.19$ | $\times 1.44$ | $\times 1.49$ | $\times 1.20$ | $\times 2.65$ |
| 60 | $\times 2.43$ | $\times 1.76$ | $\times 2.60$ | $\times 1.82$ | $\times 1.44$ | $\times 7.04$ |
| 80 | $\times 4.94$ | $\times 2.62$ | $\times 4.70$ | $\times 2.22$ | $\times 1.72$ | $\times 18.68$ |
| 99 | $\times 9.67$ | $\times 3.82$ | $\times 8.24$ | $\times 2.68$ | $\times 2.04$ | $\times 47.20$ |

* **What this means:** Attributes do not scale evenly. The curve is gentle in the 20–40 range and then climbs steeply. Going from 40 to 60 STR **doubles** your attack multiplier ($\times 1.20 \to \times 2.43$), and going from 60 to 80 doubles it again ($\times 2.43 \to \times 4.94$). This is why high-attribute builds feel disproportionately strong — because they are.
* **WIT is the extreme case:** It is worth $\times 1.00$ at 20, $\times 2.65$ at 40 and $\times 47$ at 99. WIT is what drives magic crit rate, which is why casters chase it so hard. *(Retail caps it at 20%, but our server does not — see the magic crit section).*
* **DEX is the flattest:** It only reaches $\times 2.04$ at 99. DEX is valuable because of *how many* things it touches, not because any one of them scales dramatically.

> **Note:** The complete table for every value from 1 to 99 is available as a separate download (`attribute-bonus-table.csv`).

---

## 3. Attack Power

### Physical Attack (P.Atk)

$$\text{P.Atk} = \text{Base P.Atk} \times \text{STR bonus} \times \text{Level bonus}$$

Straightforward — gear gives you the base, STR and level multiply it.

### Magic Attack (M.Atk)

$$\text{M.Atk} = \text{Base M.Atk} \times (\text{Level bonus})^2 \times (\text{INT bonus})^2$$

Both terms are **squared**. This is the single biggest difference between melee and caster scaling.

At level 80 with 40 INT:
* A fighter gets $1.69 \times 1.20 = \mathbf{\times 2.03}$
* A caster gets $1.69^2 \times 1.19^2 = 2.86 \times 1.42 = \mathbf{\times 4.06}$

Casters gain roughly twice as much from levels and INT as fighters gain from levels and STR. But read the magic damage section before you get excited — that advantage is partly given back later.

---

## 4. Defence

$$\text{P.Def} = \text{Base P.Def} \times \text{Level bonus}$$

$$\text{M.Def} = \text{Base M.Def} \times \text{MEN bonus} \times \text{Level bonus}$$

Physical defence does **not** scale with any attribute — only gear and level. There is no "tank stat" for P.Def. Magic defence does scale, with MEN.

---

## 5. Health, Mana & CP

$$\text{Max HP} = \text{Base HP} \times \text{CON bonus}$$

$$\text{Max MP} = \text{Base MP} \times \text{MEN bonus}$$

$$\text{Max CP} = \text{Base CP} \times \text{CON bonus}$$

Base values come from your class and level.

### Regeneration

* **HP regen base:**
  * Below level 11: $1.5 + \frac{\text{level}}{20}$
  * Level 11 and up: $1.4 + \frac{\text{level}}{10}$  
  *(Then multiplied by your **Level bonus** and your **CON bonus**)*

* **MP regen base:**
  $$0.87 + (\text{level} \times 0.03)$$  
  *(Then multiplied by your **Level bonus** and your **MEN bonus**)*

* **CP regen:**
  $$\text{CP regen} = \left(1.5 + \frac{\text{level}}{10}\right) \times \text{Level bonus} \times \text{CON bonus}$$

### Posture Matters a Lot

| What you're doing | Regen speed |
|:---|:---:|
| **Sitting** | $\mathbf{\times 1.5}$ |
| Standing still | $\times 1.0$ |
| Running | $\times 0.7$ |

> **Low-level bonus:** If you are **level 40 or below** and have **not yet taken your 3rd class transfer**, sitting gives you $\mathbf{\times 6.0\text{ HP regen}}$ instead of $\times 1.5$. Sitting to recover is dramatically faster for new characters — and that bonus disappears the moment you pass level 40.

Summons and pets regenerate at **double** the normal rate.

---

## 6. Hitting Your Target

$$\text{Accuracy} = \sqrt{\text{DEX}} \times 6 + \text{your level}$$

$$\text{Evasion} = \sqrt{\text{DEX}} \times 6 + \text{your level}$$

Both use the same formula, so accuracy vs evasion is purely a contest of DEX and level between you and your target.

$$\text{Hit chance} = 88 + 2 \times (\text{your Accuracy} - \text{their Evasion})$$

*(Calculated as a percentage, then adjusted by the following modifiers):*

| Situation | Effect on hit chance |
|:---|:---|
| Attacking from **behind** | Bonus |
| Attacking from the **side** | Smaller bonus |
| Attacking from the **front** | Small penalty |
| More than 50 units **above** them | Bonus |
| More than 50 units **below** them | Penalty |
| It is **night time** | Penalty |

**Finally, hit chance is clamped between 28% and 98%.**

That clamp is important and widely misunderstood. **You can never be un-hittable**, no matter how much evasion you stack — even a hopelessly outmatched attacker lands 28% of their swings. And you can never be guaranteed to hit: 2% of your attacks will miss regardless of how much accuracy you have.

> **Practical takeaway:** Evasion stacking has a hard floor of usefulness, and accuracy past the point where you reach 98% is wasted.

---

## 7. Critical Hits

### Physical Critical Rate

$$\text{Crit rate} = \text{Base Critical} \times \text{DEX bonus} \times \text{any crit-rate buffs}$$

**Capped at 500**, which displays as **50%**. Half your hits critting is the absolute maximum — Focus, Death Whisper, Dye and gear all stop mattering once you reach it.

Then, when the game rolls for the crit, it also applies:

| Attacking from | Effect |
|:---|:---|
| Behind | Bonus to crit chance |
| Side | Smaller bonus |
| Front | Small penalty |

> **Warning:** If you have no weapon equipped, your critical chance is exactly zero.

### Magic Critical Rate

$$\text{Magic crit rate} = \text{Base} \times 0.1 \times \text{WIT bonus}$$

> **Our server setting:** On retail Interlude magic crit rate is **capped at 20%** — but we remove that cap entirely. Here there is **no ceiling** on magic crit rate, so every point of WIT keeps pushing it higher (on top of the casting speed it already gives). That makes stacking WIT far more rewarding for casters on our server than on official.

### Dagger Blows

Blow skills (*Backstab*, *Mortal Blow*, etc.) use their own landing check:

$$\text{Blow chance} = \text{Weapon critical} \times \text{DEX bonus} \times \text{Height modifier} \times \text{Skill blow rate} \times \text{Blow rate bonuses}$$

The height modifier is small — being up to 25 units above your target helps slightly, below hurts slightly. Then position takes over completely.

**For skills that require you to be behind the target:**

| Your position | Chance to land |
|:---|:---:|
| Behind | **100%** |
| Side | 50% |
| Front | 3% |

For behind-only skills, none of the calculation above matters — position is everything. For blow skills that work from any angle, position gives a normal bonus/penalty and the result is **capped at 80%**.

---

## 8. Physical Damage

$$\text{Damage} = \frac{70 \times (\text{P.Atk} + \text{Skill Power}) \times \text{Soulshot} \times \text{Critical} \times \text{Position} \times \text{Variance}}{\text{their P.Def}}$$

Where each factor is:
* **P.Atk + Skill Power** — your attack power, plus the skill's power (auto-attacks add nothing here).
* **Soulshot** — $\times 2$ when soulshots are loaded, $\times 1$ without.
* **Critical** — $\times 2$ on a rolled auto-attack crit; skills use your crit-damage multiplier plus static crit damage; $\times 1$ on a normal hit.
* **Position** — a bonus from behind, less from the side, a small penalty from the front.
* **Variance** — a small random high/low roll on every hit.
* **$\div$ their P.Def** — straight division; 70 is the neutral point (see below).

Unlike magic, physical damage isn't one clean line — it's that base with conditional multipliers layered on. The exact order the game applies them:

1. Start with your **P.Atk**, and their **P.Def** (plus shield defence if they blocked).
2. **Add the skill's power** (skills only).
3. Apply **random damage variance** — every hit rolls slightly high or low.
4. If it's a **critical**, multiply by your crit damage, then add your static crit damage.
5. If it's a **soulshot critical skill from the front**, $\times 2.04$ — from behind, $\times 1.5$.
6. If it's a **rolled critical auto-attack**, $\times 2$.
7. Apply the **positional bonus** — behind, side, or front.
8. If **soulshots** are loaded: apply the soulshot bonus, then $\times 2$ for non-critical hits.
9. **Divide by their defence:** $\text{damage} \times 70 \div \text{their P.Def}$.
10. Apply PvP or PvE damage/defence bonuses.
11. Subtract any flat damage block they have.

### The Bit That Actually Matters

$$\text{Mitigation} = \frac{\text{damage} \times 70}{\text{P.Def}}$$

Physical defence works as a straight division. 70 is the neutral point — a target with 70 P.Def takes your damage unchanged. Double their P.Def and they take half the damage. Double it again, a quarter.

This has an important consequence: **P.Def has no diminishing returns, but it also never makes you immune.** Going from 1000 to 2000 P.Def halves incoming physical damage, exactly. Going from 2000 to 4000 halves it again. There is no soft cap and no wall.

### Shield Blocks

If a shield block succeeds, their shield defence is added to their P.Def for that hit. On top of that, there's a flat **5% chance the hit is reduced to 1 damage** — that's the "excellent shield defense" message.

### One Special Case

**Charge skills** scale with your charges:

$$\times 0.8 + 0.2 \times \text{charges}$$

---

## 9. Magic Damage

$$\text{Damage} = \frac{91 \times \text{Skill Power} \times \sqrt{\text{M.Atk}}}{\text{their M.Def}}$$

### The Square Root Is the Catch

Your M.Atk goes in **under a square root**. Doubling your M.Atk gives you only about **$1.41\times$ damage**, not $2\times$. Quadrupling it gives $2\times$.

Remember that M.Atk itself scales with INT *squared* and level *squared* — the square root here partly cancels that out. The two effects together are why caster damage feels smooth rather than explosive.

M.Def, by contrast, divides directly with no square root — so **M.Def is a stronger defensive stat against magic than M.Atk is an offensive one.**

### Spiritshots

| Shot | M.Atk multiplier | Resulting damage |
|:---|:---:|:---:|
| Spiritshot | $\times 2$ | about $\times 1.41$ |
| Blessed Spiritshot | $\times 4$ | **about $\times 2.0$** |

This is exactly why Blessed Spiritshots are worth their cost and normal ones feel underwhelming.

### Magic Criticals

A magic crit multiplies damage by **4** (before the target's magic crit resistance). Compare that to a physical crit at $\times 2$ — magic crits hit much harder. On retail your chance of one is capped at 20%, but our server lifts that cap, so high-WIT casters crit far more often here.

### Magic Resist and the Level Gap

This is the "resisted your magic" message, and it is driven almost entirely by **level difference**.

$$\text{Fail chance} \approx 4 \times (\text{their level} - \text{your skill's level} - \text{offset}) \times 2$$

*(Adjusted by their magic resistance versus your magic power, and **capped at 95%**).* If it fails, there's a second roll:
* **Full resist** $\to$ 0 damage ("resisted your magic")
* Otherwise $\to$ **half damage** ("damage was decreased")

$$\text{Full resist chance} = 5 \times (\text{level gap} - 10) \quad (\text{capped at 95\%})$$

> **Practical takeaway:** Casting on targets significantly above your level is close to useless, and the penalty is steep rather than gradual. Level difference matters far more for magic than for physical attacks.

> **Warning:** If you are wearing gear above your grade (an expertise penalty), your magic is forced to **95% fail chance** — effectively every spell resisted. Never fight in over-grade gear as a caster.

---

## 10. Landing and Resisting Debuffs

A debuff's chance to land starts at the skill's own rate, then gets modified by:
* **The saving attribute** — every debuff is guarded by one of your attributes.
* **Magic power vs magic defence** (magic debuffs only) — roughly $11 \times \frac{\sqrt{\text{M.Atk}}}{\text{their M.Def}}$.
* **Level difference** — $\pm 3\%$ per level, capped at $\pm 100\%$.
* **Their debuff resistance** — a value of 120 is total immunity.
* **Trait resistance** — resistance to that specific *type* (stun, bleed, sleep, poison…).
* **Elemental attribute** — $(\text{your attack element} - \text{their defence}) \div 10$ added to the chance.

**Final chance is clamped between 5% and 95%.** No debuff is ever guaranteed, and none is ever completely impossible — the floor is 5% even against a perfect defence.

### The Saving Attribute — Where CON and MEN Matter

Every debuff skill names one attribute that defends against it. Yours is checked against it, and the skill's chance to land is multiplied by:

$$\text{Protection multiplier} = 2 - \sqrt{\text{your attribute bonus}} \quad (\text{never above } 1.00)$$

| Attribute | Guards against |
|:---|:---|
| **CON** | **Stun**, Bleed, Poison, Paralyze — the "body" debuffs |
| **MEN** | **Sleep**, Root, Fear, Mute, Silence, Petrification, Paralyze, and most stat-lowering debuffs — the "mind" debuffs |
| **STR** | Disarm |
| **WIT** | One damage-over-time skill (not worth building for) |

**So yes — the old wisdom about CON and stun resistance is correct.** CON resists stun, bleed, poison, and paralyze. MEN covers the mental side: sleep, root, fear, and silence.

### How Much Protection You Actually Get

| Your attribute | CON — chance reduced by | MEN — chance reduced by |
|:---:|:---:|:---:|
| 20 | 0% | 10% |
| 30 | 3% | 16% |
| 40 | 20% | 22% |
| 50 | 39% | 28% |
| 60 | **61%** | 35% |
| 70 | **87%** | 42% |
| 80 | down to the 5% floor | 49% |
| 90 | down to the 5% floor | 57% |
| 99 | down to the 5% floor | **64%** |

Three things worth knowing:
1. **CON does nothing until about 29.** Below that the multiplier is capped at 1.00 — you get no protection, but you also take no extra penalty for having low CON. It simply doesn't engage yet.
2. **CON then accelerates viciously.** From 40 to 60 the reduction goes from 20% to 61%. From 60 to 70 it goes to 87%. By around 75 it pushes the chance down to the 5% floor, which is as close to stun-immune as this game allows. The last 20 points of CON are worth far more than the first 40.
3. **MEN is the opposite shape — early and gentle.** It starts protecting from almost the first point, but it climbs slowly and tops out around 64% even at 99. You will never be sleep-proof the way you can be stun-proof.

> **Practical takeaway:** If you are being stun-locked in PvP, CON is the answer, and it is worth pushing hard rather than a little. If you are being slept or silenced, MEN helps steadily but there is no threshold where it suddenly saves you.

> **Caveats:** The saving attribute is only one of six factors — a caster with very high M.Atk against your low M.Def can claw a lot of that chance back. And nothing takes a debuff below the 5% floor, so "immune" never literally means immune.

---

## 11. Speed & Timing

### How Fast You Attack

$$\text{Time between attacks (seconds)} = \frac{500}{\text{your P.Atk.Spd}}$$

| P.Atk.Spd | Time between swings |
|:---:|:---:|
| 300 | $\approx 1.63\text{ s}$ |
| 500 | $\approx 0.98\text{ s}$ |
| 800 | $\approx 0.61\text{ s}$ |
| 1200 | $\approx 0.41\text{ s}$ |
| 1500 (cap) | $\approx 0.33\text{ s}$ |

**P.Atk.Spd is capped at 1500.** Attack speed above that is wasted.

### How Fast You Cast

$$\text{Cast time} = \text{skill's listed time} \times \frac{333}{\text{your M.Atk.Spd}}$$

**333 is the neutral point.** At exactly 333 M.Atk.Spd, every skill casts in exactly its listed time. At 666 you cast twice as fast. At 999, three times as fast. **M.Atk.Spd is capped at 1999** — just under $6\times$ the base casting speed. Physical skills use your P.Atk.Spd in the same formula.

### Skill Cooldowns

Cooldowns start from the skill's listed reuse time and are then reduced by any reuse-rate buffs.

> **Note:** On this server, cooldowns **may** also scale with your casting/attack speed ($\times \frac{333}{\text{your speed}}$) — this is a server setting. If it's on, casting speed reduces your cooldowns as well as your cast times, which is a very large hidden benefit.

**Skill Mastery** (*Wizard's / Warrior's Mastery*) can set a skill's cooldown to **zero** outright. Its chance is driven by INT for casters, STR for fighters.

---

## 12. Getting Interrupted

### Your Cast Being Broken

Being hit while casting can interrupt you:

| You were hit by | Chance to interrupt |
|:---|:---:|
| A critical hit | **75%** |
| A normal hit | 10% |

**You cannot be interrupted at all if:** you're invulnerable, you're a raid boss, or the skill you're casting is a *physical* skill. Physical skills never get interrupted — only magic does.

### Breaking a Stun

When you hit a stunned target, the stun can break early:

| Your hit | Chance to break the stun |
|:---|:---:|
| Critical | **75%** |
| Normal | 10% |

> **Practical takeaway:** Hitting a stunned target is usually a mistake if your team is relying on that stun. A single critical has a 3-in-4 chance of freeing them.

---

## 13. Elemental Attributes

$$\text{Damage multiplier} = \frac{100 + \text{your attack attribute}}{100 + \text{their defence attribute}}$$

* 150 Fire attack against 0 defence: $250 \div 100 = \mathbf{\times 2.5\text{ damage}}$.
* 150 Fire attack against 150 Fire defence: $250 \div 250 = \mathbf{\times 1.0}$ (completely neutralised).

For auto-attacks, the game automatically uses whichever of your six elements has the **biggest advantage** against that specific target. Skills use their own element if they have one.

> **Practical takeaway:** Attribute defence is exactly as valuable as attribute attack, point for point. And spreading your attack across several elements is worse than concentrating it, since only your best element is ever used.

---

## 14. Lethal Strikes

Lethal only works when the target is **no more than 5 levels above** the skill's level.

| Strike Type | Against players | Against monsters | Against bosses |
|:---|:---|:---|:---|
| **Half Kill** | Drains all CP | HP cut to half | No lethal — $\times 2$ damage instead |
| **Full Kill** | HP and CP down to 1 | HP down to 1 | No lethal — $\times 3$ damage instead |

Bosses and raid bosses are immune to lethal, but you get extra damage in exchange.

---

## 15. Experience & SP

### How Exp Is Shared

**Exp is awarded by damage dealt, not by the killing blow.**

$$\text{Your exp} = \text{monster's exp} \times \left(\frac{\text{your damage}}{\text{monster's max HP}}\right)$$

Kill-stealing doesn't exist here in the usual sense. If you did 30% of the damage, you get 30% of the exp — whoever lands the last hit.

### The Level Gap Penalty

If you are **more than 5 levels above** the monster:

$$\text{Penalty} = 0.83^{(\text{level gap} - 5)}$$

| Levels above the mob | Exp you keep |
|:---:|:---:|
| 5 or fewer | **100%** |
| 6 | 83% |
| 8 | 57% |
| 10 | 39% |
| 15 | 15% |
| 20 | 6% |

The drop-off is brutal and compounds. Farming ten levels below yourself gives you roughly a third of the exp, and at twenty levels below you're getting almost nothing.

### Overhit

If you kill a monster with far more damage than it had HP left, you get bonus exp:

$$\text{Bonus} = \left(\frac{\text{overkill damage}}{\text{monster's max HP}}\right) \times \text{your exp} \quad (\text{capped at } +25\%)$$

You have to be the one who lands the killing blow.

### Pets

A summoned pet standing next to you takes a share of your exp. If it's **out of range**, it takes only **one fifth** of that share and you keep the rest.

### Karma

$$\text{Karma lost} = \frac{\text{exp you gained}}{(\text{a level-based divisor}) \times 15}$$

You clear PK karma by gaining experience. Higher-level characters need more exp per point of karma removed.

---

## 16. Quick Reference — What to Stack, and When to Stop

| If you want | Stack this | Why |
|:---|:---|:---|
| More melee damage | **STR**, then P.Atk | STR multiplies your whole attack |
| More caster damage | **INT** | It's squared into M.Atk |
| Faster casting | **WIT** | Also raises magic crit — uncapped on our server |
| To survive physical | **P.Def** | Straight division — no diminishing returns |
| To survive magic | **M.Def and MEN** | Divides directly, unlike M.Atk which is square-rooted |
| To land debuffs | **M.Atk and level** | Level difference is worth $\pm 3\%$ per level |
| To resist stun / bleed / poison | **CON** | Nothing below 29; near-total above 75 |
| To resist sleep / root / fear / silence | **MEN** | Steady but gentle — tops out around 64% |
| To resist debuffs generally | **Trait resists** (stun/sleep/etc.) | Stacks on top of the attribute check |
| More HP | **CON** | Also drives HP and CP regeneration |