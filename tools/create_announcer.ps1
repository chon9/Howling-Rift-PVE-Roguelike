Add-Type -AssemblyName System.Speech
$voiceOutput = Join-Path $PSScriptRoot '../assets/audio/combat-v2/voice-source'
New-Item -ItemType Directory -Path $voiceOutput -Force | Out-Null
$announcerSynth = New-Object System.Speech.Synthesis.SpeechSynthesizer
$femaleVoice = $announcerSynth.GetInstalledVoices() | Where-Object { $_.Enabled -and $_.VoiceInfo.Gender -eq [System.Speech.Synthesis.VoiceGender]::Female -and $_.VoiceInfo.Culture.Name -eq 'en-US' } | Select-Object -First 1
if ($null -eq $femaleVoice) { throw 'An installed English female voice is required to generate the announcer.' }
$announcerSynth.SelectVoice($femaleVoice.VoiceInfo.Name)
$announcerSynth.Rate = 0
$voiceFormat = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo(48000, [System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen, [System.Speech.AudioFormat.AudioChannel]::Mono)
$announcerLines = [ordered]@{
 'first_blood' = 'First blood.'
 'double_kill' = 'Double kill.'
 'triple_kill' = 'Triple kill.'
 'quadra_kill' = 'Quadra kill.'
 'penta_kill' = 'Penta kill.'
 'killing_spree' = 'Killing spree.'
 'shutdown' = 'Shut down.'
 'enemy_slain' = 'An enemy has been slain.'
 'ally_slain' = 'An ally has been slain.'
 'victory_voice' = 'Victory.'
 'defeat_voice' = 'Defeat.'
}
foreach ($line in $announcerLines.GetEnumerator()) {
 $announcerSynth.SetOutputToWaveFile((Join-Path $voiceOutput ($line.Key + '.wav')), $voiceFormat)
 $announcerSynth.Speak($line.Value)
}
$announcerSynth.Dispose()
$voiceName = $femaleVoice.VoiceInfo.Name
@{ voice = $voiceName; gender = 'Female'; language = 'en-US'; rate = 0; pitch_processing = 'none'; lines = @($announcerLines.Keys) } | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $voiceOutput 'VOICE_INFO.json') -Encoding utf8
Write-Output "Recorded original announcer text with installed female voice: $voiceName"
