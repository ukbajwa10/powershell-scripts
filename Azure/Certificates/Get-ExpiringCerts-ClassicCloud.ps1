#Connect to Azure Subscription:
Connect-AzureRmAccount -TenantId 'tenantid goes here'

#Using AzureRM PowerShell 6.13.0
Import-Module -Name AzureRM

$csvArray = [System.Collections.ArrayList]@()

function AddCsvItem {
    param( [string]$TagName, [string]$CloudServiceName, [string]$CertName, [DateTime]$Expiration, [bool]$IsExpired, [bool]$Expired30, [bool]$Expired60 )

    [void]$csvArray.Add([PsCustomObject]@{
            'Customer Name'      = $TagName
            'Cloud Service Name' = $CloudServiceName
            'Certificate Name'   = $CertName
            'Expiration Date'    = $Expiration
            'Is Expired?'        = $IsExpired
            'Will Expire in 30?' = $Expired30
            'Will Expire in 60?' = $Expired60
        })
}

#Date Variables
$todayDate = Get-Date
$todayDate30 = $todayDate.AddDays(30)
$todayDate60 = $todayDate.AddDays(60)

#To get all cloud services:
$cloudServices = Get-AzureRmResource -ResourceType Microsoft.ClassicCompute/domainNames -ApiVersion 2016-02-01 -WarningAction:SilentlyContinue



#To get relevant certificates loaded in a cloud service
foreach ($cloudService in $cloudServices) {

    $certificates = Get-AzureRmResource -ResourceGroupName $cloudService.ResourceGroupName -ResourceType Microsoft.ClassicCompute/domainNames/serviceCertificates -ResourceName $cloudService.ResourceName -ApiVersion 2016-04-01 -WarningAction:SilentlyContinue
    $slots = Get-AzureRmResource -ResourceGroupName $cloudService.ResourceGroupName -ResourceType Microsoft.ClassicCompute/domainNames/slots -ResourceName $cloudService.ResourceName -ApiVersion 2016-04-01 -WarningAction:SilentlyContinue
    $resourceGroup = Get-AzureRmResourceGroup -Name $cloudService.ResourceGroupName -WarningAction:SilentlyContinue

    Write-Host $cloudService.Name

    
    #If the cloud service is empty, skip and continue
    if ($certificates -eq $null -or $slots -eq $null -or $certificates.Count -eq 0 -or $slots.Count -eq 0) {
        Write-Host "There is nothing deployed to $($cloudService.Name) cloud service." 
        Write-Host
        AddCsvItem $resourceGroup.Tags.Customer $cloudService.Name
        Continue
    }

    $doc = [xml]$slots[0].properties.configuration
    $slotThumbprints = $doc.ServiceConfiguration.role.certificates.certificate

    if ($slotThumbprints -eq $null -or $slotThumbprints.Count -eq 0) {
        Write-Host "There are no active slot certificates for $($cloudService.Name) cloud service."
        Write-Host 
        AddCsvItem $resourceGroup.Tags.Customer $cloudService.Name
        Continue
    }



    $foundCerts = foreach ($slotThumbprint in $slotThumbprints) {
        $x = $certificates | where { $_.properties.thumbprint -eq $slotThumbprint.thumbprint }
        if ($x -ne $null) {

            @{
                certificate = $x
                name        = $slotThumbprint.name
            }
        }


    }

  

    foreach ($foundCert in $foundCerts) {
        

        $expirationDate = ([System.Security.Cryptography.X509Certificates.X509Certificate2]([System.Convert]::FromBase64String($foundCert.Certificate.Properties.data))).NotAfter 
        if ($expirationDate -le $todayDate) {
            $expirationDaysAgo = ($todayDate - $expirationDate).Days
            Write-Host "$($foundCert.Name) certificate expired $expirationDaysAgo days ago!"
        }
        elseif ($expirationDate -le $todayDate30)
        { Write-Host "$($foundCert.Name) certificate is expiring in 30 days or less" }
        elseif ($expirationDate -le $todayDate60)
        { Write-Host "$($foundCert.Name) certificate is expiring in 60 days or less" }
        else { Write-Host "$($foundCert.Name) certificate is okay. Expiration date: $expirationDate" }
        AddCsvItem $resourceGroup.Tags.Customer $cloudService.Name $foundCert.Name $expirationDate ($expirationDate -le $todayDate) ($expirationDate -le $todayDate30) ($expirationDate -le $todayDate60)

    } 
    Write-Host
}


$csvArray | Export-Csv  -Path ./CertificateReport.csv -NoTypeInformation -Force
