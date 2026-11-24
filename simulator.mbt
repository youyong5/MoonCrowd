// Copyright 2026 MoonCrowd contributors. SPDX-License-Identifier: Apache-2.0

///|
/// Fixed step in [1e-4, 1] seconds; agents use world units and units/second.
pub fn Simulator::new(time_step~ : Double = 0.05) -> Simulator raise CrowdError {
  if !time_step.is_finite() || time_step < 1.0e-4 || time_step > 1.0 {
    raise InvalidInput("time_step must be finite and in [1e-4, 1]")
  }
  { dt: time_step, tick: 0, agents: [], obstacles: [], }
}

///|
pub fn Simulator::time_step(self : Simulator) -> Double {
  self.dt
}

///|
pub fn Simulator::step_count(self : Simulator) -> Int32 {
  self.tick
}

///|
pub fn Simulator::time(self : Simulator) -> Double {
  self.tick.to_double() * self.dt
}

///|
pub fn Simulator::agent(
  self : Simulator,
  id : Int32,
) -> AgentState raise CrowdError {
  if id < 0 || id >= self.agents.length() {
    raise UnknownAgent(id)
  }
  match self.agents[id] {
    Some(a) => a
    None => raise UnknownAgent(id)
  }
}

///|
/// Owned array of immutable state values, ordered by stable ID.
pub fn Simulator::states(self : Simulator) -> Array[AgentState] {
  let result : Array[AgentState] = []
  for slot in self.agents {
    if slot is Some(a) {
      result.push(a)
    }
  }
  result
}

///|
pub fn Simulator::add_agent(
  self : Simulator,
  position : Vec2,
  config~ : AgentConfig = AgentConfig::default(),
  velocity~ : Vec2 = Vec2::zero(),
) -> Int32 raise CrowdError {
  validate_vector(position)
  validate_vector(velocity)
  validate_config(config)
  if velocity.length() > config.max_speed + 1.0e-9 {
    raise InvalidInput("initial velocity exceeds max_speed")
  }
  if self.states().length() >= 10000 || self.agents.length() >= 100000 {
    raise InvalidInput("agent capacity reached")
  }
  let id = self.agents.length()
  self.agents.push(
    Some({ id, position, velocity, preferred_velocity: Vec2::zero(), config, }),
  )
  id
}

///|
/// IDs are never reused; removing an agent cannot retarget an old handle.
pub fn Simulator::remove_agent(
  self : Simulator,
  id : Int32,
) -> Unit raise CrowdError {
  self.agent(id) |> ignore
  self.agents[id] = None
}

///|
pub fn Simulator::set_preferred_velocity(
  self : Simulator,
  id : Int32,
  velocity : Vec2,
) -> Unit raise CrowdError {
  let state = self.agent(id)
  validate_vector(velocity)
  self.agents[id] = Some({ ..state, preferred_velocity: velocity, })
}

///|
/// Changes current kinematic state explicitly, e.g. for a host-authoritative actor.
pub fn Simulator::set_state(
  self : Simulator,
  id : Int32,
  position : Vec2,
  velocity : Vec2,
) -> Unit raise CrowdError {
  let state = self.agent(id)
  validate_vector(position)
  validate_vector(velocity)
  if velocity.length() > state.config.max_speed + 1.0e-9 {
    raise InvalidInput("velocity exceeds max_speed")
  }
  self.agents[id] = Some({ ..state, position, velocity, })
}

///|
/// Call each tick. This supplies an arrival-aware preferred velocity, not a path.
pub fn Simulator::steer_toward(
  self : Simulator,
  id : Int32,
  target : Vec2,
  arrival_radius~ : Double = 0.05,
) -> Unit raise CrowdError {
  let state = self.agent(id)
  validate_vector(target)
  if !arrival_radius.is_finite() ||
    arrival_radius < 0.0 ||
    arrival_radius > 1.0e6 {
    raise InvalidInput("invalid arrival_radius")
  }
  let delta = target - state.position
  let distance = delta.length()
  let speed = ((distance - arrival_radius).max(0.0) / self.dt).min(
    state.config.max_speed,
  )
  self.agents[id] = Some({
    ..state,
    preferred_velocity: unit(delta).scale(speed),
  })
}

///|
fn orient_sign(a : Vec2, b : Vec2, c : Vec2) -> Int32 {
  let value = left_of(a, b, c)
  if value > 1.0e-10 {
    1
  } else if value < -1.0e-10 {
    -1
  } else {
    0
  }
}

///|
fn on_segment(p : Vec2, a : Vec2, b : Vec2) -> Bool {
  orient_sign(a, b, p) == 0 &&
  p.x >= a.x.min(b.x) - 1.0e-10 &&
  p.x <= a.x.max(b.x) + 1.0e-10 &&
  p.y >= a.y.min(b.y) - 1.0e-10 &&
  p.y <= a.y.max(b.y) + 1.0e-10
}

///|
fn segments_touch(a : Vec2, b : Vec2, c : Vec2, d : Vec2) -> Bool {
  let ab_c = orient_sign(a, b, c)
  let ab_d = orient_sign(a, b, d)
  let cd_a = orient_sign(c, d, a)
  let cd_b = orient_sign(c, d, b)
  (ab_c * ab_d < 0 && cd_a * cd_b < 0) ||
  on_segment(c, a, b) ||
  on_segment(d, a, b) ||
  on_segment(a, c, d) ||
  on_segment(b, c, d)
}

///|
fn point_inside(p : Vec2, vertices : Array[Vec2]) -> Bool {
  if vertices.length() < 3 {
    return false
  }
  let mut inside = false
  for i in 0..<vertices.length() {
    let a = vertices[i]
    let b = vertices[(i + 1) % vertices.length()]
    if (a.y > p.y) != (b.y > p.y) &&
      p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x {
      inside = !inside
    }
  }
  inside
}

///|
/// Two vertices make a two-sided wall. >=3 vertices make a simple solid
/// polygon, normalized to CCW. Separate obstacles must not touch or overlap.
pub fn Simulator::add_obstacle(
  self : Simulator,
  vertices : Array[Vec2],
) -> Int32 raise CrowdError {
  let n = vertices.length()
  if n < 2 || n > 1024 || self.obstacles.length() >= 4096 {
    raise InvalidInput(
      "obstacle needs 2..1024 vertices; capacity is 4096 handles",
    )
  }
  let points = vertices.copy()
  for p in points {
    validate_vector(p)
  }
  for i in 0..<n {
    if points[i].distance(points[(i + 1) % n]) < 1.0e-6 {
      raise InvalidInput(
        "obstacle edge is too short; do not repeat closing vertex",
      )
    }
  }
  if n > 2 {
    let mut area = 0.0
    for i in 0..<n {
      area += det(points[i] - points[0], points[(i + 1) % n] - points[0])
      let a = points[(i + n - 1) % n]
      let b = points[i]
      let c = points[(i + 1) % n]
      if orient_sign(a, b, c) == 0 && (b - a).dot(c - b) < 0.0 {
        raise InvalidInput("backtracking obstacle edge")
      }
      for j in (i + 1)..<n {
        if j == i + 1 || (i == 0 && j == n - 1) {
          continue
        }
        if segments_touch(
            points[i],
            points[(i + 1) % n],
            points[j],
            points[(j + 1) % n],
          ) {
          raise InvalidInput("self-intersecting obstacle")
        }
      }
    }
    if area.abs() < 1.0e-10 {
      raise InvalidInput("degenerate obstacle area")
    }
    if area < 0.0 {
      points.rev_in_place()
    }
  }
  for existing in self.obstacles {
    if existing is Some(other) {
      for i in 0..<n {
        for j in 0..<other.length() {
          if segments_touch(
              points[i],
              points[(i + 1) % n],
              other[j],
              other[(j + 1) % other.length()],
            ) {
            raise InvalidInput("separate obstacles must not touch or intersect")
          }
        }
      }
      if point_inside(points[0], other) || point_inside(other[0], points) {
        raise InvalidInput("separate solid obstacles must not overlap or nest")
      }
    }
  }
  let id = self.obstacles.length()
  self.obstacles.push(Some(points))
  id
}

///|
pub fn Simulator::remove_obstacle(
  self : Simulator,
  id : Int32,
) -> Unit raise CrowdError {
  if id < 0 || id >= self.obstacles.length() {
    raise UnknownObstacle(id)
  }
  if self.obstacles[id] is None {
    raise UnknownObstacle(id)
  }
  self.obstacles[id] = None
}

///|
fn Simulator::nearby_edges(self : Simulator, agent : AgentState) -> Array[Edge] {
  let found : Array[(Double, Int32, Int32, Edge)] = []
  let range = agent.config.obstacle_horizon * agent.config.max_speed +
    agent.config.radius
  for oid, slot in self.obstacles {
    if slot is Some(p) {
      let n = p.length()
      for i in 0..<n {
        let a = p[i]
        let b = p[(i + 1) % n]
        let distance = segment_distance_sq(agent.position, a, b)
        if left_of(a, b, agent.position) < 0.0 && distance < range * range {
          let prev = p[(i + n - 1) % n]
          let next = p[(i + 2) % n]
          found.push(
            (
              distance,
              oid,
              i,
              {
                a,
                b,
                direction: unit(b - a),
                previous_direction: unit(a - prev),
                next_direction: unit(next - b),
                convex_a: n == 2 || left_of(prev, a, b) >= 0.0,
                convex_b: n == 2 || left_of(a, b, next) >= 0.0,
              },
            ),
          )
        }
      }
    }
  }
  found.sort_by(fn(a, b) {
    if a.0 < b.0 {
      -1
    } else if a.0 > b.0 {
      1
    } else if a.1 != b.1 {
      a.1.compare(b.1)
    } else {
      a.2.compare(b.2)
    }
  })
  found.map(item => item.3)
}

///|
/// All solves read one old-state snapshot; all updates commit together.
/// Finite, speed-bounded fallback can still violate ORCA lines: inspect report.
pub fn Simulator::step(self : Simulator) -> StepReport raise CrowdError {
  if self.tick >= 2000000000 {
    raise InvalidInput("step counter limit reached")
  }
  let active = self.states()
  let tree = build_tree(active.copy(), 0)
  let next : Array[AgentState] = []
  let diagnostics : Array[AgentDiagnostics] = []
  let mut fallbacks = 0
  let mut violations = 0
  let mut candidates = 0
  for agent in active {
    let found = neighbors(tree, agent)
    candidates += found.length()
    let count = found.length().min(agent.config.max_neighbors)
    let lines = obstacle_lines(agent, self.nearby_edges(agent))
    let obstacle_count = lines.length()
    let mut overlaps = 0
    for i in 0..<count {
      let other = found[i].1
      let sum_radius = agent.config.radius + other.config.radius
      if found[i].0 < sum_radius * sum_radius {
        overlaps += 1
      }
      lines.push(agent_line(agent, other, self.dt))
    }
    let (failed, result) = lp2(
      lines,
      agent.config.max_speed,
      agent.preferred_velocity,
      false,
    )
    let used_fallback = failed < lines.length()
    let velocity = if used_fallback {
      lp3(lines, obstacle_count, failed, agent.config.max_speed, result)
    } else {
      result
    }
    let position = agent.position + velocity.scale(self.dt)
    if !velocity.is_finite() ||
      !position.is_finite() ||
      velocity.length() > agent.config.max_speed + 1.0e-7 ||
      position.x.abs() > 1.0e6 ||
      position.y.abs() > 1.0e6 {
      raise NumericalFailure(
        "step rejected before commit: result outside numeric contract",
      )
    }
    let mut max_violation = 0.0
    for line in lines {
      max_violation = max_violation.max(
        det(line.direction, line.point - velocity),
      )
    }
    if used_fallback {
      fallbacks += 1
    }
    if max_violation > 1.0e-7 {
      violations += 1
    }
    diagnostics.push({
      id: agent.id,
      neighbors: count,
      neighbors_truncated: found.length() > count,
      obstacle_constraints: obstacle_count,
      constraints: lines,
      used_fallback,
      max_violation,
      overlapping_neighbors: overlaps,
    })
    next.push({ ..agent, velocity, position, })
  }
  for state in next {
    self.agents[state.id] = Some(state)
  }
  self.tick += 1
  {
    step: self.tick,
    time: self.time(),
    agents: diagnostics,
    fallback_agents: fallbacks,
    violating_agents: violations,
    neighbor_candidates: candidates,
  }
}

///|
pub fn Simulator::snapshot(self : Simulator) -> Snapshot {
  {
    dt: self.dt,
    tick: self.tick,
    agents: self.agents.copy(),
    obstacles: self.obstacles.map(p => p.map(v => v.copy())),
  }
}

///|
pub fn Snapshot::restore(self : Snapshot) -> Simulator {
  {
    dt: self.dt,
    tick: self.tick,
    agents: self.agents.copy(),
    obstacles: self.obstacles.map(p => p.map(v => v.copy())),
  }
}
