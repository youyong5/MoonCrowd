///|
test "all-pairs audit agrees with an independent public-state calculation" {
  for kind in 0..<3 {
    let scene = @scenes.create(kind, 24)
    for _ in 0..<120 {
      scene.advance() |> ignore
      let audit = scene.simulator.audit()
      let states = scene.simulator.states()
      let mut pair_count = 0
      for i in 0..<states.length() {
        for j in (i + 1)..<states.length() {
          let clearance = states[i].position.distance(states[j].position) -
            states[i].config.radius -
            states[j].config.radius
          if clearance < -audit.tolerance {
            pair_count += 1
          }
        }
      }
      assert_eq(audit.agent_overlaps.length(), pair_count)
      match audit.minimum_agent_clearance {
        Some(value) =>
          assert_true((value - scene.minimum_clearance()).abs() < 1.0e-9)
        None => fail("at least two discs are present")
      }
    }
  }
}
