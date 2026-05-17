# Asset Intake Manifest

## Purpose

This file records which curated source packs from `E:\Archive\Godot\shuyi\assets` have been copied into the Godot project and where they now live under `shuyi_playland/assets`.

---

## First Batch Imported

### 1. Pixel UI pack 3

**Source:**

- `E:\Archive\Godot\shuyi\assets\Pixel UI pack 3\*.png`

**Project destination:**

- `res://assets/ui/buttons/`

**Intended use:**

- Home cards and CTA skins
- Reward/result action buttons
- Growth / sign-in / achievement page button polish

---

### 2. Kyrise's 16x16 RPG Icon Pack - V1.3

**Source:**

- `E:\Archive\Godot\shuyi\assets\Kyrise's 16x16 RPG Icon Pack - V1.3\icons\*`

**Project destination:**

- `res://assets/ui/icons/system/`

**Intended use:**

- Navigation icons
- Settings / achievements / sign-in / wrong-book icons
- Module and state iconography

---

### 3. Ninja Adventure - Asset Pack

**Source:**

- `E:\Archive\Godot\shuyi\assets\Ninja Adventure - Asset Pack\Actor\*`
- `E:\Archive\Godot\shuyi\assets\Ninja Adventure - Asset Pack\Items\*`
- `E:\Archive\Godot\shuyi\assets\Ninja Adventure - Asset Pack\FX\*`

**Project destination:**

- `res://assets/characters/mascots/`
- `res://assets/mini_games/pickups/food/`
- `res://assets/effects/ui_feedback/`

**Intended use:**

- Mascot / helper character presentation
- Mini-game pickups
- UI and gameplay feedback FX

---

### 4. Free Pixel Effects Pack

**Source:**

- `E:\Archive\Godot\shuyi\assets\Free Pixel Effects Pack\*.png`

**Project destination:**

- `res://assets/effects/reward/`

**Intended use:**

- Reward burst
- Success feedback
- Result page sparkle FX
- Sign-in / achievement reward animation candidates

---

### 5. FreePixelFood

**Source:**

- `E:\Archive\Godot\shuyi\assets\FreePixelFood\Assets\*`

**Project destination:**

- `res://assets/mini_games/pickups/food/`

**Intended use:**

- Mini-game collectible props
- Secondary fun pickups, not core currency

---

### 6. 0x72_DungeonTilesetII_v1.7

**Source:**

- `E:\Archive\Godot\shuyi\assets\0x72_DungeonTilesetII_v1.7\*.png`
- `E:\Archive\Godot\shuyi\assets\0x72_DungeonTilesetII_v1.7\frames\*`

**Project destination:**

- `res://assets/mini_games/dungeon/tiles/`
- `res://assets/mini_games/dungeon/props/`

**Intended use:**

- Dungeon mini-game map visuals
- Home decorative packaging
- Level path / exploration-style packaging

---

## Deliberately Not Imported Yet

These were intentionally deferred because they are either lower priority, style-risky, or product-direction mismatched:

- `Free Icon Pack v3.1 (Basic)/`
- `Fantasy Knight - Free Pixelart Animated Character/`
- `MainCharacter(FreePack)/`
- `Small-8-Direction-Characters_by_AxulArt/`
- `Rodwan_Cliffs/`
- `Holy VFX 01-02/`
- `Free Smoke Fx Pixel 2/`
- weapon / gun / PSX model packs

Reasons for deferment:

- avoid style overload before scene-level integration
- avoid importing conflicting character styles too early
- avoid product-tone mismatch for education UX

---

## What This Means

The project now has a first normalized intake of:

- UI skin candidates
- iconography candidates
- mascot / mini-game character candidates
- reward FX candidates
- collectible candidates
- dungeon mini-game environment candidates

This completes the **asset intake and organization** step, but does **not yet mean scenes are visually upgraded**. Scene-level replacement and node binding remain the next implementation layer.
