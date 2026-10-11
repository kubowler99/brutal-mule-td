# Game Concept Document — Project: Arcane Survivor

A hero‑centric, roguelike, Survivors‑like 2D mobile action game built with Solar2D.

## High‑Level Overview

### Game Summary

**Arcane Survivor** places a single **stationary hero** on a defensive wall at the bottom center of the screen. Enemies spawn and advance from the top and sides toward the wall. The hero cannot move; survival and success depend on **ability selection, ability upgrades, positioning of summoned support**, and timing. Runs are short (5–10 minutes) and highly replayable via randomized upgrade drafts and meta progression.

### Core Pillars

- **Stationary Hero Defense** — hero defends from a fixed wall position; gameplay focuses on ability choice and synergies.  
- **Roguelike Drafting** — at each level up the player chooses **one of three random options** (new ability or an upgrade).  
- **Limited Active Slots** — hero can have up to **5 active abilities**; each ability supports up to **5 upgrade tiers**.  
- **Short, Intense Runs** — mobile‑friendly sessions with escalating waves and bosses.  
- **Low‑cost Art, High Depth** — silhouette art with clear VFX for readability.

## Core Gameplay Loop

### Moment‑to‑Moment

- Hero sits on the **wall (bottom center)** and auto‑uses active abilities according to cooldowns and triggers.  
- Auto‑attacks fire at intervals.
- Hero can have up to 5 active abilities/attacks
- Collect XP by defeating enemies.
- Level up and choose one of three random abilities/ability upgrades.
- Survive increasingly difficult waves.

### Level Up / Draft

- Every XP threshold → **Level Up** → game pauses briefly and presents **3 random cards**.  
- Each card is either a **new ability** (if fewer than 5 active abilities) or an **upgrade tier** for an existing ability.  
- Player selects **one** card. Repeat until run ends.

### Run Loop

- Start run → choose hero
- Fight waves → collect XP → upgrade
- Mid‑run elite enemies + mini‑bosses
- Final boss at round level 20
- Earn currency → unlock meta upgrades
- Repeat with new builds

### Meta Loop

- Unlock new heroes
- Unlock new abilities
- Upgrade permanent stats
- Clear stages to unlock the next battlefield (see **Stages**)
- Buy card packs with gold, level cards up, and equip a 3-card loadout (see **Cards**)
- Unlock difficulty tiers
- Cosmetic skins

## Heroes

### Hero 1: The Arcane Wanderer

- Role: Balanced starter hero
- Base Attack: Arcane Bolt (auto‑fires at nearest enemy)
- Passive: +10% XP gain
- Ultimate (optional future feature): Arcane Nova (burst AOE)

### Hero 2: The Ember Knight

- Role: Close‑range bruiser
- Base Attack: Flame Slash (short‑range arc)
- Passive: +20% damage when below 50% HP

### Hero 3: The Frost Witch

- Role: Control / crowd management
- Base Attack: Frost Shard (piercing projectile)
- Passive: Enemies hit are slowed by 20%

### There will be at least 12 unique heroes at launch

- Hero 1 will be available to all players
- Heroes 2 - 8 can be earned through events and side quest rewards (earn enough tickets to purchase the hero)
- Heroes 9+ can be earned through marketplace purchases

## Abilities & Upgrades

### Ability Categories

- Projectile (bolts, arrows, shards)
- Area (explosions, novas, shockwaves)
- Orbitals / patrollers (blades that sweep along the wall, rotating fireballs)
- Summons (floating turrets, drones, spirits)
- Passives (crit chance, movement speed, cooldown reduction)

### Example Upgrades

#### Arcane Bolt

- Lv2: +20% damage
- Lv3: +1 projectile
- Lv4: Bolts pierce 1 enemy
- Lv5: +30% attack speed

#### Frost Shard

- Lv2: +15% slow
- Lv3: +1 shard
- Lv4: Shards ricochet once
- Lv5: Freeze chance added

#### Patrol Blades

Patrol Blades replaced the original Orbiting Blades concept. Blades sweep back and forth along the whole wall and cut enemies they touch, which suits a stationary hero better than blades circling the hero.

- Lv2: +1 blade (up to 6)
- Lv3: +25% patrol speed
- Lv4: +3 damage per hit
- Lv5: Blades grow larger

### New Abilities (Expansion)

Six new abilities fill the categories the current roster lacks: summons, crit, and wall sustain. Each follows the same rules as existing abilities: up to 5 tiers, and synergy tags that feed the shared-tag damage bonus and draft weighting.

| **Ability** | **Category** | **Tags** | **Base Behavior** |
| --- | --- | --- | --- |
| **Chain Lightning** | Projectile | *projectile; arcane* | A bolt hits the nearest enemy, then jumps to 2 more nearby enemies for 70% damage each jump |
| **Meteor** | Area | *area; fire* | Marks the densest enemy group, then lands 1.2s later for heavy damage in a radius and leaves a short burn |
| **Poison Cloud** | Area | *area; poison* | Drops a lingering cloud in front of the wall that deals damage over time; poison stacks |
| **Spirit Turret** | Summon | *summon; arcane* | Places a turret on the wall that fires at its own target; lasts the whole run |
| **Keen Eye** | Passive | *crit* | Adds crit chance to every ability; crits deal 2x damage |
| **Mending Wards** | Passive | *sustain* | The wall regenerates health every second |

#### Chain Lightning

- Lv2: +1 jump
- Lv3: +20% damage
- Lv4: Jumps no longer lose damage
- Lv5: Each jump has a 20% chance to stun for 0.5s

#### Meteor

- Lv2: +25% radius
- Lv3: -1s cooldown
- Lv4: Burn lasts twice as long
- Lv5: Drops a second, smaller meteor on the next densest group

#### Poison Cloud

- Lv2: Cloud lasts 50% longer
- Lv3: +1 poison stack per tick
- Lv4: Poisoned enemies take 10% more damage from all sources
- Lv5: Enemies that die while poisoned burst into a small cloud

#### Spirit Turret

- Lv2: +1 turret
- Lv3: +30% fire rate
- Lv4: Turret shots pierce 1 enemy
- Lv5: Turret shots slow and burn

#### Keen Eye

- Each tier: +4% crit chance (20% at Lv5); crits deal 2x damage
- Lv5: crits deal 2.5x damage

#### Mending Wards

- Each tier: +0.5 wall health per second (2.5 per second at Lv5)
- Lv5: The wall also gets a shield equal to 10% of its maximum health every 30s

### Hero Ability Synergy Chart

A compact, copy‑pasteable Markdown chart showing **ability categories**, **synergy tags**, **recommended pairings**, and **sample builds** for the three starter heroes: **Arcane Wanderer**, **Ember Knight**, and **Frost Witch**. Use this to design upgrade cards, weighted draws, and synergy bonuses.

#### Synergy Matrix

| **Ability Category** | **Primary Effect** | **Synergy Tags** | **Good With** | **Countered By** |
| --- | --- | --- | --- | --- |
| **Projectile** | Single or multi bolts | *pierce; crit; speed* | Area; Orbitals | High HP tanks |
| **Area** | AOE damage or burst | *knockback; burn; slow* | Projectile; Summons | Fast runners |
| **Orbitals** | Rotating damage around hero | *stun; reflect; size* | Projectile; Passive buffs | Ranged snipers |
| **Summons** | Autonomous units that attack | *tank; DPS; distract* | Area; Passive buffs | AOE damage |
| **Passive** | Stat modifiers and procs | *crit; regen; pickup* | Any offensive ability | Silence mechanics |
| **Control** | Slow, stun, root effects | *slow; freeze; pull* | Projectile; Area | Crowd immune elites |

#### Synergy Tags and Effects

| **Tag** | **Short Effect** | **Design Use** |
| --- | --- | --- |
| **pierce** | Projectiles hit multiple enemies | Boosts clear speed vs swarms |
| **burn** | Damage over time after hit | Pairs with slow to extend uptime |
| **slow** | Reduces enemy speed | Enables kiting and AOE uptime |
| **tank** | Summons absorb damage | Protects hero and enables DPS builds |
| **crit** | Chance for high damage | Scales with attack speed passives |
| **poison** | Stacking damage over time | Rewards long fights against tanky enemies and bosses |
| **summon** | Independent attackers on the wall | Adds damage without using the hero's cooldowns |
| **sustain** | Wall healing and shields | Lets risky damage builds survive longer |

### Hero Specific Synergies

#### Arcane Wanderer

- **Core Strength**: Balanced projectile scaling and utility.
- **Best Synergies**: *Projectile (pierce) + Orbitals (reflect)* → sustained multi‑target DPS.
- **Recommended Pairing**: **Piercing Bolts** + **Orbiting Blades** + **Crit Passive**.
- **Counterplay**: Struggles vs heavy single‑target bosses without burst AOE.

#### Ember Knight

- **Core Strength**: Close range burst and sustain.
- **Best Synergies**: *Area (burn) + Passive (life steal)* → durable DPS in melee.
- **Recommended Pairing**: **Flame Slash AOE** + **Burn DoT** + **HP Regen Passive**.
- **Counterplay**: Kited by slows; add mobility or summons to close gap.

#### Frost Witch

- **Core Strength**: Crowd control and kiting.
- **Best Synergies**: *Control (slow) + Projectile (pierce)* → lock enemies for piercing volleys.
- **Recommended Pairing**: **Frost Shard** + **Global Slow Aura** + **Orbitals for zoning**.
- **Counterplay**: Weak vs high HP tanks unless paired with burn or crit.

### Sample Builds

| **Build Name** | **Hero** | **Key Abilities** | **Playstyle** |
| --- | --- | --- | --- |
| **Arcane Volley** | Arcane Wanderer | Piercing Bolts; 2 Orbitals; Crit Passive | Midrange kiting and sustained clear |
| **Blazing Vanguard** | Ember Knight | Flame Slash AOE; Burn DoT; HP Regen | Frontline brawler, sustain through waves |
| **Glacial Cage** | Frost Witch | Frost Shard; Slow Aura; Summon Ice Turret | Control and kite, safe scaling |

### Implementation Notes for Solar2D

- **Synergy Tags**: store as string arrays on ability objects for quick checks.  
- **Synergy Bonus Calculation**: apply small multiplicative buffs when 2+ abilities share a tag (e.g., +10% damage per matching tag).  
- **Upgrade Draft Weighting**: increase probability of offering upgrades that share tags with the hero’s current abilities.  
- **UI**: show tag icons on upgrade cards to make synergies readable at a glance.

## Enemies

### Enemy Types

- Walker — Basic melee chaser
- Runner — Fast, low HP
- Brute — Slow, tanky
- Spitter — Ranged attacker
- Swarmling — Tiny, appears in large groups

### Elite Enemies

- Larger, glowing variants with:
- AOE slam
- Charge attack
- Summoning ability

### New Enemy Types (Expansion)

Each new enemy asks for a specific answer, so that stage rosters push players toward different builds. Every new enemy has a counter-play note; the counter should always be possible with the abilities the stage expects players to have.

| **Enemy** | **Behavior** | **Counter-play** | **First Stage** |
| --- | --- | --- | --- |
| **Shielder** | Carries a shield that blocks projectiles hitting it from the front | Area damage, Patrol Blades, or pierce (a piercing projectile breaks the shield) | Frozen Pass |
| **Frost Golem** | Slow, very tanky, and immune to slow and freeze | Burn, poison, or high single-target damage | Frozen Pass |
| **Bomber** | Runs at the wall and explodes for heavy wall damage | Kill it early; it explodes harmlessly if killed before it reaches the wall | Burning Keep |
| **Splitter** | Splits into 2 smaller copies when killed (the copies do not split again) | Area damage and pierce | Burning Keep |
| **Wraith** | Turns untargetable for 1.5s every 4s | Area damage that is already on the ground, or burst while it is visible | Sunken Crypt |
| **Necromancer** | Stays at range and raises 2 dead enemies every 6s | Prioritize it; projectiles target it first when it is in range | Sunken Crypt |
| **Burrower** | Travels underground and surfaces just in front of the wall | Ground effects near the wall (Poison Cloud, Frost Nova, Patrol Blades) | Arcane Rift |

### Bosses

- Appear at levels 10 (mid boss) and 20 (final boss) in every stage
- Telegraph attacks
- Drop large XP orbs and meta currency
- Each stage has its own boss pair (see **Stages**)

## Progression Systems

### Meta Upgrades (Permanent)

- +HP
- +Damage
- +Movement Speed
- +Pickup Radius
- +Cooldown Reduction
- +Gold Gain

## Stages

A run takes place in one **stage**: a battlefield with its own background, enemy roster, boss pair, and difficulty. There are 5 stages. Stage 1 is open from the start; winning a stage (beating its level 20 boss) unlocks the next. Every run in every stage still ends at level 20. Later stages pay more gold so that replaying them is worth it.

| **#** | **Stage** | **Enemy Health & Damage** | **Gold** | **New Threats** | **Mid Boss (Lv 10)** | **Final Boss (Lv 20)** |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | **Cursed Field** | x1.0 | x1.0 | Current roster | **Bone Colossus** — heavy telegraphed wall hits | **The Lich** — heavy telegraphed wall hits |
| 2 | **Frozen Pass** | x1.3 | x1.25 | Frost Golem, Shielder | **Frost Troll** — telegraphed slam (double wall damage) | **Ice Wyrm** — raises Frost Golems |
| 3 | **Burning Keep** | x1.7 | x1.5 | Bomber, Splitter | **Flame Juggernaut** — charges the wall | **Ember Drake** — calls in Bombers |
| 4 | **Sunken Crypt** | x2.2 | x1.75 | Wraith, Necromancer | **Drowned Priest** — raises walkers | **Crypt Horror** — telegraphed slam (double wall damage) |
| 5 | **Arcane Rift** | x3.0 | x2.0 | Burrower, plus every earlier threat | **Rift Warden** — phases out like a Wraith | **The Unmaker** — slams and raises Wraiths |

Bosses reuse the existing attack mechanics (telegraphed slams, charges, summons, and phasing). Unique attacks such as frost lines or fire rain on marked circles are a future addition.

Each stage defines:

- **Background**: a full-screen battlefield image (Stage 1 uses the current battlefield).
- **Enemy table**: weighted entries with a minimum level and group size, the same shape as the current spawner table. Earlier enemies still appear in later stages.
- **Boss pair**: a mid boss at level 10 and a final boss at level 20.
- **Multipliers**: enemy health and damage, and gold earned.
- **Unlock**: the stage that must be won first.

Players pick a stage after tapping PLAY, then pick a hero. Stage data lives in `data/stages.json`.

## Cards

Cards are a collectible meta system. Players buy **card packs** with gold, keep the cards in a collection, level them up by merging, and equip up to **3 cards** before each run. Cards add power to a run without replacing the level-up draft.

### Card Packs

- A pack costs **150 gold** (to be tuned; a typical run should earn 2–4 packs).
- A pack holds **3 cards**. Each card's tier is rolled independently:

| **Tier** | **Chance per Card** | **Card Color** |
| --- | --- | --- |
| **Common** | 75% | Grey |
| **Uncommon** | 15% | Green |
| **Rare** | 7% | Blue |
| **Legendary** | 2.9% | Gold |
| **Mythic** | 0.1% | Violet |

- Within a tier, every card in that tier has the same chance.
- **Pity counters** keep bad luck from lasting too long:
  - If 9 packs in a row had no Rare-or-better card, the 10th pack is guaranteed one.
  - If 49 packs in a row had no Legendary-or-better card, the 50th pack is guaranteed one.
  - There is no Mythic pity; Mythic cards stay a jackpot.

### Card Kinds

- **Passive** cards apply for the whole run as soon as the run starts.
- **Active** cards have a number of **charges per run**. Each equipped active card appears as a button in the HUD; tapping it spends a charge. Charges refill at the start of every run.
- Using a card never destroys it. A card is only removed from the collection when it is sacrificed in a merge or fusion.

### Card Catalog

Every card has a unique power: no power appears twice, and each tier has its own powers. The launch catalog has **26 cards**: 8 Common, 6 Uncommon, 5 Rare, 4 Legendary, 3 Mythic. Values below are at card level 1; "Per Level" is added for each level above 1.

#### Common (8)

| **Card** | **Kind** | **Level 1 Effect** | **Per Level** |
| --- | --- | --- | --- |
| **Sharpened Focus** | Passive | +4% damage | +0.5% |
| **Stone Mortar** | Passive | +10 wall health | +2 |
| **Scholar's Notes** | Passive | +5% XP | +0.5% |
| **Gold Pouch** | Passive | +5% gold from the run | +0.5% |
| **Iron Spikes** | Passive | Enemies take 2 damage each time they hit the wall | +0.5 |
| **Head Start** | Passive | Start the run with 20 XP | +5 XP |
| **Wall Patch** | Active (1 charge) | Heal the wall for 10% of its maximum health | +1% |
| **Spark** | Active (2 charges) | Strike the 3 nearest enemies for 30 damage | +4 damage |

#### Uncommon (6)

| **Card** | **Kind** | **Level 1 Effect** | **Per Level** |
| --- | --- | --- | --- |
| **Swift Casting** | Passive | +6% cooldown speed | +0.5% |
| **Ember Brand** | Passive | Hits have a 10% chance to burn for 3s | +1% chance |
| **Bulwark** | Passive | The wall takes 8% less damage | +0.5% |
| **Bounty Hunter** | Passive | Elites give +50% XP | +5% |
| **Second Opinion** | Active (1 charge) | Reroll the current level-up draft | No per-level growth; milestones add charges |
| **Frost Pulse** | Active (2 charges) | Slow every enemy on screen by 40% for 4s | +0.2s |

#### Rare (5)

| **Card** | **Kind** | **Level 1 Effect** | **Per Level** |
| --- | --- | --- | --- |
| **Split Shot** | Passive | +1 projectile for projectile abilities | Extra projectiles lose 2% less damage per level |
| **Chain Reaction** | Passive | Kills have a 15% chance to explode for 20 area damage | +1% chance, +2 damage |
| **Executioner** | Passive | +25% damage to elites and bosses | +2% |
| **Purge** | Active (1 charge) | Destroy every non-boss enemy on screen | Bosses on screen take 2% of max health per level |
| **Bastion** | Active (1 charge) | The wall takes no damage for 6s | +0.3s |

#### Legendary (4)

| **Card** | **Kind** | **Level 1 Effect** | **Per Level** |
| --- | --- | --- | --- |
| **Second Wind** | Passive | The first time the wall would fall, it survives at 50% health instead | +2% health restored |
| **Sixth Seal** | Passive | +1 active ability slot (6 instead of 5) | +2% damage for the sixth ability |
| **Twin Cast** | Passive | Abilities have a 15% chance to fire twice | +1% |
| **Meteor Storm** | Active (1 charge) | 8 meteors strike random enemies for 150 damage each | +10 damage |

#### Mythic (3)

| **Card** | **Kind** | **Level 1 Effect** | **Per Level** |
| --- | --- | --- | --- |
| **Time Stop** | Active (1 charge) | Freeze every enemy for 5s; abilities keep firing | +0.2s |
| **Arcane Singularity** | Active (1 charge) | Pull every non-boss enemy to one point and deal 500 damage | +40 damage |
| **Ascendance** | Passive | Every 5th level-up lets the player pick 2 cards from the draft instead of 1 | No per-level growth; milestones improve it |

### Card Levels

- Cards go from **level 1 to level 15**.
- A card's main value grows with level: `value = level 1 value + per level × (level − 1)`.
- Levels **5, 10, and 15** are **milestones** that add an extra bonus on top of the normal growth:
  - **Level 5**: a secondary effect. Examples: Spark strikes 4 enemies instead of 3; Executioner also adds +10% crit damage; Time Stop also makes frozen enemies take 10% more damage.
  - **Level 10**: active cards get **+1 charge**; passive cards get their level 1 value added again.
  - **Level 15**: a **capstone** unique to the card. Examples: Stone Mortar's wall health also regenerates 1 per second; Purge also heals the wall 1% per enemy destroyed; Second Wind triggers twice per run. Each card's milestone bonuses are listed in `data/cards.json` and on the card detail screen.

### Merging (Leveling Up)

A card levels up by **sacrificing other cards of the same tier**. Any card of the same tier counts, including duplicates of the card itself. Sacrificed cards are removed from the collection.

| **To Reach Level** | **Cards Sacrificed per Level** | **Levels in Band** | **Total for Band** |
| --- | --- | --- | --- |
| 2–5 | 5 | 4 | 20 |
| 6–10 | 10 | 5 | 50 |
| 11–15 | 20 | 5 | 100 |

- Reaching level 10 costs 10 cards; reaching level 11 costs 20.
- Taking one card from level 1 to level 15 costs **170 cards** of its tier.

### Fusion

Fusion turns spare cards into a card of a higher tier, so that high tiers stay reachable even with low drop rates.

- **5 Common** cards fuse into 1 random **Uncommon** card.
- **5 Uncommon** cards fuse into 1 random **Rare** card.
- **5 Rare** cards fuse into 1 random **Legendary** card.
- **10 Legendary** cards fuse into 1 random **Mythic** card.
- The new card starts at level 1. The sacrificed cards' levels are lost.

### Loadout

- Before a run, the player equips up to **3 cards** on the hero select screen.
- A card can be equipped in only one slot. Changing the loadout is free.
- Equipped passive cards add to the run's starting bonuses alongside permanent upgrades and the hero's own bonus.
- Equipped active cards appear as HUD buttons next to the ability indicators.

## Unlockables

- New heroes
- New abilities
- New difficulty tiers
- Cosmetic skins

## Art Direction

### Visual Style

- Silhouette characters with glowing accents
- Soft gradient backgrounds
- Parallax layers for depth
- High‑contrast enemies for readability
- Minimal UI with clean icons

### Animation Style

- Simple 2–4 frame loops
- Impact flashes and hit sparks
- Screen shake for big hits

## Technical Design (Solar2D)

### Key Systems

- Update Loop: Centralized game loop calling entity updates
- Spawner: Time‑based enemy waves
- Collision System: AABB or distance‑based
- Upgrade Draft: Weighted random selection
- Object Pooling: For enemies and projectiles
- Camera: Static or slight follow offset

### Monetization (Optional)

- Cosmetic skins
- Battle pass with XP boosters
- Ad‑based revives
- Meta progression accelerators
- No pay‑to‑win mechanics

### Roadmap (MVP → Launch)

#### MVP (2–3 Weeks)

- One hero
- One enemy type
- Basic auto‑attack
- XP + level‑up system
- 3–5 upgrades
- 5‑minute survival mode

#### Alpha

- 3 heroes
- 5 enemy types
- 20+ upgrades
- Boss fight
- Meta progression

#### Beta

- Polished UI
- Sound + music
- Difficulty tiers
- Save system

#### Expansion

1. Update this design document (stages, new enemies, new abilities, cards).
2. Card core: card data, collection, packs with pity, merging, fusion, loadout, saved progress.
3. Card screens: card shop with pack opening, collection with merge and fusion, loadout on hero select, card art.
4. Cards in runs: passive card bonuses and active card HUD buttons.
5. New enemies: Shielder, Frost Golem, Bomber, Splitter, Wraith, Necromancer, Burrower.
6. New abilities: Chain Lightning, Meteor, Poison Cloud, Spirit Turret, Keen Eye, Mending Wards.
7. Stages: 5 stages with their own backgrounds, rosters, boss pairs, stage select, and unlocks.

#### Launch

- Cosmetics
- Additional heroes
- Daily challenges
- Leaderboards
