///|
test "example scenarios call the public API and retain finite speed-bounded states" {
  for kind in 0..<3 {
    let scene = @scenes.create(kind, 32)
    for _ in 0..<100 {
      let report = scene.advance()
      for a in scene.simulator.states() {
        assert_true(a.position.is_finite() && a.velocity.is_finite())
        assert_true(a.velocity.length() <= a.config.max_speed + 1.0e-7)
      }
      // Dense reciprocal traffic can be infeasible. Check the advertised
      // diagnostic definition directly against every returned constraint.
      for d in report.agents {
        let velocity = scene.simulator.agent(d.id).velocity
        let mut violation = 0.0
        for line in d.constraints {
          let delta = line.point - velocity
          violation = violation.max(
            line.direction.x * delta.y - line.direction.y * delta.x,
          )
        }
        assert_true((violation - d.max_violation).abs() < 1.0e-9)
      }
    }
  }
}
