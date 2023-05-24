function Add-CsvItem {
    param(
        [string]$TagName,
        [string]$TagURL,
        [string]$CloudServiceName,
        [string]$CertName,
        [string]$CertThumbprint,
        [DateTime]$Expiration,
        [bool]$IsExpired,
        [bool]$Expired30,
        [bool]$Expired60
    )

    $csvItem = [PsCustomObject]@{
        'Customer Name'          = $TagName
        'Customer URL'           = $TagURL
        'Cloud Service Name'     = $CloudServiceName
        'Certificate Name'       = $CertName
        'Certificate Thumbprint' = $CertThumbprint
        'Expiration Date'        = $Expiration
        'Expired'                = $IsExpired
        'Expires in 30 Days'     = $Expired30
        'Expires in 60 Days'     = $Expired60
    }

    $csvArray.Add($csvItem) | Out-Null
}

function Main {
    # Import the Azure Key Vault module
    Import-Module -Name Az.KeyVault

    # Set the Azure subscription
    Set-AzContext -SubscriptionId "subscriptionId goes here"

    # Get all Key Vaults within the subscription
    $keyVaultList = Get-AzKeyVault

    # Get the current date
    $currentDate = Get-Date

    # Create hash tables for expired, expiring in 30 days, and expiring in 60 days certificates
    $expiringCertificates = @{}

    # Create CSV array to push data to CSV
    $csvArray = [System.Collections.ArrayList]@()

    # Loop through each Key Vault
    foreach ($keyVault in $keyVaultList) {
        $keyVaultName = $keyVault.VaultName

        # Get the certificates from the Key Vault
        $certificates = Get-AzKeyVaultCertificate -VaultName $keyVaultName

        # Loop through each certificate and check if expiration is within 60 days
        foreach ($certificate in $certificates) {
            $daysUntilExpiration = ($certificate.Expires - $currentDate).Days

            # Get the certificate thumbprint
            $certificateThumbprint = (Get-AzKeyVaultCertificate -VaultName $keyVaultName -Name $certificate.Name).Thumbprint

            # Create a custom object to store certificate information in hash table
            $certificateObject = [PSCustomObject]@{
                "Name"       = $certificate.Name
                "Thumbprint" = $certificateThumbprint
                "Expires"    = $certificate.Expires
            }
		
            # If certificate expires within 60 days add it to the hash table 
            if ($daysUntilExpiration -le 60) {
                $expiringCertificates[$certificateThumbprint] = $certificateObject
            }
        }
    }

    # Display the certificates in each hash table
    Write-Host "Excpired or Expiring Certificates in Key Vaults:"
    $expiringCertificates.Values

    # Get all Extended Support Cloud Services
    $cloudServices = Get-AzCloudService

    # Check if the expired certificates in Key Vaults are currently deployed to any cloud service
    foreach ($cloudService in $cloudServices) {
        $cses = Get-AzCloudService -ResourceGroupName $cloudService.ResourceGroupName -CloudServiceName $cloudService.Name
        $xml = [xml]$cses.Configuration
        $csesThumbprint = $xml.ServiceConfiguration.Role.Certificates.Certificate.thumbprint
        if ($expiringCertificates.ContainsKey($csesThumbprint)) {
            $certificate = $expiringCertificates[$csesThumbprint]
        }
        # Remove this 'else' if you want all certificates reported not just the expiring ones. 
        else {
            Continue
        }

        $certificateName = $certificate.Name
        $certificateThumbprint = $certificate.Thumbprint
        $certificateExpiration = $certificate.Expires
        $daysUntilExpiration = ($certificateExpiration - $currentDate).Days

        $csvItemParams = @{
            TagName          = $cloudService.Tag["Customer"]
            TagURL           = $cloudService.Tag["URL"]
            CloudServiceName = $cloudService.Name
            CertName         = $certificateName 
            CertThumbprint   = $certificateThumbprint 
            Expiration       = $certificateExpiration 
            IsExpired        = ($daysUntilExpiration -le 0)
            Expired30        = ($daysUntilExpiration -le 30)
            Expired60        = ($daysUntilExpiration -le 60)
        }

        Add-CsvItem @csvItemParams
    }
    # Export the data to a CSV file
    $reportFilePath = "./csesCertificateReport.csv"
    $csvArray | Export-Csv  -Path $reportFilePath -NoTypeInformation -Force
    Start-Process -FilePath $reportFilePath
}

#Call the Main function
Main
