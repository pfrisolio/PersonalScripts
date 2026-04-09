Import-Module ActiveDirectory

$domainDn = (Get-ADDomain).DistinguishedName
$outCsv   = Join-Path $PWD "AD_EnabledUsers_InheritanceDisabled.csv"

$users = Get-ADUser -Filter "Enabled -eq 'True'" -SearchBase $domainDn `
    -Properties DistinguishedName,SamAccountName,Enabled

$result = foreach ($u in $users) {
    try {
        $acl = Get-Acl -Path ("AD:\" + $u.DistinguishedName)

        if ($acl.AreAccessRulesProtected) {
            [pscustomobject]@{
                SamAccountName      = $u.SamAccountName
                Enabled             = $u.Enabled
                DistinguishedName   = $u.DistinguishedName
                InheritanceDisabled = $true
            }
        }
    }
    catch {
        [pscustomobject]@{
            SamAccountName      = $u.SamAccountName
            Enabled             = $u.Enabled
            DistinguishedName   = $u.DistinguishedName
            InheritanceDisabled = $null
            Error               = $_.Exception.Message
        }
    }
}

$result | Sort-Object SamAccountName | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $outCsv
"Found {0} enabled users with inheritance disabled. Report: {1}" -f ($result | Measure-Object).Count, $outCsv