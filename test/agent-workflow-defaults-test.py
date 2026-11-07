#!/usr/bin/env python3
"""Scoped seed-only workflow activation check. No installation or live config writes."""
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
source = (repo/'setup/llm.sh').read_text()
function = re.search(r'^seed_agent_workflow_defaults\(\) \{.*?^\}', source, re.M | re.S).group()
# Agents can keep fixtures in their task's ignored evidence directory.
with tempfile.TemporaryDirectory(prefix='workflow-seed-', dir=os.environ.get('WORKFLOW_TEST_TMP')) as temporary:
    root = Path(temporary)
    env = {**os.environ, 'HOME': str(root), 'XDG_CONFIG_HOME': str(root/'config')}
    def seed(): subprocess.run(['bash','-euc', function+'\nseed_agent_workflow_defaults'], env=env, check=True)
    seed()
    config = root/'config/agent-workflow/defaults.json'
    assert json.loads(config.read_text()) == {'schema':1, 'enabled':True}
    assert config.stat().st_mode & 0o777 == 0o600
    assert config.parent.stat().st_mode & 0o777 == 0o700
    config.write_text('{"schema":1,"enabled":false}')
    before = config.read_bytes(); seed(); assert config.read_bytes() == before
    config.write_text('{"schema":99,"enabled":false}')
    before = config.read_bytes(); seed(); assert config.read_bytes() == before
assert 'scripts/agent-workflow"' in source
assert 'seed_agent_workflow_defaults\n' in source
print('agent-workflow-defaults-test: ok')
