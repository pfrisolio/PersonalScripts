#The purpose of this script is to create an overview:
#The total amount of SharePoint Storage used by this Site Collection,
#and how much could be saved by trimming the versions

#Set Variables
$SharePointAdminSiteURL = "https://paulofadaquestlab-admin.sharepoint.com"
$outputPath = "C:\SharePointAssessment"

$reducedNumberOfVersions = 5
$UsingInteractive = $false
$UsingCertificate = $true

$clientID = "1e1f165a-d8bf-4c35-9e31-58843e21ee2a"
$tenantId = "paulofadaquestlab.onmicrosoft.com"

$certificatePassword = "adaQuest@2026"
$certificatePath = "C:\SharePointAssessment\SharePoint Version History Assessment.pfx"

# Ensure output folder exists
if (!(Test-Path $outputPath))
{
    New-Item -ItemType Directory -Path $outputPath | Out-Null
}

function HandleWeb ($site, $web, $root)
{
    $csvPath = $script:csvPath

    try
    {
        $DocumentLibraries = Get-PnPList -Connection $connection -ErrorAction Stop |
            Where-Object {
                $_.BaseTemplate -eq 101 -and $_.Hidden -eq $false
            }

        foreach($lib in $DocumentLibraries)
        {
            if(
                $lib.Title -eq "Form Templates" -or
                $lib.Title -eq "Style Library" -or
                $lib.Title -eq "Site Assets" -or
                $lib.Title -eq "Biblioteca de Estilos" -or
                $lib.Title -eq "Modelos de Formulário" -or
                $lib.Title -eq "Ativos do Site" -or
                $lib.Title -eq "Documentos do Conjunto de Sites" -or
                $lib.Title -eq "AppPages" -or
                $lib.Title -eq "Pages" -or
                $lib.Title -eq "Settings" -or
                $lib.Title -eq "Teams Wiki Data"
            )
            {
                Write-Host -ForegroundColor Red "Skipping $($lib.Title)"
                continue
            }

            Write-Host -ForegroundColor Green "$($lib.Title) loading items"

            try
            {
                $items = Get-PnPListItem `
                    -Connection $connection `
                    -List $lib `
                    -PageSize 500 `
                    -ErrorAction Stop

                Write-Host -ForegroundColor Blue "$($lib.Title), $($items.Count)"
            }
            catch
            {
                throw $_.Exception
            }

            foreach($item in $items)
            {
                # Skip folders or invalid items
                if(-not $item["FileRef"] -or $item.FileSystemObjectType -eq "Folder")
                {
                    continue
                }

                try
                {
                    $file = Get-PnPFile `
                        -Connection $connection `
                        -Url $item["FileRef"] `
                        -AsFileObject `
                        -ErrorAction Stop
                }
                catch
                {
                    Write-Host -ForegroundColor Red "`tError: $($_.Exception.Message)"
                    continue
                }

                if(-not $file)
                {
                    continue
                }

                $versions = Get-PnPProperty `
                    -Connection $connection `
                    -ClientObject $file `
                    -Property Versions

                # Only process files with more than 1 version
                if($versions.Count -gt 1)
                {
                    $versionSize = 0
                    $versionSizeReduced = 0

                    # Current total version size
                    foreach($FileVersion in $versions)
                    {
                        $versionSize += $FileVersion.Size
                    }

                    # Reduced version count size
                    $versions2 = $versions | Select-Object -Last $reducedNumberOfVersions

                    foreach($FileVersion in $versions2)
                    {
                        $versionSizeReduced += $FileVersion.Size
                    }

                    # Calculate sizes
                    $TotalFileSize = [Math]::Round(((($item.File.Length + $versionSize) / 1024) / 1024), 2)

                    $TotalFileSizeReduced = [Math]::Round(((($item.File.Length + $versionSizeReduced) / 1024) / 1024), 2)

                    $VersionSize = [Math]::Round((($versionSize / 1024) / 1024), 2)

                    $CurrentVersionSize = [Math]::Round((($item.File.Length / 1024) / 1024), 2)

                    # Site name
                    if($root -eq $true)
                    {
                        $siteName = $web.Title + " - Root"
                    }
                    else
                    {
                        $siteName = $web.Title
                    }

                    # Only export if versions consume space
                    if($versionSize -gt 0)
                    {
                        $fileextention = $item["FileLeafRef"].Substring(
                            $item["FileLeafRef"].LastIndexOf(".") + 1
                        )

                        $element = [PSCustomObject]@{
                            SiteUrl             = $site
                            SiteName            = $siteName
                            ListTitle           = $lib.Title
                            ItemName            = $file.Name
                            FileType            = $fileextention
                            Modified            = $file.TimeLastModified.ToString()
                            VersionCount        = $versions.Count
                            TotalFileSize       = $TotalFileSize
                            TotalFileSizeReduced = $TotalFileSizeReduced
                        }

                        # REAL-TIME CSV WRITE
                        $element | Export-Csv `
                            -Path $csvPath `
                            -Append `
                            -NoTypeInformation `
                            -Encoding utf8BOM `
                            -Delimiter "|"

                        # Running totals
                        $script:totalSize += $TotalFileSize
                        $script:totalSizeReduced += $TotalFileSizeReduced

                        Write-Host -ForegroundColor Cyan "Written to CSV: $($file.Name)"
                    }
                }
            }
        }
    }
    catch
    {
        Write-Host -ForegroundColor Red "`tError: $($_.Exception.Message)"
    }
}

function Get-SiteCollections
{
    # Get site collections in scope

    if($UsingInteractive -eq $true)
    {
        $conn = Connect-PnPOnline `
            -Url $SharePointAdminSiteURL `
            -Interactive `
            -ReturnConnection
    }

    if($UsingCertificate -eq $true)
    {
        $conn = Connect-PnPOnline `
            -Url $SharePointAdminSiteURL `
            -ClientId $clientID `
            -Tenant $tenantId `
            -CertificatePath $certificatePath `
            -CertificatePassword (
                ConvertTo-SecureString -AsPlainText -Force $certificatePassword
            ) `
            -ReturnConnection
    }

    $SiteCollections = Get-PnPTenantSite -Connection $conn

    return $SiteCollections
}

Try
{
    # Get all site collections
    $SiteCollections = Get-SiteCollections

    $index = 0
    $totalnumber = $SiteCollections.Count

    foreach($Site in $SiteCollections)
    {
        $SiteURL = $Site.Url

        Write-Host -ForegroundColor Green "$($SiteURL), number $index of $totalnumber"

        $index++

        try
        {
            # Create CSV file path
            $shortSiteUrl = $SiteURL.Split("/")[-1]

            if([string]::IsNullOrWhiteSpace($shortSiteUrl))
            {
                $shortSiteUrl = "RootSite"
            }

            $csvPath = "$outputPath\$shortSiteUrl.csv"

            # Remove existing CSV
            if(Test-Path $csvPath)
            {
                Remove-Item $csvPath -Force
            }

            # Script scope variables
            $script:csvPath = $csvPath
            $script:totalSize = 0
            $script:totalSizeReduced = 0

            # Connect to site collection
            if($UsingInteractive -eq $true)
            {
                $connection = Connect-PnPOnline `
                    -Url $SiteURL `
                    -Interactive `
                    -ReturnConnection
            }

            if($UsingCertificate -eq $true)
            {
                $connection = Connect-PnPOnline `
                    -Url $SiteURL `
                    -ClientId $clientID `
                    -Tenant $tenantId `
                    -CertificatePath $certificatePath `
                    -CertificatePassword (
                        ConvertTo-SecureString -AsPlainText -Force $certificatePassword
                    ) `
                    -ReturnConnection
            }

            # Process root web
            HandleWeb `
                -site $SiteURL `
                -web (Get-PnPWeb -Connection $connection) `
                -root $true

            # Process sub sites
            $SubSites = Get-PnPSubWeb -Recurse -Connection $connection

            foreach($web in $SubSites)
            {
                if($UsingInteractive -eq $true)
                {
                    $connection = Connect-PnPOnline `
                        -Url $web.Url `
                        -Interactive `
                        -ReturnConnection
                }

                if($UsingCertificate -eq $true)
                {
                    $connection = Connect-PnPOnline `
                        -Url $web.Url `
                        -ClientId $clientID `
                        -Tenant $tenantId `
                        -CertificatePath $certificatePath `
                        -CertificatePassword (
                            ConvertTo-SecureString -AsPlainText -Force $certificatePassword
                        ) `
                        -ReturnConnection
                }

                Write-Host "Web: $($web.URL)"

                HandleWeb `
                    -site $SiteURL `
                    -web $web `
                    -root $false
            }

            # Final totals
            $totalSize = [Math]::Round($script:totalSize, 2)
            $totalSizeReduced = [Math]::Round($script:totalSizeReduced, 2)

            $savings = $totalSize - $totalSizeReduced
            $savings = [Math]::Round($savings, 2)

            Write-Host -ForegroundColor Yellow "-----------------------------------"
            Write-Host -ForegroundColor Yellow "Site: $SiteURL"
            Write-Host -ForegroundColor Yellow "Current Size: $totalSize MB"
            Write-Host -ForegroundColor Yellow "Reduced Size: $totalSizeReduced MB"
            Write-Host -ForegroundColor Yellow "Potential Savings: $savings MB"
            Write-Host -ForegroundColor Yellow "CSV File: $csvPath"
            Write-Host -ForegroundColor Yellow "-----------------------------------"
        }
        catch
        {
            Write-Host -ForegroundColor Red "`tError: $($_.Exception.Message)"
        }
    }
}
catch
{
    Write-Host -ForegroundColor Red "Error: $($_.Exception.Message)"
}