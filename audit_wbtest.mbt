///|
test "audit observes overlaps even when pair avoidance is disabled" {
  let sim = Simulator::new()
  let config = AgentConfig::{ ..AgentConfig::default(), max_neighbors: 0, }
  let a = sim.add_agent(Vec2::zero(), config~)
  let b = sim.add_agent(Vec2::new(0.1, 0.0), config~)
  let report = sim.step()
  assert_eq(report.violating_agents, 0)
  let audit = sim.audit()
  assert_true(!audit.is_clear())
  assert_eq(audit.agent_overlaps.length(), 1)
  assert_eq(audit.agent_overlaps[0].first, a)
  assert_eq(audit.agent_overlaps[0].second, b)
  near(audit.agent_overlaps[0].clearance, -0.5)
  assert_eq(audit.minimum_agent_clearance, Some(-0.5))
  assert_eq(audit.step, 1)
}

///|
test "audit distinguishes absence of pairs from zero clearance" {
  let sim = Simulator::new()
  let empty = sim.audit()
  assert_true(empty.is_clear())
  assert_eq(empty.minimum_agent_clearance, None)
  assert_eq(empty.minimum_obstacle_clearance, None)
  sim.add_agent(Vec2::zero()) |> ignore
  assert_eq(sim.audit().minimum_agent_clearance, None)
  sim.add_agent(Vec2::new(0.6, 0.0)) |> ignore
  assert_true(sim.audit(tolerance=0.0).is_clear())
  assert_eq(sim.audit().minimum_agent_clearance, Some(0.0))
}

///|
test "audit checks wall proximity and ignores deleted obstacle handles" {
  let sim = Simulator::new()
  let wall = sim.add_obstacle([Vec2::new(0.0, -2.0), Vec2::new(0.0, 2.0)])
  let agent = sim.add_agent(Vec2::new(0.1, 0.0))
  let report = sim.audit()
  assert_eq(report.obstacle_overlaps.length(), 1)
  let overlap = report.obstacle_overlaps[0]
  assert_eq(overlap.agent, agent)
  assert_eq(overlap.obstacle, wall)
  assert_true(!overlap.center_inside)
  near(overlap.clearance, -0.2)
  sim.remove_obstacle(wall)
  assert_true(sim.audit().is_clear())
  assert_eq(sim.audit().minimum_obstacle_clearance, None)
}

///|
test "solid polygon audit catches a disc center strictly inside" {
  let sim = Simulator::new()
  sim.add_obstacle([
    Vec2::new(-1.0, -1.0),
    Vec2::new(1.0, -1.0),
    Vec2::new(1.0, 1.0),
    Vec2::new(-1.0, 1.0),
  ])
  |> ignore
  sim.add_agent(Vec2::zero()) |> ignore
  let report = sim.audit()
  assert_true(report.obstacle_overlaps[0].center_inside)
  near(report.obstacle_overlaps[0].clearance, -1.3)
}

///|
test "audit respects concave cutout and corner distances" {
  let sim = Simulator::new()
  sim.add_obstacle([
    Vec2::new(-1.0, -1.0),
    Vec2::new(1.0, -1.0),
    Vec2::new(1.0, 0.0),
    Vec2::new(0.0, 0.0),
    Vec2::new(0.0, 1.0),
    Vec2::new(-1.0, 1.0),
  ])
  |> ignore
  sim.add_agent(Vec2::new(0.5, 0.5)) |> ignore
  let report = sim.audit()
  assert_true(report.is_clear())
  assert_eq(report.minimum_obstacle_clearance, Some(0.2))
}

///|
test "audit tolerance filters counts without changing raw clearances" {
  let sim = Simulator::new()
  sim.add_agent(Vec2::zero()) |> ignore
  sim.add_agent(Vec2::new(0.599, 0.0)) |> ignore
  assert_true(!sim.audit(tolerance=0.0).is_clear())
  let tolerant = sim.audit(tolerance=0.01)
  assert_true(tolerant.is_clear())
  match tolerant.minimum_agent_clearance {
    Some(value) => near(value, -0.001)
    None => fail("missing clearance")
  }
  for value in [-1.0, 0.0 / 0.0, 1.0 / 0.0] {
    let invalid = try {
      sim.audit(tolerance=value) |> ignore
      false
    } catch {
      InvalidInput(_) => true
      _ => false
    }
    assert_true(invalid)
  }
}

///|
test "audit remains observational and IDs survive holes" {
  let sim = Simulator::new()
  let deleted = sim.add_agent(Vec2::new(5.0, 5.0))
  sim.remove_agent(deleted)
  sim.add_agent(Vec2::zero()) |> ignore
  sim.add_agent(Vec2::new(0.1, 0.0)) |> ignore
  let before = sim.states()
  let report = sim.audit()
  assert_eq(report.agent_overlaps[0].first, 1)
  assert_eq(report.agent_overlaps[0].second, 2)
  report.agent_overlaps.clear()
  assert_eq(sim.audit().agent_overlaps.length(), 1)
  assert_eq(sim.states(), before)
  assert_eq(sim.step_count(), 0)
}

///|
test "bounded audit details retain exact totals including count-only mode" {
  let sim = Simulator::new()
  for _ in 0..<10 {
    sim.add_agent(Vec2::zero()) |> ignore
  }
  let report = sim.audit(max_details=3)
  assert_eq(report.agent_overlap_count, 45)
  assert_eq(report.agent_overlaps.length(), 3)
  assert_true(report.details_truncated)
  let count_only = sim.audit(max_details=0)
  assert_eq(count_only.agent_overlap_count, 45)
  assert_true(count_only.agent_overlaps.is_empty())
  assert_true(!count_only.is_clear())
  for value in [-1, 1000001] {
    let bad = try {
      sim.audit(max_details=value) |> ignore
      false
    } catch {
      InvalidInput(_) => true
      _ => false
    }
    assert_true(bad)
  }
}
