///|
test "host preference batch commits all validated states" {
  let sim = Simulator::new()
  let a = sim.add_agent(Vec2::new(-2.0, 0.0))
  let b = sim.add_agent(Vec2::new(2.0, 0.0))
  let before = sim.snapshot()
  sim.set_preferred_velocities([
    (a, Vec2::new(1.0, 0.0)),
    (b, Vec2::new(-1.0, 0.0)),
  ])
  assert_eq(sim.agent(a).preferred_velocity, Vec2::new(1.0, 0.0))
  assert_eq(sim.agent(b).preferred_velocity, Vec2::new(-1.0, 0.0))
  assert_eq(before.restore().agent(a).preferred_velocity, Vec2::zero())
  let states = sim.states()
  sim.set_preferred_velocities([])
  assert_eq(sim.states(), states)
}

///|
test "invalid late batch handle does not leave early updates applied" {
  let sim = Simulator::new()
  let id = sim.add_agent(Vec2::zero())
  let before = sim.states()
  let rejected = try {
    sim.set_preferred_velocities([(id, Vec2::new(1.0, 0.0)), (99, Vec2::zero())])
    false
  } catch {
    UnknownAgent(_) => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(sim.states(), before)
}

///|
test "duplicate and non-finite batch preferences are rejected atomically" {
  let sim = Simulator::new()
  let a = sim.add_agent(Vec2::zero())
  let b = sim.add_agent(Vec2::new(1.0, 0.0))
  let before = sim.states()
  let duplicate = try {
    sim.set_preferred_velocities([(a, Vec2::new(1.0, 0.0)), (a, Vec2::zero())])
    false
  } catch {
    InvalidInput(_) => true
    _ => false
  }
  assert_true(duplicate)
  let invalid = try {
    sim.set_preferred_velocities([
      (a, Vec2::new(1.0, 0.0)),
      (b, Vec2::new(0.0 / 0.0, 0.0)),
    ])
    false
  } catch {
    InvalidInput(_) => true
    _ => false
  }
  assert_true(invalid)
  assert_eq(sim.states(), before)
}

///|
test "configuration changes preserve state and are included in checkpoints" {
  let sim = Simulator::new()
  let a = sim.add_agent(Vec2::zero())
  let old = sim.snapshot()
  let updated = AgentConfig::{
    ..AgentConfig::default(),
    radius: 0.5,
    max_speed: 2.0,
    max_neighbors: 8,
  }
  sim.set_config(a, updated)
  assert_eq(sim.agent(a).config, updated)
  assert_eq(old.restore().agent(a).config, AgentConfig::default())
  assert_eq(sim.snapshot().restore().agent(a), sim.agent(a))
}

///|
test "lowering speed below current motion requires explicit state intervention" {
  let sim = Simulator::new()
  let id = sim.add_agent(Vec2::zero(), velocity=Vec2::new(1.0, 0.0))
  let stopped = AgentConfig::{ ..AgentConfig::default(), max_speed: 0.0, }
  let before = sim.agent(id)
  let rejected = try {
    sim.set_config(id, stopped)
    false
  } catch {
    InvalidInput(_) => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(sim.agent(id), before)
  sim.set_state(id, before.position, Vec2::zero())
  sim.set_config(id, stopped)
  assert_eq(sim.agent(id).config.max_speed, 0.0)
}

///|
test "configuration updates enforce horizon and reject removed handles" {
  let sim = Simulator::new(time_step=0.1)
  let id = sim.add_agent(Vec2::zero())
  let before = sim.agent(id)
  let bad = AgentConfig::{ ..AgentConfig::default(), obstacle_horizon: 0.01, }
  let rejected = try {
    sim.set_config(id, bad)
    false
  } catch {
    InvalidInput(_) => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(sim.agent(id), before)
  sim.remove_agent(id)
  let stale = try {
    sim.set_preferred_velocities([(id, Vec2::zero())])
    false
  } catch {
    UnknownAgent(_) => true
    _ => false
  }
  assert_true(stale)
}
