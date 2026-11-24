///|
test "48-disc circle exchange stays separated and reaches all goals" {
  let scene = @scenes.create(0, 48)
  for _ in 0..<400 {
    let report = scene.advance()
    assert_eq(report.violating_agents, 0)
    assert_true(scene.minimum_clearance() >= -1.0e-7)
  }
  assert_eq(scene.arrived(), 48)
}
