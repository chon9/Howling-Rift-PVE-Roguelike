param(
 [ValidateSet('Download','Install','Verify')][string]$Mode,
 [Parameter(Mandatory=$true)][string]$Cache,
 [Parameter(Mandatory=$true)][string]$Version,
 [string]$ZipUrl, [string]$ChecksumUrl, [string]$GameDir,
 [int]$ProcessId=0, [string]$ZipPath, [string]$ExpectedHash,
 [switch]$NoLaunch
)
$ErrorActionPreference='Stop'
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw 'Invalid version' }
$cacheRoot=[IO.Path]::GetFullPath($Cache)
New-Item -ItemType Directory -Force -Path $cacheRoot | Out-Null
$statePath=Join-Path $cacheRoot "state-$Version.json"
$stageRoot=Join-Path $cacheRoot "stage-$Version"
$archivePath=Join-Path $cacheRoot "package-$Version.zip"
$zipName="Howling-Rift-v$Version-Spacewar.zip"
function Set-State([string]$Phase,[string]$Message='') {
 $state=@{version=$Version;phase=$Phase;message=$Message} | ConvertTo-Json -Compress
 [IO.File]::WriteAllText($statePath+'.tmp',$state)
 Move-Item -LiteralPath ($statePath+'.tmp') -Destination $statePath -Force
}
function Valid-File([string]$Name) {
 return ($Name -in @('Howling Rift.exe','Howling Rift.pck','libgodotsteam.windows.template_release.x86_64.dll','steam_api64.dll','steam_appid.txt')) -or ($Name -match '^[A-Za-z0-9 _.-]+\.md$')
}
function File-Hash([string]$Path) {
 $stream=[IO.File]::OpenRead($Path)
 $sha=[Security.Cryptography.SHA256]::Create()
 try { return [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','') }
 finally { $sha.Dispose(); $stream.Dispose() }
}
function Verify-And-Stage([string]$Archive,[string]$Hash) {
 if ($Hash -notmatch '^[a-fA-F0-9]{64}$') { throw 'Invalid checksum' }
 if ((File-Hash $Archive) -ne $Hash) { throw 'Checksum mismatch; package rejected' }
 Add-Type -AssemblyName System.IO.Compression.FileSystem
 $zip=[IO.Compression.ZipFile]::OpenRead($Archive)
 try {
  $entries=@();$seen=@{};$total=0L
  foreach ($entry in $zip.Entries) {
   $name=$entry.FullName.Replace('\','/')
   if ($name.EndsWith('/')) { continue }
   $prefix="Spacewar-v$Version/"
   if (-not $name.StartsWith($prefix,[StringComparison]::Ordinal)) { throw 'Unexpected archive root' }
   $leaf=$name.Substring($prefix.Length)
   if ($leaf.Contains('/') -or $leaf.Contains(':') -or $leaf -in @('.','..') -or -not (Valid-File $leaf)) { throw 'Unsafe archive entry' }
   if ($seen.ContainsKey($leaf.ToLowerInvariant())) { throw 'Duplicate archive entry' }
   if ((($entry.ExternalAttributes -shr 16) -band 0xF000) -eq 0xA000) { throw 'Symbolic links are not allowed' }
   $seen[$leaf.ToLowerInvariant()]=$true
   $total+=$entry.Length
   if ($total -gt 1500MB) { throw 'Package is too large' }
   $entries+=@{entry=$entry;name=$leaf}
  }
  foreach ($required in @('Howling Rift.exe','Howling Rift.pck','libgodotsteam.windows.template_release.x86_64.dll','steam_api64.dll','steam_appid.txt')) {
   if (-not $seen.ContainsKey($required.ToLowerInvariant())) { throw "Missing required file: $required" }
  }
  New-Item -ItemType Directory -Force -Path $stageRoot | Out-Null
  foreach ($data in $entries) {
   $target=[IO.Path]::GetFullPath((Join-Path $stageRoot $data.name))
   if (-not $target.StartsWith($stageRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Archive path escaped staging' }
   [IO.Compression.ZipFileExtensions]::ExtractToFile($data.entry,$target,$true)
  }
  # Retain a hash manifest so staging modifications cannot be installed unnoticed.
  $manifest=@()
  foreach ($data in $entries) { $manifest+=@{name=$data.name;sha256=(File-Hash (Join-Path $stageRoot $data.name))} }
  [IO.File]::WriteAllText((Join-Path $stageRoot 'manifest.json'),(ConvertTo-Json -InputObject @($manifest) -Depth 4))
 } finally { $zip.Dispose() }
 Set-State 'ready'
}
try {
 if ($Mode -eq 'Download') {
  Set-State 'downloading'
  $prefix="https://github.com/chon9/Howling-Rift-PVE-Roguelike/releases/download/v$Version/"
  $legacyPrefix="https://github.com/chon9/Howling-Rift---PVE-Roguelike/releases/download/v$Version/"
  $trusted=($ZipUrl -eq ($prefix+$zipName) -and $ChecksumUrl -eq ($prefix+$zipName+'.sha256')) -or ($ZipUrl -eq ($legacyPrefix+$zipName) -and $ChecksumUrl -eq ($legacyPrefix+$zipName+'.sha256'))
  if (-not $trusted) { throw 'Untrusted release URL' }
  [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
  $client=New-Object Net.WebClient
  try {
   $client.Headers.Add('User-Agent','Howling-Rift-Updater')
   $checksum=$client.DownloadString($ChecksumUrl)
   if ($checksum -notmatch ('^([a-fA-F0-9]{64})\s+'+[regex]::Escape($zipName)+'\s*$')) { throw 'Invalid checksum file' }
   $hash=$Matches[1]
   $client.DownloadFile($ZipUrl,$archivePath)
  } finally { $client.Dispose() }
  Verify-And-Stage $archivePath $hash
 } elseif ($Mode -eq 'Verify') {
  Set-State 'verifying'
  Verify-And-Stage $ZipPath $ExpectedHash
 } else {
  if ([string]::IsNullOrWhiteSpace($GameDir)) { throw 'Missing game directory' }
  $gameRoot=[IO.Path]::GetFullPath($GameDir)
  $exe=Join-Path $gameRoot 'Howling Rift.exe'
  if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { throw 'Invalid game installation' }
  $manifest=Get-Content -LiteralPath (Join-Path $stageRoot 'manifest.json') -Raw | ConvertFrom-Json
  if (@($manifest).Count -lt 5) { throw 'Incomplete stage' }
  foreach ($file in $manifest) {
   if (-not (Valid-File $file.name)) { throw 'Unsafe staged file' }
   $source=Join-Path $stageRoot $file.name
   if ((File-Hash $source) -ne $file.sha256) { throw 'Staging integrity check failed' }
   $target=[IO.Path]::GetFullPath((Join-Path $gameRoot $file.name))
   if (-not $target.StartsWith($gameRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Install path escaped game directory' }
   if ((Test-Path -LiteralPath $target) -and -not (Test-Path -LiteralPath $target -PathType Leaf)) { throw 'Install target is not a file' }
  }
  if ($ProcessId -gt 0) { Wait-Process -Id $ProcessId -Timeout 90 -ErrorAction SilentlyContinue }
  if ($ProcessId -gt 0 -and (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue)) { throw 'Game is still running' }
  $backup=Join-Path $cacheRoot ('backup-'+$Version+'-'+[guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $backup | Out-Null
  foreach ($file in $manifest) {
   $target=Join-Path $gameRoot $file.name
   if (Test-Path -LiteralPath $target -PathType Leaf) { Copy-Item -LiteralPath $target -Destination (Join-Path $backup $file.name) }
  }
  try {
   Set-State 'installing'
   foreach ($file in $manifest) { Copy-Item -LiteralPath (Join-Path $stageRoot $file.name) -Destination (Join-Path $gameRoot $file.name) -Force }
  } catch {
   foreach ($saved in (Get-ChildItem -LiteralPath $backup -File)) { Copy-Item -LiteralPath $saved.FullName -Destination (Join-Path $gameRoot $saved.Name) -Force }
   throw
  }
  Set-State 'installed'
  if (-not $NoLaunch) { Start-Process -FilePath $exe -WorkingDirectory $gameRoot -WindowStyle Hidden }
 }
} catch {
 Set-State 'error' $_.Exception.Message
 if ($Mode -eq 'Install' -and -not $NoLaunch -and $exe -and (Test-Path -LiteralPath $exe -PathType Leaf)) {
  if ($ProcessId -eq 0 -or -not (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue)) {
   Start-Process -FilePath $exe -WorkingDirectory $gameRoot -WindowStyle Hidden -ErrorAction SilentlyContinue
  }
 }
 exit 1
}
