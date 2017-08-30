﻿<#
.DESCRIPTION
    This script updates the new service encryption key for all the 8010/8020 devices.

    Steps to execute the script: 
    ----------------------------
    1.  Open powershell, create a new folder & change directory to the folder.
            > mkdir C:\scripts\StorSimpleSDKTools
            > cd C:\scripts\StorSimpleSDKTools
    
    2.  Download nuget CLI under the same folder in Step1.
        Various versions of nuget.exe are available on nuget.org/downloads. Each download link points directly to an .exe file, so be sure to right-click and save the file to your computer rather than running it from the browser. 
            > wget https://dist.nuget.org/win-x86-commandline/latest/nuget.exe -Out :\scripts\StorSimpleSDKTools\nuget.exe
    
    3.  Download the dependent SDK
            > C:\scripts\StorSimpleSDKTools\nuget.exe install Microsoft.Azure.Management.Storsimple8000series
            > C:\scripts\StorSimpleSDKTools\nuget.exe install Microsoft.IdentityModel.Clients.ActiveDirectory -Version 2.28.3
            > C:\scripts\StorSimpleSDKTools\nuget.exe install Microsoft.Rest.ClientRuntime.Azure.Authentication -Version 2.2.9-preview
    
    4.  Download the script from script center. 
            > wget https://github.com/anoobbacker/storsimpledevicemgmttools/raw/master/Authorize-ServiceEncryptionRollover.ps1 -Out Update-CloudApplianceServiceEncryptionKey.ps1
            > .\Update-CloudApplianceServiceEncryptionKey.ps1 -SubscriptionId <subid> -TenantId <tenantid> -ResourceGroupName <resource group> -ManagerName <device manager>
     
     ----------------------------     
.PARAMS 

    SubscriptionId: Input the Subscription ID where the StorSimple 8000 series device manager is deployed.
    TenantId: Input the ID of the tenant of the subscription. Get using Get-AzureRmSubscription cmdlet.
    DeviceName: Input the name of the StorSimple device on which to authorize a device to change the service encryption key.
    ResourceGroupName: Input the name of the resource group on which to authorize a device to change the service encryption key.
    ManagerName: Input the name of the resource (StorSimple device manager) on which to authorize a device to change the service encryption key.
#>

Param
(
    [parameter(Mandatory = $true, HelpMessage = "Input the Subscription ID where the StorSimple 8000 series device manager is deployed.")]
    [String]
    $SubscriptionId,

    [parameter(Mandatory = $true, HelpMessage = "Input the ID of the tenant of the subscription. Get using Get-AzureRmSubscription cmdlet.")]
    [String]
    $TenantId,

    [parameter(Mandatory = $true, HelpMessage = "Input the name of the resource group on which to rollover the service encryption key.")]
    [String]
    $ResourceGroupName,

    [parameter(Mandatory = $true, HelpMessage = "Input the name of the resource (StorSimple device manager) on which to rollover the service encryption key.")]
    [String]
    $ManagerName,

    [parameter(Mandatory = $true, HelpMessage = "Input the service encryption key.")]
    [String]
    $EncryptionKey
)

# Set Current directory path
$ScriptDirectory = (Get-Location).Path

#Set dll path
$ActiveDirectoryPath = Join-Path $ScriptDirectory "Microsoft.IdentityModel.Clients.ActiveDirectory.2.28.3\lib\net45\Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
$ClientRuntimeAzurePath = Join-Path $ScriptDirectory "Microsoft.Rest.ClientRuntime.Azure.3.3.7\lib\net452\Microsoft.Rest.ClientRuntime.Azure.dll"
$ClientRuntimePath = Join-Path $ScriptDirectory "Microsoft.Rest.ClientRuntime.2.3.8\lib\net452\Microsoft.Rest.ClientRuntime.dll"
$NewtonsoftJsonPath = Join-Path $ScriptDirectory "Newtonsoft.Json.6.0.8\lib\net45\Newtonsoft.Json.dll"
$AzureAuthenticationPath = Join-Path $ScriptDirectory "Microsoft.Rest.ClientRuntime.Azure.Authentication.2.2.9-preview\lib\net45\Microsoft.Rest.ClientRuntime.Azure.Authentication.dll"
$StorSimple8000SeresePath = Join-Path $ScriptDirectory "Microsoft.Azure.Management.Storsimple8000series.1.0.0\lib\net452\Microsoft.Azure.Management.Storsimple8000series.dll"

#Load all required assemblies
[System.Reflection.Assembly]::LoadFrom($ActiveDirectoryPath) | Out-Null
[System.Reflection.Assembly]::LoadFrom($ClientRuntimeAzurePath) | Out-Null
[System.Reflection.Assembly]::LoadFrom($ClientRuntimePath) | Out-Null
[System.Reflection.Assembly]::LoadFrom($NewtonsoftJsonPath) | Out-Null
[System.Reflection.Assembly]::LoadFrom($AzureAuthenticationPath) | Out-Null
[System.Reflection.Assembly]::LoadFrom($StorSimple8000SeresePath) | Out-Null

# Print methods
Function PrettyWriter($Content, $Color = "Yellow") { 
    Write-Host $Content -Foregroundcolor $Color 
}

# Define constant variables (DO NOT CHANGE BELOW VALUES)
$FrontdoorUrl = "urn:ietf:wg:oauth:2.0:oob"
$TokenUrl = "https://management.azure.com"
$DomainId = "1950a258-227b-4e31-a9cf-717495945fc2"

$FrontdoorUri = New-Object System.Uri -ArgumentList $FrontdoorUrl
$TokenUri = New-Object System.Uri -ArgumentList $TokenUrl

$AADClient = [Microsoft.Rest.Azure.Authentication.ActiveDirectoryClientSettings]::UsePromptOnly($DomainId, $FrontdoorUri)

# Set Synchronization context
$SyncContext = New-Object System.Threading.SynchronizationContext
[System.Threading.SynchronizationContext]::SetSynchronizationContext($SyncContext)

# Verify User Credentials
$Credentials = [Microsoft.Rest.Azure.Authentication.UserTokenProvider]::LoginWithPromptAsync($TenantId, $AADClient).GetAwaiter().GetResult()
$StorSimpleClient = New-Object Microsoft.Azure.Management.StorSimple8000Series.StorSimple8000SeriesManagementClient -ArgumentList $TokenUri, $Credentials

# Set SubscriptionId
$StorSimpleClient.SubscriptionId = $SubscriptionId

try {

    $Devices = [Microsoft.Azure.Management.StorSimple8000Series.DevicesOperationsExtensions]::ListByManager($StorSimpleClient.Devices, $ResourceGroupName, $ManagerName);

     $Devices | ForEach-Object {
         if ( $_.DeviceType -eq [Microsoft.Azure.Management.StorSimple8000Series.Models.DeviceType]::Series8000VirtualAppliance) {
             $SecuritySettings = [Microsoft.Azure.Management.StorSimple8000Series.DeviceSettingsOperationsExtensions]::GetSecuritySettings($StorSimpleClient.DeviceSettings, $_.FriendlyName, $ResourceGroupName, $ManagerName);
             $ServiceDataEncryptionKey = New-Object[Microsoft.Azure.Management.StorSimple8000Series.Models.AsymmetricEncryptedSecret]::AsymmetricEncryptedSecret($EncryptionKey, [Microsoft.Azure.Management.StorSimple8000Series.Models.EncryptionAlgorithm]::None)
         }
     }
     $ServiceDataEncryptionKey = New-Object Microsoft.Azure.Management.StorSimple8000Series.Models.CloudApplianceSettings -ArgumentList $TokenUri, $Credentials
    
    [Microsoft.Azure.Management.StorSimple8000Series.DeviceSettingsOperationsExtensions]::UpdateSecuritySettings($StorSimpleClient.DeviceSettings, $DeviceName, $ResourceGroupName, $ManagerName)

    # Print success message
    PrettyWriter "Device ($($DeviceName)) successfully authorized a device to change the service encryption key`nThe authorization will be expire after 4 hours.`n"
}
catch {
    # Print error details
    Write-Error $_.Exception.Message
    break
}