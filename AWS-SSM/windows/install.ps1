Write-Output 'Installing Breeze Agent...'
$breeze_agent_installer = @(Get-ChildItem *.windows.signed.exe)[0]
Start-Process $breeze_agent_installer -ArgumentList '-gm2' -NoNewWindow -Wait
Remove-Item $breeze_agent_installer -Force -Confirm:$false
Write-Output 'Done'
