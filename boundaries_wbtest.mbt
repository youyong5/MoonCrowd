///|
test "prediction windows cannot be shorter than the fixed step" {
  let sim = Simulator::new(time_step=0.1)
  let bad = AgentConfig::{ ..AgentConfig::default(), time_horizon: 0.01, }
  let rejected = try {
    sim.add_agent(Vec2::zero(), config=bad) |> ignore
    false
  } catch {
    InvalidInput(_) => true
    _ => false
  }
  assert_true(rejected)
  assert_true(sim.states().is_empty())
}

///|
test "non-finite numbers are rejected atomically" {
  let sim = Simulator::new()
  let id = sim.add_agent(Vec2::zero())
  let before = sim.states()
  let nan = 0.0 / 0.0
  let infinity = 1.0 / 0.0
  for value in [nan, infinity, -infinity] {
    let rejected = try {
      sim.set_state(id, Vec2::new(value, 0.0), Vec2::zero())
      false
    } catch {
      InvalidInput(_) => true
      _ => false
    }
    assert_true(rejected)
    let bad = AgentConfig::{ ..AgentConfig::default(), radius: value, }
    let bad_config = try {
      sim.add_agent(Vec2::zero(), config=bad) |> ignore
      false
    } catch {
      InvalidInput(_) => true
      _ => false
    }
    assert_true(bad_config)
  }
  assert_eq(sim.states(), before)
}

///|
test "empty worlds advance and neighbor disabling is explicit" {
  let sim = Simulator::new()
  assert_eq(sim.step().agents.length(), 0)
  let config = AgentConfig::{ ..AgentConfig::default(), max_neighbors: 0, }
  sim.add_agent(Vec2::zero(), config~) |> ignore
  sim.add_agent(Vec2::new(0.1, 0.0), config~) |> ignore
  let report = sim.step()
  assert_eq(report.neighbor_candidates, 0)
  assert_eq(report.agents[0].neighbors, 0)
  assert_true(!report.agents[0].neighbors_truncated)
}

///|
test "LP projects onto intersecting half-planes within speed circle" {
  let lines = [
    Constraint::{
      point: Vec2::new(1.0, 0.0),
      direction: Vec2::new(0.0, -1.0),
      obstacle: false,
    },
    Constraint::{
      point: Vec2::new(0.0, 0.5),
      direction: Vec2::new(1.0, 0.0),
      obstacle: false,
    },
  ]
  let (fail, result) = lp2(lines, 2.0, Vec2::zero(), false)
  assert_eq(fail, 2)
  near(result.x, 1.0)
  near(result.y, 0.5)
}

///|
test "LP reports incompatible parallel lines" {
  let lines = [
    Constraint::{
      point: Vec2::new(1.0, 0.0),
      direction: Vec2::new(0.0, -1.0),
      obstacle: false,
    },
    Constraint::{
      point: Vec2::zero(),
      direction: Vec2::new(0.0, 1.0),
      obstacle: false,
    },
  ]
  let (fail, result) = lp2(lines, 2.0, Vec2::zero(), false)
  assert_eq(fail, 1)
  let recovered = lp3(lines, 0, fail, 2.0, result)
  assert_true(recovered.is_finite())
  assert_true(
    lines.any(line => det(line.direction, line.point - recovered) > 0.0),
  )
}

///|
test "returned diagnostics are independent from the next simulation state" {
  let sim = Simulator::new()
  sim.add_agent(Vec2::new(-1.0, 0.0)) |> ignore
  sim.add_agent(Vec2::new(1.0, 0.0)) |> ignore
  let report = sim.step()
  let fork = sim.snapshot().restore()
  report.agents[0].constraints.clear()
  report.agents.clear()
  assert_eq(sim.step(), fork.step())
}
