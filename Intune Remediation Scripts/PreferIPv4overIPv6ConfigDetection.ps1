# Check Prefer IPv4 over IPv6 registry keys

$IPv4Path = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters"

$IPv4Settings = @{

"DisabledComponents" = 32 

}

$nonCompliant = $false

foreach ($setting in $IPv4Settings.GetEnumerator()) {

$currentValue = (Get-ItemProperty -Path $IPv4Path -Name $setting.Key -ErrorAction SilentlyContinue).$($setting.Key) 
 
if ($currentValue -ne $setting.Value) { 
 
    Write-Output "Non-compliant: $($setting.Key) is $currentValue, expected $($setting.Value)" 
 
    $nonCompliant = $true 
 
}

}

if (-not $nonCompliant) {

Write-Output "Compliant" 
 
exit 0

} else {

Write-Output "Non-compliant" 
 
exit 1

}