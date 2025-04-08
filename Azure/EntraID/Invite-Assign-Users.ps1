#Requires -Modules Microsoft.Graph.Identity.SignIns, Microsoft.Graph.Users, Microsoft.Graph.Applications
#Requires -Version 7.0
#Requires -PSEdition Core

param (
    [Parameter(Mandatory=$true, HelpMessage="Input the full name of the client that is inviting the users.")]
    [string]$RequesterName,
    [Parameter(Mandatory=$true, HelpMessage="Input the company name of the client the users are being invited to.")]
    [string]$CompanyName,
    [Parameter(Mandatory=$true, HelpMessage="Valid regions to invite to are: 'USPROD', 'USTEST', 'CAN', 'UKPROD', 'UKTEST'.")]
    [ValidateSet("USPROD", "USTEST", "CAN", "UKPROD", "UKTEST")]
    [string]$Region
)

Import-Module Microsoft.Graph.Identity.SignIns
Import-Module Microsoft.Graph.Users
Import-Module Microsoft.Graph.Applications

# Connect to AAD Tenant using App registration ClientID
# Create App Registration in tenant - make sure to require assignment to enterprise app

Connect-MgGraph -NoWelcome -Scopes "User.ReadWrite.All", "Application.ReadWrite.All", "Directory.ReadWrite.All", "AppRoleAssignment.ReadWrite.All" -ClientId "" -TenantId ""

switch ($Region) {
    "USPROD" {
        $app_id = ""
        $redirectURL = ""
        Write-Host "Inviting and assigning users to US Production..." -ForegroundColor Green
        break
    }
    "USTEST" {
        $app_id = ""
        $redirectURL = ""
        Write-Host "Inviting and assigning users to US Test..." -ForegroundColor Green
        break
    }
    "CAN" {
        $app_id = ""
        $redirectURL = ""
        Write-Host "Inviting and assigning users to Canada..." -ForegroundColor Green
        break
    }
    "UKPROD" {
        $app_id = ""
        $redirectURL = ""
        Write-Host "Inviting and assigning users to UK Production..." -ForegroundColor Green
        break
    }
    "UKTEST" {
        $app_id = ""
        $redirectURL = ""
        Write-Host "Inviting and assigning users to UK Test..." -ForegroundColor Green
        break
    }
    Default {
        Write-Host "Invalid Region!" -ForegroundColor Red
        exit
    }
}
function Main {
    # Clean up Users.txt file
    if (Test-Path -Path "$PSScriptRoot\users.txt") {
        Write-Host "Clearing out old redemption links..." -ForegroundColor Cyan
        Remove-Item -Path "$PSScriptRoot\users.txt"
    }
    
    # Get the service principal for the enterprise application 
    $servicePrincipal = Get-MgServicePrincipal -Filter "AppId eq '$app_id'"

    # Import users to invite via CSV file. Include User Display Name and Email Address
    $users = Import-CSV -Path $PSScriptRoot\users.csv

    # Set invite message here
    $InvitedUserMessageInfo = [Microsoft.Graph.PowerShell.Models.MicrosoftGraphInvitation]@{
        CustomizedMessageBody = "Hello,
        You are receiving this invitation to SaaS environment for Application because $RequesterName at $CompanyName requested that you be added. Please accept this invitation to gain access to your Gimmal Records application. If you have any questions or concerns, feel free to reach out to support@company.com."
    }

    # Invite the user to the tenant as a Guest and output Redeem URLs to a text document
    foreach ($user in $users) {
        $userInvite = New-MgInvitation -InvitedUserDisplayName $user.DisplayName -InvitedUserEmailAddress $user.EmailAddress -InviteRedirectUrl $redirectURL -SendInvitationMessage:$true -InvitedUserMessageInfo $InvitedUserMessageInfo
        $userInvite | Out-Null
        Write-Output $userInvite.InvitedUserDisplayName $userInvite.InviteRedeemUrl | Out-File -FilePath $PSScriptRoot\users.txt -Append
    }
    Start-Sleep 15
    # Wait for the last user to propagate in the tenant before inviting users
    Write-Host
    $userCount = (($users.EmailAddress | Measure-Object).Count) / 2
    $loopTimeout = New-TimeSpan -Minutes $userCount
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $lastEmail = ($users.EmailAddress)[-1]
    # Keeps looping until either the last user shows up in tenant or the loop times out. Loop times out after 30 seconds per user invited. 
    while (([bool](Get-MgUser -Search "Mail:$lastEmail" -ConsistencyLevel eventual) -eq $false) -and $stopwatch.Elapsed -lt $loopTimeout) {
        Get-MgUser -Search "Mail:$lastEmail" -ConsistencyLevel eventual
        Write-Host "Waiting for users to propagate in the tenant..." -ForegroundColor Yellow
        Start-Sleep -Seconds 3
    }

    $stopwatch.Stop()

    # Assign user to the enterprise application
    foreach ($user in $users){
        # Find the just invited user in the tenant
        $email = $user.EmailAddress
        $userId = (Get-MgUser -Search "Mail:$email" -ConsistencyLevel eventual).Id
        $params = @{
            "PrincipalId" =$userId
            "ResourceId" =$servicePrincipal.Id
            }
        # Assign the user to the Enterprise application with default access
        New-MgUserAppRoleAssignment -UserId $userId -BodyParameter $params
    }
    # Generate the Salesforce Message. Note that $userCount is calculated by dividing the number of users in half (line 85), used for creating the timeout. Variable name should probably be updated.
    if($userCount -ge 1) {
        Set-Clipboard -Value ""
    } else {
        Set-Clipboard -Value ""
    }

}

Main
