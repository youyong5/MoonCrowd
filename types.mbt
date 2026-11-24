// Copyright 2026 MoonCrowd contributors. SPDX-License-Identifier: Apache-2.0

///|
/// Invalid inputs are rejected before the simulator is changed.
#derive(Debug)
pub suberror CrowdError {
  InvalidInput(String)
  UnknownAgent(Int32)
  UnknownObstacle(Int32)
  NumericalFailure(String)
}

///|
/// Kinematic discs: velocities can change immediately, with no acceleration cap.
#derive(Eq, Debug)
pub(all) struct AgentConfig {
  radius : Double
  max_speed : Double
  neighbor_distance : Double
  max_neighbors : Int32
  time_horizon : Double
  obstacle_horizon : Double
}

///|
pub fn AgentConfig::default() -> AgentConfig {
  {
    radius: 0.3,
    max_speed: 1.5,
    neighbor_distance: 8.0,
    max_neighbors: 16,
    time_horizon: 3.0,
    obstacle_horizon: 3.0,
  }
}

///|
#derive(Eq, Debug)
pub(all) struct AgentState {
  id : Int32
  position : Vec2
  velocity : Vec2
  preferred_velocity : Vec2
  config : AgentConfig
}

///|
/// Feasible velocities lie on the left of this directed line.
/// A positive violation is det(direction, point - velocity).
#derive(Eq, Debug)
pub(all) struct Constraint {
  point : Vec2
  direction : Vec2
  obstacle : Bool
}

///|
#derive(Eq, Debug)
pub(all) struct AgentDiagnostics {
  id : Int32
  neighbors : Int32
  neighbors_truncated : Bool
  obstacle_constraints : Int32
  constraints : Array[Constraint]
  used_fallback : Bool
  max_violation : Double
  overlapping_neighbors : Int32
}

///|
#derive(Eq, Debug)
pub(all) struct StepReport {
  step : Int32
  time : Double
  agents : Array[AgentDiagnostics]
  fallback_agents : Int32
  violating_agents : Int32
  neighbor_candidates : Int32
}

///|
/// Independent value checkpoint. Mutating arrays returned by states() cannot
/// mutate a simulator or a checkpoint. Restoring preserves IDs and step count.
pub struct Snapshot {
  dt : Double
  tick : Int32
  agents : Array[AgentState?]
  obstacles : Array[Array[Vec2]?]
}

///|
priv struct Edge {
  a : Vec2
  b : Vec2
  direction : Vec2
  previous_direction : Vec2
  next_direction : Vec2
  convex_a : Bool
  convex_b : Bool
}

///|
pub struct Simulator {
  dt : Double
  mut tick : Int32
  agents : Array[AgentState?]
  obstacles : Array[Array[Vec2]?]
}

///|
fn validate_vector(v : Vec2) -> Unit raise CrowdError {
  if !v.is_finite() || v.x.abs() > 1.0e6 || v.y.abs() > 1.0e6 {
    raise InvalidInput("vector must be finite and within +/-1e6")
  }
}

///|
fn validate_config(c : AgentConfig) -> Unit raise CrowdError {
  if !c.radius.is_finite() ||
    c.radius < 1.0e-6 ||
    c.radius > 1.0e4 ||
    !c.max_speed.is_finite() ||
    c.max_speed < 0.0 ||
    c.max_speed > 1.0e4 ||
    !c.neighbor_distance.is_finite() ||
    c.neighbor_distance <= 0.0 ||
    c.neighbor_distance > 1.0e6 ||
    c.max_neighbors < 0 ||
    c.max_neighbors > 100000 ||
    !c.time_horizon.is_finite() ||
    c.time_horizon < 1.0e-4 ||
    c.time_horizon > 1.0e4 ||
    !c.obstacle_horizon.is_finite() ||
    c.obstacle_horizon < 1.0e-4 ||
    c.obstacle_horizon > 1.0e4 {
    raise InvalidInput("invalid disc configuration; see docs/CONTRACT.md")
  }
}
