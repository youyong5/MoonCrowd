#!/usr/bin/env python3
"""Build the real MoonBit JS example; web/app.js contains no avoidance solver."""
from pathlib import Path
import shutil
import subprocess
ROOT=Path(__file__).resolve().parents[1]
subprocess.run(['moon','build','examples/browser','--target','js','--release','--deny-warn'],cwd=ROOT,check=True)
artifact=ROOT/'_build/js/release/build/examples/browser/browser.js'
if not artifact.is_file():
    raise SystemExit(f'Missing expected build artifact: {artifact}')
header='/* MoonCrowd: Copyright 2026 contributors. ORCA/LP adapted from RVO2, Copyright 2008 University of North Carolina at Chapel Hill. SPDX-License-Identifier: Apache-2.0. See NOTICE.txt and LICENSE.txt. */\n'
(ROOT/'web/mooncrowd.js').write_text(header+artifact.read_text())
shutil.copy2(ROOT/'NOTICE',ROOT/'web/NOTICE.txt')
shutil.copy2(ROOT/'LICENSE',ROOT/'web/LICENSE.txt')
print('Ready: web/index.html (static, no Node packages or server APIs)')
