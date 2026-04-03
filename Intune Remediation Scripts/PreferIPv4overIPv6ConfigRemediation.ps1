# Ensure Prefer IPv4 over IPv6 registry key is present

$IPv4Path = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters"

$IPv4Settings = @{

"DisabledComponents" = 32 

}

if (-Not (Test-Path $IPv4Path)) {

New-Item -Path $IPv4Path -Force | Out-Null

}

foreach ($setting in $IPv4Settings.GetEnumerator()) {

Set-ItemProperty -Path $IPv4Path -Name $setting.Key -Value $setting.Value -Type DWord -Force | Out-Null 
 
Write-Output "Set $($setting.Key) to $($setting.Value)"

}