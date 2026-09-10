"""Validate workflow YAML; requires PyYAML (pip install PyYAML)."""
from pathlib import Path
import yaml

root = Path(__file__).resolve().parent.parent
for path in sorted((root / '.github' / 'workflows').glob('*.yml')):
    # BaseLoader preserves GitHub's `on` key rather than YAML 1.1 booleans.
    workflow = yaml.load(path.read_text(encoding='utf-8'), Loader=yaml.BaseLoader)
    assert isinstance(workflow, dict), path
    assert 'on' in workflow and 'jobs' in workflow, path
    assert isinstance(workflow['jobs'], dict), path
    for job in workflow['jobs'].values():
        assert 'runs-on' in job and isinstance(job['steps'], list), path
        for step in job['steps']:
            assert ('uses' in step) != ('run' in step), (path, step)
    print(f'PASS: workflow YAML structure: {path.name}')
