# Godot — Version Reference

| Field | Value |
|-------|-------|
| **Engine Version** | 4.6.1 |
| **Project Pinned** | 2026-05-18 |
| **LLM Knowledge Cutoff** | May 2025 |
| **Risk Level** | MEDIUM — Godot 4.4–4.6 are near or beyond the LLM training cutoff |

## Knowledge Gap Analysis

The LLM's training data covers Godot up to approximately version 4.3. The project uses Godot 4.6.1, which introduces changes across 4.4, 4.5, and 4.6 that may not be fully represented in LLM suggestions.

| Version | Status | Key Concern |
|---------|--------|-------------|
| 4.3     | Within training data | LOW RISK — well-represented |
| 4.4     | At training boundary | MEDIUM RISK — some API changes may be missed |
| 4.5     | Beyond training data | MEDIUM RISK — verify API suggestions |
| 4.6     | Beyond training data | MEDIUM RISK — verify API suggestions |

## Verification Required

When agents suggest Godot API calls for 4.4+, they should:
1. Check `deprecated-apis.md` before suggesting any API
2. Check `breaking-changes.md` for version-specific behavior changes
3. Use WebSearch to verify uncertain APIs against the official Godot 4.6 docs
4. Flag any suggestion that may be version-sensitive with a note

## Post-Cutoff Version Timeline

| Version | Release Date | Key Highlights |
|---------|-------------|----------------|
| 4.4 | 2025-02 | Vulkan mobile improvements, new tile map system, enhanced animation |
| 4.5 | ~2025-06 | (Verify release date — estimated) |
| 4.6 | ~2025-10+ | (Verify release date — project uses 4.6.1) |

> **Note**: Release dates after 4.4 are approximate. Run `/setup-engine refresh` to update with verified dates.

## Migration Notes — 4.3 → 4.6.1

See `breaking-changes.md` and `deprecated-apis.md` for detailed per-version migration guidance. The project was created on 4.6.1 so no migration is needed, but agents must avoid suggesting pre-4.4 APIs that may have been removed or changed.