// Copyright 2026 MoonCrowd contributors. SPDX-License-Identifier: Apache-2.0
// Browser FFI lives only in this example. Every simulation step is MoonBit.

///|
extern "js" fn install(
  reset : (Int32, Int32) -> String,
  step : () -> String,
) -> Unit =
  #| (reset, step) => { globalThis.MoonCrowd = { reset, step }; }

///|
fn encode(
  scene : @scenes.Scene,
  violations : Int32,
  fallbacks : Int32,
  diagnostics~ : String = "[]",
) -> String {
  let states = scene.simulator.states()
  let agents = states
    .map(a => {
      "[\{a.id},\{a.position.x},\{a.position.y},\{a.velocity.x},\{a.velocity.y},\{a.config.radius}]"
    })
    .join(",")
  "{\"step\":\{scene.simulator.step_count()},\"time\":\{scene.simulator.time()},\"arrived\":\{scene.arrived()},\"violations\":\{violations},\"fallbacks\":\{fallbacks},\"agents\":[\{agents}],\"diagnostics\":\{diagnostics}}"
}

///|
fn main {
  let scene : Ref[@scenes.Scene?] = Ref(None)
  install(
    fn(kind, count) {
      try {
        let created = @scenes.create(kind, count)
        scene.val = Some(created)
        encode(created, 0, 0)
      } catch {
        err => "{\"error\":\"\{err.message()}\"}"
      }
    },
    fn() {
      match scene.val {
        None => "{\"error\":\"reset first\"}"
        Some(current) =>
          try {
            let report = current.advance()
            let meta = report.agents
              .map(a => {
                "[\{a.id},\{a.neighbors},\{a.neighbors_truncated},\{a.used_fallback},\{a.max_violation}]"
              })
              .join(",")
            encode(
              current,
              report.violating_agents,
              report.fallback_agents,
              diagnostics="[\{meta}]",
            )
          } catch {
            err => "{\"error\":\"\{err.message()}\"}"
          }
      }
    },
  )
}
