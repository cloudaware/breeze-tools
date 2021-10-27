Write-Output 'Uninstalling Breeze Agent...'
if (@(schtasks /Query /FO LIST | Select-String 'Breeze Agent') -ne '') {
	schtasks /Delete /TN 'Breeze Agent' /F
}
if (@(schtasks /Query /FO LIST | Select-String 'Breeze Agent Logrotate') -ne '') {
	schtasks /Delete /TN 'Breeze Agent Logrotate' /F
}
$breeze_directory = $Env:ProgramFiles + "\Breeze"
if (Test-Path -Path $breeze_directory) {
	Remove-Item $breeze_directory -Recurse -Force -Confirm:$false
}
Write-Output 'Done'
