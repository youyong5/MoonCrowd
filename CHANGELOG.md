# Changelog

## 0.1.0 — 2026-11-26 (Mooncakes unpublished)

- Port pinned RVO2 disc and obstacle ORCA constraints and LP fallback to MoonBit Double.
- Add deterministic neighbor tree, stable IDs, input/geometry validation and atomic stepping.
- Add per-agent constraints, residuals, truncation and overlap diagnostics.
- Add exact global geometric overlap counts and signed clearances with bounded detail arrays.
- Add atomic host preference batches and validated runtime config updates.
- Surface geometry metrics in CLI/browser alongside velocity-constraint residuals.
- Add independent in-memory checkpoints and arrival-velocity helper.
- Add four-backend regression tests and 2,304 independent RVO2 state fixtures.
- Add CLI scenarios, static browser demo, separate-module consumer test and CI workflows.
- Document model assumptions, infeasibility, numerical limits and licensing boundaries.
- Lock failed demo controls until successful reset; keep selected scene consistent on reset failure.
- Verify both reference JSON and formatted MoonBit assertions from a clean pinned upstream checkout.
- Add a checked local release command with tracked-source packaging, Git history and SHA-256 manifest.

- Verify independent consumers against both workspace and the actual packaged ZIP; prepare an exact-version registry mode.
- Pause after reset and keep count controls consistent after a failed scene rebuild.
- Exercise real Chromium desktop, mobile touch/high DPI and offline-file use in CI, including recovery and canvas/layout checks.
- Keep the compact mobile header source link on one line; cover it in layout checks.
- Add a manually triggered, successful-CI-gated GitHub Release workflow with checked ZIP and SHA-256 assets.
