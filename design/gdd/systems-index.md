# Systems Index

> **Last updated**: 2026-05-18
> **Project**: 数一游园 (Shuyi Playland)
> **Phase**: Production (v0.9.2)

## Systems List

| System | GDD | Layer | Priority | Status |
|--------|-----|-------|----------|--------|
| Game Concept | [game-concept.md](game-concept.md) | Foundation | — | Approved |
| Content System | [content-system.md](content-system.md) | Foundation | P0 | Approved |
| Practice System | [practice-system.md](practice-system.md) | Core | P0 | Approved |
| Question Types | [question-types.md](question-types.md) | Core | P0 | Approved |
| Growth System | [growth-system.md](growth-system.md) | Feature | P0 | Approved |
| Persistence System | [persistence-system.md](persistence-system.md) | Foundation | P0 | Approved |
| UI & Navigation | [ui-navigation.md](ui-navigation.md) | Presentation | P0 | Approved |
| Audio System | [audio-system.md](audio-system.md) | Polish | P1 | Partially Implemented |

## Layer Definitions

- **Foundation**: Systems that everything else depends on (content, persistence, concept)
- **Core**: Primary gameplay systems (practice, question types)
- **Feature**: Supporting systems that enhance gameplay (growth, achievements, tasks)
- **Presentation**: UI, navigation, visual feedback
- **Polish**: Audio, animations, visual effects (not yet documented as separate GDDs)

## Dependency Graph

```
Game Concept (defines the product)
  └─ Content System (provides question data)
       └─ Practice System (uses questions, records answers)
            ├─ Question Types (renders questions)
            ├─ Growth System (tracks progress, awards rewards)
            └─ Persistence System (saves all state)
  └─ UI & Navigation (orchestrates all screens)
       └─ connects to all other systems via AppState signals
```

## Notes

- All GDDs are reverse-documented from existing implementation (status: `reverse-documented`)
- Mini-game system uses hardcoded questions (MVP placeholder) — documented in practice-system.md
- Audio system, animation system, and settings system are implemented but not yet documented as separate GDDs
- Admin backend (Node.js) is implemented but not documented in this index (external tool, not a game system)