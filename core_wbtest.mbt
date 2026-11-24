///|
fn near(a : Double, b : Double, tolerance~ : Double = 1.0e-8) -> Unit raise {
  assert_true((a - b).abs() <= tolerance, msg="expected \{a} near \{b}")
}

///|
test "isolated disc follows preference and respects speed circle" {
  let sim = Simulator::new(time_step=0.1)
  let id = sim.add_agent(Vec2::zero())
  sim.set_preferred_velocity(id, Vec2::new(3.0, 4.0))
  let report = sim.step()
  let state = sim.agent(id)
  near(state.velocity.length(), 1.5)
  near(state.position.x, 0.09)
  near(state.position.y, 0.12)
  assert_eq(report.fallback_agents, 0)
}

///|
test "head on discs stay separated across 200 fixed steps" {
  let sim = Simulator::new()
  let a = sim.add_agent(Vec2::new(-3.0, 0.0))
  let b = sim.add_agent(Vec2::new(3.0, 0.0))
  for _ in 0..<200 {
    sim.set_preferred_velocity(a, Vec2::new(1.5, 0.0))
    sim.set_preferred_velocity(b, Vec2::new(-1.5, 0.0))
    let report = sim.step()
    assert_true(
      sim.agent(a).position.distance(sim.agent(b).position) >= 0.6 - 1.0e-7,
    )
    assert_eq(report.violating_agents, 0)
  }
}

///|
test "coincident agents recover finitely with stable ID symmetry" {
  let sim = Simulator::new()
  let a = sim.add_agent(Vec2::zero())
  let b = sim.add_agent(Vec2::zero())
  let report = sim.step()
  assert_true(report.fallback_agents > 0)
  assert_true(report.violating_agents > 0)
  assert_eq(report.agents[0].overlapping_neighbors, 1)
  let av = sim.agent(a).velocity
  let bv = sim.agent(b).velocity
  assert_true(av.is_finite() && bv.is_finite())
  near(av.x, -bv.x)
  assert_true(av.x < 0.0)
  for _ in 0..<20 {
    sim.step() |> ignore
  }
  assert_true(
    sim.agent(a).position.distance(sim.agent(b).position) >= 0.6 - 1.0e-7,
  )
}

///|
test "stable IDs reject removed handles" {
  let sim = Simulator::new()
  let a = sim.add_agent(Vec2::zero())
  sim.remove_agent(a)
  let b = sim.add_agent(Vec2::zero())
  assert_eq(b, a + 1)
  let rejected = try {
    sim.set_preferred_velocity(a, Vec2::zero())
    false
  } catch {
    UnknownAgent(_) => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(sim.states().length(), 1)
}

///|
test "input errors are atomic" {
  let sim = Simulator::new()
  let id = sim.add_agent(Vec2::zero())
  let before = sim.agent(id)
  let bad = AgentConfig::{ ..AgentConfig::default(), radius: -1.0, }
  let rejected = try {
    sim.add_agent(Vec2::zero(), config=bad) |> ignore
    false
  } catch {
    InvalidInput(_) => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(sim.agent(id), before)
  assert_eq(sim.states().length(), 1)
  assert_eq(sim.step_count(), 0)
  let bad_time = try {
    Simulator::new(time_step=0.0) |> ignore
    false
  } catch {
    InvalidInput(_) => true
    _ => false
  }
  assert_true(bad_time)
  let bad_vector = try {
    sim.set_preferred_velocity(id, Vec2::new(1.0e100, 0.0))
    false
  } catch {
    InvalidInput(_) => true
    _ => false
  }
  assert_true(bad_vector)
  assert_eq(sim.agent(id), before)
}

///|
test "checkpoint branches restore independent replay including holes and obstacles" {
  let sim = Simulator::new()
  let a = sim.add_agent(Vec2::new(-2.0, -1.0))
  let removed = sim.add_agent(Vec2::new(-2.0, 1.0))
  sim.remove_agent(removed)
  let wall = sim.add_obstacle([Vec2::new(0.0, -3.0), Vec2::new(0.0, 3.0)])
  sim.set_preferred_velocity(a, Vec2::new(1.0, 0.2))
  sim.step() |> ignore
  let checkpoint = sim.snapshot()
  let fork = checkpoint.restore()
  for _ in 0..<30 {
    assert_eq(sim.step(), fork.step())
  }
  assert_eq(sim.states(), fork.states())
  fork.remove_obstacle(wall)
  fork.remove_agent(a)
  assert_eq(sim.states().length(), 1)
  assert_eq(checkpoint.restore().step_count(), 1)
  let states = sim.states()
  states.clear()
  assert_eq(sim.states().length(), 1)
}

///|
test "two-sided wall prevents normal crossing from both sides" {
  let sim = Simulator::new()
  sim.add_obstacle([Vec2::new(0.0, -5.0), Vec2::new(0.0, 5.0)]) |> ignore
  let a = sim.add_agent(Vec2::new(-2.0, 0.0))
  let b = sim.add_agent(Vec2::new(2.0, 0.1))
  sim.set_preferred_velocity(a, Vec2::new(1.0, 0.0))
  sim.set_preferred_velocity(b, Vec2::new(-1.0, 0.0))
  for _ in 0..<150 {
    let report = sim.step()
    assert_true(sim.agent(a).position.x <= -0.3 + 1.0e-7)
    assert_true(sim.agent(b).position.x >= 0.3 - 1.0e-7)
    assert_true(report.agents[0].obstacle_constraints > 0)
  }
}

///|
test "clockwise and counterclockwise polygons behave identically" {
  let points = [
    Vec2::new(-1.0, -1.0),
    Vec2::new(1.0, -1.0),
    Vec2::new(1.0, 1.0),
    Vec2::new(-1.0, 1.0),
  ]
  let a = Simulator::new()
  let b = Simulator::new()
  a.add_obstacle(points) |> ignore
  b.add_obstacle(points.rev()) |> ignore
  let id = a.add_agent(Vec2::new(-3.0, 0.2))
  b.add_agent(Vec2::new(-3.0, 0.2)) |> ignore
  for _ in 0..<40 {
    a.set_preferred_velocity(id, Vec2::new(1.0, 0.0))
    b.set_preferred_velocity(id, Vec2::new(1.0, 0.0))
    a.step() |> ignore
    b.step() |> ignore
    near(a.agent(id).position.distance(b.agent(id).position), 0.0)
  }
  // Caller-owned polygon arrays are copied by add_obstacle.
  points.clear()
  assert_eq(a.states(), b.states())
}

///|
test "self-intersecting touching and degenerate obstacles are rejected" {
  let sim = Simulator::new()
  let bad = try {
    sim.add_obstacle([
      Vec2::zero(),
      Vec2::new(1.0, 1.0),
      Vec2::new(0.0, 1.0),
      Vec2::new(1.0, 0.0),
    ])
    |> ignore
    false
  } catch {
    InvalidInput(_) => true
    _ => false
  }
  assert_true(bad)
  assert_eq(sim.add_obstacle([Vec2::zero(), Vec2::new(1.0, 0.0)]), 0)
  let touching = try {
    sim.add_obstacle([Vec2::zero(), Vec2::new(0.0, 1.0)]) |> ignore
    false
  } catch {
    InvalidInput(_) => true
    _ => false
  }
  assert_true(touching)
  let short = try {
    sim.add_obstacle([Vec2::new(2.0, 0.0), Vec2::new(2.0, 0.0)]) |> ignore
    false
  } catch {
    InvalidInput(_) => true
    _ => false
  }
  assert_true(short)
  sim.remove_obstacle(0)
  assert_eq(sim.add_obstacle([Vec2::zero(), Vec2::new(0.0, 1.0)]), 1)
}

///|
test "neighbor caps and ties are observable and deterministic" {
  let sim = Simulator::new()
  let id = sim.add_agent(Vec2::zero(), config={
    ..AgentConfig::default(),
    max_neighbors: 1,
  })
  sim.add_agent(Vec2::new(-1.0, 0.0)) |> ignore
  sim.add_agent(Vec2::new(1.0, 0.0)) |> ignore
  let report = sim.step()
  assert_eq(report.agents[id].neighbors, 1)
  assert_true(report.agents[id].neighbors_truncated)
  assert_eq(report.neighbor_candidates, 6)
}

///|
test "arrival steering avoids target overshoot in isolation" {
  let sim = Simulator::new()
  let id = sim.add_agent(Vec2::zero())
  let goal = Vec2::new(0.04, 0.0)
  sim.steer_toward(id, goal, arrival_radius=0.0)
  sim.step() |> ignore
  near(sim.agent(id).position.x, 0.04)
  sim.steer_toward(id, goal, arrival_radius=0.0)
  sim.step() |> ignore
  near(sim.agent(id).velocity.length(), 0.0)
}

///|
test "bounding tree query matches brute force including equal distances" {
  let sim = Simulator::new()
  for i in 0..<50 {
    sim.add_agent(Vec2::new((i % 10).to_double(), (i / 10).to_double()), config={
      ..AgentConfig::default(),
      neighbor_distance: 2.5,
    })
    |> ignore
  }
  let active = sim.states()
  let tree = build_tree(active.copy(), 0)
  for agent in active {
    let actual = neighbors(tree, agent).map(x => x.1.id)
    let expected = active.filter(other => {
      agent.id != other.id &&
      (agent.position - other.position).length_squared() < 6.25
    })
    expected.sort_by(fn(a, b) {
      let da = (agent.position - a.position).length_squared()
      let db = (agent.position - b.position).length_squared()
      if da < db {
        -1
      } else if da > db {
        1
      } else {
        a.id.compare(b.id)
      }
    })
    assert_eq(actual, expected.map(a => a.id))
  }
}

///|
test "infeasible stationary discs report violations without hiding overlap" {
  let sim = Simulator::new()
  let config = AgentConfig::{ ..AgentConfig::default(), max_speed: 0.0, }
  sim.add_agent(Vec2::zero(), config~) |> ignore
  sim.add_agent(Vec2::new(0.1, 0.0), config~) |> ignore
  let report = sim.step()
  assert_eq(report.violating_agents, 2)
  assert_eq(report.fallback_agents, 2)
  for a in sim.states() {
    near(a.velocity.length(), 0.0)
  }
}

///|
test "numerical step rejection does not partially commit agents" {
  let sim = Simulator::new(time_step=1.0)
  let a = sim.add_agent(Vec2::zero())
  let b = sim.add_agent(Vec2::new(1.0e6, 0.0))
  sim.set_preferred_velocity(a, Vec2::new(1.0, 0.0))
  sim.set_preferred_velocity(b, Vec2::new(1.0, 0.0))
  let before = sim.states()
  let rejected = try {
    sim.step() |> ignore
    false
  } catch {
    NumericalFailure(_) => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(sim.states(), before)
  assert_eq(sim.step_count(), 0)
}
