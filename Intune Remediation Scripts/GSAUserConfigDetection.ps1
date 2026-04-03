# Check Global Secure Access registry keys

$gsaPath = "HKLM:\SOFTWARE\Microsoft\Global Secure Access Client"

$gsaSettings = @{

"HideSignOutButton" = 1 
 
"HideDisablePrivateAccessButton" = 1 
 
"HideDisableButton" = 1 
 
"RestrictNonPrivilegedUsers" = 1

}

$nonCompliant = $false

foreach ($setting in $gsaSettings.GetEnumerator()) {

$currentValue = (Get-ItemProperty -Path $gsaPath -Name $setting.Key -ErrorAction SilentlyContinue).$($setting.Key) 
 
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