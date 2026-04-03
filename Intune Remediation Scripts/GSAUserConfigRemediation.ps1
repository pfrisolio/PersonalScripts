# Ensure Global Secure Access registry keys are present

$gsaPath = "HKLM:\SOFTWARE\Microsoft\Global Secure Access Client"

$gsaSettings = @{

"HideSignOutButton" = 1 
 
"HideDisablePrivateAccessButton" = 1 
 
"HideDisableButton" = 1 
 
"RestrictNonPrivilegedUsers" = 1

}

if (-Not (Test-Path $gsaPath)) {

New-Item -Path $gsaPath -Force | Out-Null

}

foreach ($setting in $gsaSettings.GetEnumerator()) {

Set-ItemProperty -Path $gsaPath -Name $setting.Key -Value $setting.Value -Type DWord -Force | Out-Null 
 
Write-Output "Set $($setting.Key) to $($setting.Value)"

}