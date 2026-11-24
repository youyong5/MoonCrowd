// Copyright 2026 MoonCrowd contributors. SPDX-License-Identifier: Apache-2.0

///|
/// Change one disc's configuration without silently clamping current velocity.
/// Rejected updates leave the old config/state intact. Changing radius can
/// create geometric overlap; inspect audit() after host-driven changes.
pub fn Simulator::set_config(
  self : Simulator,
  id : Int32,
  config : AgentConfig,
) -> Unit raise CrowdError {
  let current = self.agent(id)
  validate_config(config)
  if config.time_horizon < self.dt || config.obstacle_horizon < self.dt {
    raise InvalidInput("prediction horizons must be at least time_step")
  }
  if current.velocity.length() > config.max_speed + 1.0e-9 {
    raise InvalidInput(
      "new max_speed is below current velocity; explicitly set_state first",
    )
  }
  self.agents[id] = Some({ ..current, config, })
}

///|
/// Apply host-generated preferences as one atomic batch. Duplicate IDs are
/// rejected instead of making behavior depend on accidental input ordering.
pub fn Simulator::set_preferred_velocities(
  self : Simulator,
  updates : Array[(Int32, Vec2)],
) -> Unit raise CrowdError {
  let seen = Array::make(self.agents.length(), false)
  let staged : Array[AgentState] = []
  for (id, preferred_velocity) in updates {
    let current = self.agent(id)
    validate_vector(preferred_velocity)
    if seen[id] {
      raise InvalidInput("duplicate agent ID in preference batch")
    }
    seen[id] = true
    staged.push({ ..current, preferred_velocity, })
  }
  for state in staged {
    self.agents[state.id] = Some(state)
  }
}
