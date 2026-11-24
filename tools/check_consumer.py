#!/usr/bin/env python3
"""Build and test a separate module against the public API via moon.work."""
from pathlib import Path
import subprocess
import tempfile
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='mooncrowd-consumer-') as directory:
    work=Path(directory)
    app=work/'consumer'
    app.mkdir()
    # The module path is a literal from Path, serialized as a language string.
    import json
    (work/'moon.work').write_text('members = ['+json.dumps(str(ROOT))+', "consumer"]\n')
    (app/'moon.mod').write_text('name = "consumer/mooncrowd_smoke"\nimport { "youyong5/mooncrowd@0.1.0" }\n')
    (app/'moon.pkg').write_text('import { "youyong5/mooncrowd" @crowd }\n')
    (app/'consumer.mbt').write_text('''pub fn exercise() -> Bool raise @crowd.CrowdError {
  let sim = @crowd.Simulator::new()
  let id = sim.add_agent(@crowd.Vec2::new(-2.0, 0.0))
  sim.steer_toward(id, @crowd.Vec2::new(2.0, 0.0))
  let checkpoint = sim.snapshot()
  let report = sim.step()
  report.step == 1 && sim.agent(id).position.x > -2.0 && checkpoint.restore().step_count() == 0
}
''')
    (app/'consumer_wbtest.mbt').write_text('test "independent public API consumer" { assert_true(exercise()) }\n')
    subprocess.run(['moon','test','.','--target','all','--deny-warn'],cwd=app,check=True)
print('Independent consumer: four backends passed')
