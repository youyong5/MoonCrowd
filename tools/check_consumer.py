#!/usr/bin/env python3
"""Verify external API consumption from a workspace, packaged ZIP, or registry.

The registry mode uses an exact version without a moon.work source override.
It must only be reported as passing after an actual successful registry run.
"""
import argparse
import json
from pathlib import Path
import re
import subprocess
import tempfile
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]

CONSUMER = '''test "public movement diagnostics and independent checkpoint" {
  let sim = create_world()
  let id = sim.add_agent(@crowd.Vec2::new(-2.0, 0.0))
  sim.set_config(id, { ..@crowd.AgentConfig::default(), radius: 0.25 })
  sim.set_preferred_velocities([(id, @crowd.Vec2::new(1.0, 0.0))])
  let checkpoint = sim.snapshot()
  let report = sim.step()
  assert_eq(report.step, 1)
  assert_true(sim.agent(id).position.x > -2.0)
  assert_true(sim.audit().is_clear())
  let restored = checkpoint.restore()
  assert_eq(restored.step_count(), 0)
  restored.step() |> ignore
  assert_eq(restored.states(), sim.states())
}

test "public batch rejection does not partially update preferences" {
  let sim = create_world()
  let id = sim.add_agent(@crowd.Vec2::zero())
  let before = sim.states()
  let rejected = try {
    sim.set_preferred_velocities([
      (id, @crowd.Vec2::new(1.0, 0.0)),
      (id, @crowd.Vec2::new(0.0, 1.0)),
    ])
    false
  } catch { @crowd.CrowdError::InvalidInput(_) => true; _ => false }
  assert_true(rejected)
  assert_eq(sim.states(), before)
}

test "public audit sees overlaps with avoidance disabled and no details" {
  let sim = create_world()
  let config = @crowd.AgentConfig::{ ..@crowd.AgentConfig::default(), max_neighbors: 0 }
  sim.add_agent(@crowd.Vec2::zero(), config~) |> ignore
  sim.add_agent(@crowd.Vec2::new(0.1, 0.0), config~) |> ignore
  let audit = sim.audit(max_details=0)
  assert_eq(audit.agent_overlap_count, 1)
  assert_eq(audit.agent_overlaps.length(), 0)
  assert_true(audit.details_truncated)
  assert_true(!audit.is_clear())
}
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', choices=['workspace', 'package', 'registry'], default='workspace')
    parser.add_argument('--version', help='Exact registry version; defaults to moon.mod version')
    args = parser.parse_args()
    manifest = (ROOT / 'moon.mod').read_text(encoding='utf-8')
    name = re.search(r'^name\s*=\s*"([^"]+)"', manifest, re.M).group(1)
    version = args.version or re.search(r'^version\s*=\s*"([^"]+)"', manifest, re.M).group(1)
    if not re.fullmatch(r'\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?', version):
        parser.error('version must be an exact semantic version')
    if args.version and args.source != 'registry':
        parser.error('--version is only valid with --source registry')
    with tempfile.TemporaryDirectory(prefix='mooncrowd-consumer-') as directory:
        work = Path(directory)
        app = work / 'consumer'
        app.mkdir()
        source = ROOT
        if args.source == 'package':
            subprocess.run(['moon', 'package'], cwd=ROOT, check=True)
            archive = ROOT / '_build/publish' / (name.replace('/', '-') + '-' + version + '.zip')
            source = work / 'packaged'
            source.mkdir()
            with ZipFile(archive) as packaged:
                for entry in packaged.infolist():
                    target = (source / entry.filename).resolve()
                    if source not in target.parents or entry.external_attr >> 16 & 0o170000 == 0o120000:
                        raise SystemExit('Unsafe packaged ZIP entry: ' + entry.filename)
                packaged.extractall(source)
            if not (source / 'moon.mod').is_file():
                raise SystemExit('Packaged archive has no root moon.mod')
        if args.source != 'registry':
            (work / 'moon.work').write_text('members = [' + json.dumps(str(source)) + ', "consumer"]\n', encoding='utf-8')
        (app / 'moon.mod').write_text('name = "consumer/mooncrowd_smoke"\nimport { ' + json.dumps(name + '@' + version) + ' }\n', encoding='utf-8')
        (app / 'moon.pkg').write_text('import { ' + json.dumps(name) + ' @crowd }\n', encoding='utf-8')
        (app / 'consumer.mbt').write_text('pub fn create_world() -> @crowd.Simulator raise @crowd.CrowdError { @crowd.Simulator::new() }\n', encoding='utf-8')
        (app / 'consumer_wbtest.mbt').write_text(CONSUMER, encoding='utf-8')
        if args.source == 'registry':
            subprocess.run(['moon', 'update'], cwd=app, check=True)
        subprocess.run(['moon', 'fmt'], cwd=app, check=True)
        subprocess.run(['moon', 'test', '.', '--target', 'all', '--deny-warn'], cwd=app, check=True)
    print(f'Independent consumer ({args.source}, {name}@{version}): 3 public API tests on each of four backends passed')


if __name__ == '__main__':
    main()
