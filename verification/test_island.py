import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess

ROOT = Path(__file__).resolve().parents[1]
PLUGIN = ROOT/'plugin'
MANIFEST = json.loads((ROOT/'verification/source_manifest.json').read_text())

def test_complete_source_and_license_preserved():
    rows = MANIFEST['files']
    assert len(rows) == 46
    assert {str(p.relative_to(PLUGIN)) for p in PLUGIN.rglob('*') if p.is_file()} == {r['path'] for r in rows}
    for row in rows:
        p = PLUGIN/row['path']
        assert hashlib.sha256(p.read_bytes()).hexdigest() == row['sha256']
        assert stat.S_IMODE(p.stat().st_mode) == row['mode']
        src = Path(MANIFEST['source'])/row['path']
        assert src.read_bytes() == p.read_bytes()
        assert not src.samefile(p)
    assert (PLUGIN/'LICENSE').is_file()

def test_no_assistant_integrations():
    forbidden = re.compile(r'jarvis|AgentBridge|agent_hook|hermes|opencode|codex|ApprovalCard',re.I)
    for p in PLUGIN.rglob('*'):
        if p.is_file():
            assert not forbidden.search(p.read_text()), str(p)

def test_manifest_and_local_imports_complete():
    manifest = json.loads((PLUGIN/'manifest.json').read_text())
    assert manifest['id'] == 'omarchy-dynamic-island'
    assert (PLUGIN/manifest['entryPoints']['panel']).is_file()
    for p in PLUGIN.rglob('*.qml'):
        for name in re.findall(r'^import\s+"([^"]+)"',p.read_text(),re.M):
            assert (p.parent/name).exists(), (p,name)

def test_all_qml_parses_without_executing_plugin():
    paths = sorted(PLUGIN.rglob('*.qml'))
    assert len(paths) == 41
    errors=[]
    for p in paths:
        result=subprocess.run(['/usr/lib/qt6/bin/qmlformat','--ignore-settings',str(p)],
                              stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,text=True,timeout=15)
        if result.returncode: errors.append((str(p.relative_to(PLUGIN)),result.stderr))
    assert not errors, errors

def test_model_behaviors_without_desktop_services():
    source=(PLUGIN/'IslandModel.js').read_text().replace('.pragma library','',1)
    assertions=r'''
const assert = require('node:assert/strict');
assert.equal(parseDuration('1h30m'), 5400);
assert.equal(parseDuration('1:30'), 90);
assert.equal(parseDuration('25'), 1500);
assert.equal(parseDuration('invalid'), 0);
assert.deepEqual(activities({media:true, recording:true, timer:true}), ['recording','timer','media']);
assert.equal(viewFor({}), 'idle');
assert.equal(viewFor({userExpanded:true,inboxOpen:true}), 'inbox-expanded');
assert.equal(viewFor({userExpanded:true,recording:true,hasMedia:true}), 'recording-media-expanded');
assert.equal(viewFor({notification:true,notificationActions:true}), 'notification-actions');
assert.equal(viewFor({hud:{layout:'progress'},notification:true}), 'hud-progress');
assert.equal(isMicStream({isStream:true,isSink:false,name:'real-microphone'}), true);
assert.equal(isMicStream({isStream:true,isSink:false,name:'peak-monitor'}), false);
assert.deepEqual(parseConfig('invalid-json'), {});
assert.equal(entryFor({plugins:[{id:'omarchy-dynamic-island',style:'notch'}]},'omarchy-dynamic-island').style,'notch');
console.log('14 island model behavior assertions passed');
'''
    result=subprocess.run(['/usr/bin/node','-e',source+'\n'+assertions],capture_output=True,text=True,timeout=15)
    assert result.returncode == 0,result.stderr

def test_quick_controls_model_helpers():
    source = (PLUGIN / 'IslandModel.js').read_text().replace('.pragma library', '', 1)
    assertions = r'''
const assert = require('node:assert/strict');

// Test sizing for controls
const res = sizeFor("controls", {}, { w: 0, h: 0, r: 0 });
assert.equal(res.w, 440);
assert.equal(res.h, 380);
assert.equal(res.r, 34);

// Test call duration formatting
assert.equal(formatCallDuration(0), "00:00");
assert.equal(formatCallDuration(75), "01:15");
assert.equal(formatCallDuration(765), "12:45");
assert.equal(formatCallDuration(3665), "1:01:05");

// Test appearance themes
assert.equal(validAppearance("glass"), true);
assert.equal(validAppearance("black"), true);
assert.equal(validAppearance("graphite"), true);
assert.equal(validAppearance("theme"), true);
assert.equal(validAppearance("invalid"), false);

console.log('quick controls model helpers passed');
'''
    result = subprocess.run(['/usr/bin/node', '-e', source + '\n' + assertions], capture_output=True, text=True, timeout=15)
    assert result.returncode == 0, result.stderr

def test_existing_screen_recovery_regressions_offscreen(tmp_path):
    runtime=tmp_path/'runtime';runtime.mkdir(mode=0o700)
    env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',
             QT_QPA_PLATFORMTHEME='',QT_STYLE_OVERRIDE='Fusion',
             XDG_RUNTIME_DIR=str(runtime),XDG_CACHE_HOME=str(tmp_path/'cache'),
             XDG_CONFIG_HOME=str(tmp_path/'config'),XDG_DATA_HOME=str(tmp_path/'data'))
    result=subprocess.run(['/usr/lib/qt6/bin/qmltestrunner','-input',str(PLUGIN/'tests/tst_screen_recovery.qml')],
                          env=env,capture_output=True,text=True,timeout=25)
    (ROOT/'verification/screen_recovery.log').write_text(result.stdout+result.stderr)
    assert result.returncode == 0,result.stdout+result.stderr
