// Copyright 2026 MoonCrowd contributors. SPDX-License-Identifier: Apache-2.0

///|
fn main {
  try {
    for kind in 0..<3 {
      let scene = @scenes.create(kind, 48)
      let mut fallbacks = 0
      let mut violations = 0
      let mut clearance = 1.0e9
      let mut overlapping_pair_steps = 0
      let mut obstacle_contact_steps = 0
      for _ in 0..<400 {
        let report = scene.advance()
        fallbacks += report.fallback_agents
        violations += report.violating_agents
        clearance = clearance.min(scene.minimum_clearance())
        let audit = scene.simulator.audit()
        overlapping_pair_steps += audit.agent_overlap_count
        obstacle_contact_steps += audit.obstacle_overlap_count
      }
      println(
        "scene=\{kind} steps=400 arrived=\{scene.arrived()}/48 min_disc_clearance=\{clearance} fallback_agent_steps=\{fallbacks} violating_agent_steps=\{violations} overlapping_pair_steps=\{overlapping_pair_steps} obstacle_contact_steps=\{obstacle_contact_steps}",
      )
    }
  } catch {
    err => {
      println("MoonCrowd example failed: \{err.message()}")
      panic()
    }
  }
}
