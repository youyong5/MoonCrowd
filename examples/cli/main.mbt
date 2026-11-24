// Copyright 2026 MoonCrowd contributors. SPDX-License-Identifier: Apache-2.0

///|
fn main {
  try {
    for kind in 0..<3 {
      let scene = @scenes.create(kind, 48)
      let mut fallbacks = 0
      let mut violations = 0
      let mut clearance = 1.0e9
      for _ in 0..<400 {
        let report = scene.advance()
        fallbacks += report.fallback_agents
        violations += report.violating_agents
        clearance = clearance.min(scene.minimum_clearance())
      }
      println(
        "scene=\{kind} steps=400 arrived=\{scene.arrived()}/48 min_disc_clearance=\{clearance} fallback_agent_steps=\{fallbacks} violating_agent_steps=\{violations}",
      )
    }
  } catch {
    err => {
      println("MoonCrowd example failed: \{err.message()}")
      panic()
    }
  }
}
