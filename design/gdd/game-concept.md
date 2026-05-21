---
status: reverse-documented
source: shuyi_playland/ + 数一游园_Godot开发方案.md
date: 2026-05-18
verified-by: user
---

# Game Concept: 数一游园 (Shuyi Playland)

## Overview

数一游园 (Shuyi Playland) is an offline math learning app for Chinese elementary students grades 1–6. It wraps structured math exercises in light gamification — levels, tasks, growth progression, and rewards — making repetitive practice feel purposeful without becoming a heavy RPG. The core fantasy is "a student exploring a math park where every correct answer earns real progress."

## Player Fantasy

A young student who feels math practice is boring discovers a colorful park where each exercise is a challenge, each correct answer earns stars and coins, and each day they return to find new tasks waiting. The fantasy is: **steady, visible growth through practice** — not competition or combat, but personal progression that feels rewarding.

## Core Pillars

1. **Practice with Purpose** — Every exercise advances the student's level, earns currency, and unlocks new content.
2. **Light Gamification** — Tasks, streaks, and achievements wrap the learning, but math remains the core.
3. **Offline First** — The entire app works without internet. All data is local.
4. **Data-Driven Content** — Questions, levels, rewards, and rules are JSON configs, not hardcoded.

## Target Audience

- **Primary**: Chinese elementary students grades 1–6 (ages 6–12)
- **Platform**: Android phones, portrait orientation (720×1280)
- **Input**: Touch-only (no gamepad, no keyboard)
- **[TR-concept-004]** Performance target: 60fps on mid-range Android devices (2GB RAM, Snapdragon 600-class or equivalent); 16.6ms frame budget; 100 draw calls max; 256MB memory ceiling

## Key Metrics (from existing implementation)

| Metric | Value |
|--------|-------|
| Questions | 158 (target: 300+) |
| Grades | 6 (grades 1–6) |
| Modules | 28 |
| Knowledge points | 23 |
| Levels | 24 |
| Question types | 10 |
| Session modes | 6 (level, special_practice, random_practice, mock_test, wrong_retry, mini_game) |

## Related Systems

- [[content-system.md]] — Content hierarchy and data pipeline
- [[practice-system.md]] — Session modes, question rendering, scoring
- [[question-types.md]] — 10 question type specifications
- [[growth-system.md]] — Progression, tasks, achievements, sign-in
- [[persistence-system.md]] — Save/load, backup, SQLite
- [[ui-navigation.md]] — Screen flow and navigation

## Scope Boundaries

### In Scope (v1.0)
- Offline single-player math practice
- 6 session modes
- 10 question types
- Growth system (level, EXP, gold, tasks, achievements)
- Wrong answer review
- Backup/export/import
- Android APK

### Out of Scope (v1.0)
- Multiplayer or online features
- Parental controls (future)
- In-app purchases
- Server-synced content updates (future — content is bundled)
- Advanced analytics dashboard (future)