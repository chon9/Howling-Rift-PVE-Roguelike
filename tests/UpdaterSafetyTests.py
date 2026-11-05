"""Exercise the real Windows updater in isolated workspace fixtures."""
import hashlib, json, subprocess, tempfile, zipfile
from pathlib import Path
root=Path(__file__).resolve().parents[1]
helper=root/'assets/updater/UpdateGame.ps1'
required=['Howling Rift.exe','Howling Rift.pck','libgodotsteam.windows.template_release.x86_64.dll','steam_api64.dll','steam_appid.txt']
checks=0
with tempfile.TemporaryDirectory(prefix='updater-test-',dir=root/'.godot') as tmp:
 test=Path(tmp).resolve()
 assert test.is_relative_to((root/'.godot').resolve())
 def check(ok,message):
  global checks
  checks+=1
  assert ok,message
 def run(mode,cache,*args):
  p=subprocess.run(['powershell.exe','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',str(helper),'-Mode',mode,'-Cache',str(cache),'-Version','0.4.4',*map(str,args)],capture_output=True,text=True,timeout=30)
  if p.returncode and mode=="Verify" and cache.name=="valid":print(p.stdout,p.stderr,(cache/"state-0.4.4.json").read_text())
  return p.returncode
 def make(name,entries):
  archive=test/(name+'.zip')
  with zipfile.ZipFile(archive,'w') as z:
   for n,v in entries:z.writestr(n,v)
  return archive,hashlib.sha256(archive.read_bytes()).hexdigest()
 normal=[('Spacewar-v0.4.4/'+n,b'new '+n.encode()) for n in required]
 archive,sha=make('valid',normal)
 cache=test/'valid'
 check(run('Verify',cache,'-ZipPath',archive,'-ExpectedHash',sha)==0,'valid package must stage')
 check(json.loads((cache/'state-0.4.4.json').read_text())['phase']=='ready','verified package becomes ready')
 check(run('Verify',test/'wrong-hash','-ZipPath',archive,'-ExpectedHash','0'*64)!=0,'wrong SHA must reject')
 for label,entries in [('traversal',normal+[('Spacewar-v0.4.4/../escaped.exe',b'bad')]),('foreign-root',normal+[('Other/file.md',b'bad')]),('unknown-exe',normal+[('Spacewar-v0.4.4/evil.exe',b'bad')]),('missing',normal[:-1]),('duplicate',normal+[normal[0]])]:
  bad,bad_sha=make(label,entries)
  check(run('Verify',test/label,'-ZipPath',bad,'-ExpectedHash',bad_sha)!=0,label+' package must reject')
 check(not (test/'escaped.exe').exists(),'traversal creates no external file')
 game=test/'game';game.mkdir()
 for name in required:(game/name).write_bytes(b'old '+name.encode())
 (game/'progression.cfg').write_text('preserve-player-save')
 check(run('Install',cache,'-GameDir',game,'-NoLaunch')==0,'verified staged update must install')
 check(all((game/n).read_bytes()==b'new '+n.encode() for n in required),'all game files updated together')
 check((game/'progression.cfg').read_text()=='preserve-player-save','unrelated files and saves untouched')
 check(any(p.name.startswith('backup-') for p in cache.iterdir()),'old installation backup retained')
 (cache/'stage-0.4.4/Howling Rift.exe').write_bytes(b'tampered')
 before=(game/'Howling Rift.exe').read_bytes()
 check(run('Install',cache,'-GameDir',game,'-NoLaunch')!=0,'staging tampering must reject')
 check((game/'Howling Rift.exe').read_bytes()==before,'failed verification preserves installed game')
 check(run('Download',test/'foreign-download','-ZipUrl','https://evil.example/x.zip','-ChecksumUrl','https://evil.example/x.sha256')!=0,'untrusted download URL rejected before network access')
print('UPDATER SAFETY:',checks,'checks, 0 failures')
