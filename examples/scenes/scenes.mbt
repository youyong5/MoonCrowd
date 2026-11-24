// Copyright 2026 MoonCrowd contributors. SPDX-License-Identifier: Apache-2.0
// Application-owned goals and demo scene policy; not part of the ORCA kernel.

///|
pub struct Scene {
  simulator : @crowd.Simulator
  priv goals : Array[@crowd.Vec2]
  walls : Array[Array[@crowd.Vec2]]
  kind : Int32
}

///|
/// 0: circle exchange; 1: crossing flows; 2: narrow doorway.
pub fn create(kind : Int32, count : Int32) -> Scene raise @crowd.CrowdError {
  let simulator = @crowd.Simulator::new()
  let goals : Array[@crowd.Vec2] = []
  let walls : Array[Array[@crowd.Vec2]] = []
  let count = count.max(4).min(160)
  if kind == 2 {
    walls.push([@crowd.Vec2::new(0.0, -9.0), @crowd.Vec2::new(0.0, -1.2)])
    walls.push([@crowd.Vec2::new(0.0, 1.2), @crowd.Vec2::new(0.0, 9.0)])
    for wall in walls {
      simulator.add_obstacle(wall) |> ignore
    }
  }
  for i in 0..<count {
    let position : @crowd.Vec2 = if kind == 0 {
      let angle = 2.0 * 3.141592653589793 * i.to_double() / count.to_double()
      @crowd.Vec2::new(8.0 * @math.cos(angle), 8.0 * @math.sin(angle))
    } else {
      let side = if i % 2 == 0 { -1.0 } else { 1.0 }
      let k = i / 2
      @crowd.Vec2::new(
        side * (4.0 + (k % 6).to_double() * 0.75),
        ((k / 6).to_double() - 6.0) * 0.75,
      )
    }
    simulator.add_agent(position, config={
      ..@crowd.AgentConfig::default(),
      radius: 0.18,
      neighbor_distance: 20.0,
      max_neighbors: 160,
      time_horizon: 2.5,
    })
    |> ignore
    goals.push(@crowd.Vec2::new(-position.x, -position.y))
  }
  { simulator, goals, walls, kind, }
}

///|
pub fn Scene::advance(
  self : Scene,
) -> @crowd.StepReport raise @crowd.CrowdError {
  for agent in self.simulator.states() {
    let target = self.goals[agent.id]
    // Doorway waypoints belong to the host's route policy. ORCA has no planner.
    let waypoint = if self.kind == 2 &&
      agent.position.x * target.x < 0.0 &&
      agent.position.x.abs() > 0.8 {
      @crowd.Vec2::new(0.0, if agent.position.x < 0.0 { -0.4 } else { 0.4 })
    } else {
      target
    }
    self.simulator.steer_toward(agent.id, waypoint, arrival_radius=0.08)
    let state = self.simulator.agent(agent.id)
    // Deterministic side preference (0.3 of forward velocity) breaks perfectly symmetric deadlocks.
    // Explicit example policy, not a collision guarantee or a change to ORCA.
    if self.kind != 2 && agent.position.distance(target) > 0.3 {
      let v = state.preferred_velocity
      self.simulator.set_preferred_velocity(
        agent.id,
        @crowd.Vec2::new(v.x - 0.3 * v.y, v.y + 0.3 * v.x),
      )
    }
  }
  self.simulator.step()
}

///|
pub fn Scene::arrived(self : Scene) -> Int32 {
  let mut count = 0
  for a in self.simulator.states() {
    if a.position.distance(self.goals[a.id]) < 0.15 {
      count += 1
    }
  }
  count
}

///|
pub fn Scene::minimum_clearance(self : Scene) -> Double {
  let states = self.simulator.states()
  let mut clearance = 1.0e9
  for i in 0..<states.length() {
    for j in (i + 1)..<states.length() {
      clearance = clearance.min(
        states[i].position.distance(states[j].position) -
        states[i].config.radius -
        states[j].config.radius,
      )
    }
  }
  if states.length() < 2 {
    0.0
  } else {
    clearance
  }
}
