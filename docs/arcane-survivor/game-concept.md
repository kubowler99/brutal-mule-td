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
- Collect XP orbs from defeated enemies.
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
- Orbitals (rotating blades, fireballs)
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

#### Orbiting Blades

- Lv2: +1 blade
- Lv3: +25% rotation speed
- Lv4: Blades grow in size
- Lv5: Blades explode on hit

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

### Bosses

- Appear at levels 10 and 20
- Telegraph attacks
- Drop large XP orbs and meta currency

## Progression Systems

### Meta Upgrades (Permanent)

- +HP
- +Damage
- +Movement Speed
- +Pickup Radius
- +Cooldown Reduction
- +Gold Gain

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

#### Launch

- Cosmetics
- Additional heroes
- Daily challenges
- Leaderboards
