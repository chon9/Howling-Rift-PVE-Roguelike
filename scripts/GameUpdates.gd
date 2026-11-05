extends Node
signal changed
const REPO="chon9/Howling-Rift-PVE-Roguelike"
const LEGACY_REPO="chon9/Howling-Rift---PVE-Roguelike"
const API="https://api.github.com/repos/"+REPO+"/releases/latest"
const PAGE="https://github.com/"+REPO+"/releases/latest"
const CACHE="user://updates"
var current: String=str(ProjectSettings.get_setting("application/config/version","0.0.0"))
var latest=""
var status="Version check pending"
var phase="idle"
var release: Dictionary={}
var auto_download=true
var request: HTTPRequest
var worker_pid=0
var poll_time=0.
var checked=false
func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 var prefs=ConfigFile.new()
 if prefs.load("user://updates.cfg")==OK:auto_download=bool(prefs.get_value("updates","auto_download",true))
 request=HTTPRequest.new();request.use_threads=true;request.timeout=20.;request.body_size_limit=1024*1024
 add_child(request);request.request_completed.connect(_checked)
 if DisplayServer.get_name()=="headless" or OS.has_feature("editor"):
  status="Development build • v"+current
 elif OS.get_name()!="Windows":status="v"+current+" • manual updates"
 else:call_deferred("check_latest")
func set_auto_download(value: bool) -> void:
 auto_download=value
 var prefs=ConfigFile.new();prefs.set_value("updates","auto_download",value);prefs.save("user://updates.cfg")
 if value and phase=="available":download_update()
func check_latest() -> void:
 if phase in ["checking","downloading","installing"]:return
 phase="checking";status="v"+current+" • Checking GitHub…";changed.emit()
 var error=request.request(API,PackedStringArray(["Accept: application/vnd.github+json","User-Agent: Howling-Rift-Updater"]))
 if error!=OK:_error("Could not check updates. Retry when online.")
static func version_parts(value: String) -> Array:
 var regex=RegEx.new();regex.compile("^v?([0-9]+)\\.([0-9]+)\\.([0-9]+)$")
 var result=regex.search(value)
 if result==null:return []
 return [result.get_string(1).to_int(),result.get_string(2).to_int(),result.get_string(3).to_int()]
static func newer(candidate: String,installed: String) -> bool:
 var a=version_parts(candidate);var b=version_parts(installed)
 if a.is_empty() or b.is_empty():return false
 for index in range(3):
  if a[index]!=b[index]:return a[index]>b[index]
 return false
static func parse_release(data: Variant) -> Dictionary:
 if not data is Dictionary or data.get("draft",true) or data.get("prerelease",true):return {}
 var tag=str(data.get("tag_name",""))
 if version_parts(tag).is_empty():return {}
 var version=tag.trim_prefix("v");var name="Howling-Rift-v"+version+"-Spacewar.zip"
 var prefixes=["https://github.com/"+REPO+"/releases/download/"+tag+"/","https://github.com/"+LEGACY_REPO+"/releases/download/"+tag+"/"]
 var result={"version":version,"zip_url":"","checksum_url":""}
 if not data.get("assets",[]) is Array:return {}
 for asset in data.assets:
  if not asset is Dictionary:continue
  var url=str(asset.get("browser_download_url",""))
  if asset.get("name","")==name and url in [prefixes[0]+name,prefixes[1]+name]:result.zip_url=url
  if asset.get("name","")==name+".sha256" and url in [prefixes[0]+name+".sha256",prefixes[1]+name+".sha256"]:result.checksum_url=url
 return result if not result.zip_url.is_empty() and not result.checksum_url.is_empty() else {}
func _checked(result: int,code: int,_headers: PackedStringArray,body: PackedByteArray) -> void:
 if result!=HTTPRequest.RESULT_SUCCESS or code!=200:_error("Update check unavailable. You can still play.");return
 release=parse_release(JSON.parse_string(body.get_string_from_utf8()))
 if release.is_empty():_error("Release has no verified update package.");return
 checked=true;latest=release.version
 if newer(latest,current):
  phase="available";status="Update available: v"+latest+" • Installed v"+current
  changed.emit()
  if auto_download and not OS.has_feature("editor") and OS.get_name()=="Windows":download_update()
 else:
  phase="current";status="Up to date • v"+current if latest==current else "Development build v"+current+" • Latest release v"+latest
  changed.emit()
func helper_path() -> String:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE))
 var path=ProjectSettings.globalize_path(CACHE+"/UpdateGame.ps1")
 var file=FileAccess.open(path,FileAccess.WRITE)
 if file==null:return ""
 file.store_string(FileAccess.get_file_as_string("res://assets/updater/UpdateGame.ps1"));file.close()
 return path
func download_update() -> void:
 if phase!="available" or release.is_empty():return
 if OS.has_feature("editor") or OS.get_name()!="Windows":
  status="Source build: use GitHub release to install updates.";changed.emit();return
 var helper=helper_path()
 if helper.is_empty():_error("Could not create updater. Open release page to download.");return
 var state_path=ProjectSettings.globalize_path(CACHE+"/state-"+latest+".json")
 if FileAccess.file_exists(state_path):DirAccess.remove_absolute(state_path)
 phase="downloading";status="Downloading v"+latest+" in background…";changed.emit()
 worker_pid=OS.create_process("powershell.exe",PackedStringArray(["-NoProfile","-NonInteractive","-WindowStyle","Hidden","-ExecutionPolicy","Bypass","-File",helper,"-Mode","Download","-Cache",ProjectSettings.globalize_path(CACHE),"-Version",latest,"-ZipUrl",release.zip_url,"-ChecksumUrl",release.checksum_url]),false)
 if worker_pid<=0:_error("Could not launch updater. Open release page to download.")
func _process(delta: float) -> void:
 if phase!="downloading":return
 poll_time+=delta
 if poll_time<.5:return
 poll_time=0.
 var path=CACHE+"/state-"+latest+".json"
 if FileAccess.file_exists(path):
  var state=JSON.parse_string(FileAccess.get_file_as_string(path))
  if state is Dictionary and state.get("version","")==latest:
   if state.get("phase","")=="ready":
    phase="ready";status="v"+latest+" ready • Restart to update";changed.emit();return
   if state.get("phase","")=="error":_error("Update failed. Retry or download from GitHub.");return
 if worker_pid>0 and not OS.is_process_running(worker_pid):_error("Update stopped. Retry or download from GitHub.")
func restart_to_update() -> void:
 if phase!="ready" or GameState.started or LanSession.active:return
 var executable=OS.get_executable_path()
 var pid=OS.create_process("powershell.exe",PackedStringArray(["-NoProfile","-NonInteractive","-WindowStyle","Hidden","-ExecutionPolicy","Bypass","-File",helper_path(),"-Mode","Install","-Cache",ProjectSettings.globalize_path(CACHE),"-Version",latest,"-GameDir",executable.get_base_dir(),"-ProcessId",str(OS.get_process_id())]),false)
 if pid<=0:_error("Could not restart updater. Please retry.");return
 phase="installing";get_tree().quit()
func _error(message: String) -> void:
 phase="error";status="v"+current+" • "+message;changed.emit()
func open_release() -> void:OS.shell_open(PAGE)
