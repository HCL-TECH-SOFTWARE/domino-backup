#Requires -Modules VMware.VimAutomation.Core, Rubrik

param (
    [Parameter()]
    [String]$Tag,
    
    [Parameter()]
    [String]$Source,

    [Parameter()]
    [String]$Destination,

    [Parameter()]
    [Bool]$PersistMount
    )

function convertto-datetime($epochms) {
    Get-Date (Get-Date ((Get-Date "1970-01-01 00:00:00.000Z") + ([TimeSpan]::FromMilliSeconds($epochms)))).ToUniversalTime() -UFormat '+%Y-%m-%dT%H:%M:%S.000Z'
}

function ConvertFrom-SecureStringToPlainText ([System.Security.SecureString]$SecureString) {

    [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
    
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    )            
}

if(!(Test-Path .\rubrik.xml)) {
    $config = @{}
    Write-Output "Welcome to the first time setup!"
    $config.vcenterHost = Read-Host -Prompt "vCenter FQDN"
    $config.vcenterUser = Read-Host -Prompt "vCenter User"
    $config.vcenterPass = Read-Host -Prompt "vCenter Password" -AsSecureString
    $config.rubrikHost = Read-Host -Prompt "Rubrik FQDN"
    $config.rubrikClientId = Read-Host -Prompt "Rubrik Service Account Client ID"
    $config.rubrikSecret = Read-Host -Prompt "Rubrik Service Account Secret" -AsSecureString
    $config | Export-Clixml .\rubrik.xml
    exit
    }
else {
    $config = Import-Clixml .\rubrik.xml
}

$tagmount = $Tag.Split('\')[-1].Split('.')[0]

If(Test-Path .\$tagmount) {
    Write-Output "Found existing mount file: $tagmount."
    $newDriveLetter = Get-Content $tagmount
} else {
    ###
    # Connect to vCenter and Rubrik
    Connect-VIServer -Server $config.vcenterHost -Username $config.vcenterUser -Password (ConvertFrom-SecureStringToPlainText $config.vcenterPass)
    Connect-Rubrik -Server $config.rubrikHost -id $config.rubrikClientId -Secret (ConvertFrom-SecureStringToPlainText $config.rubrikSecret)

    ###
    # Tag Search
    $globalSearchResult = Invoke-RubrikRESTCall -api internal -Method POST -Endpoint "search/global" -Body @{regex = $Tag}

    Write-Output $globalSearchResult

    $snapshotTime = convertto-datetime($globalSearchResult.data[0].snapshotTime)
    $drive = $globalSearchResult.data[0].dirs.Split('/')[1]
    #$filePath = $globalSearchResult.data[0].dirs[0].Replace('/','\').Substring(1)
    $vmId = $globalSearchResult.data[0].snappableId
    $vmName = $globalSearchResult.data[0].snappableName

    ###
    # Get vmdk from drive letter
    $harddrives = Get-VM $vmName | Get-HardDisk
    $vmdk = ""
    foreach ($hd in $harddrives) {
        if (($hd | Get-VMGuestDisk).DiskPath.Contains($drive)) {
            $vmdk = $hd.ExtensionData.Backing.FileName
        }
    }

    Write-Output "VMDK File: $vmdk"

    ###
    # Get Snapshot
    $snapshot = Get-RubrikSnapshot -id $vmId -Date $snapshotTime

    ###
    # Get VMDK ID
    $virtualDisks = Invoke-RubrikRESTCall -api internal -method GET -endpoint "vmware/vm/virtual_disk" 
    $vmdkId = ($virtualDisks.data | Where-Object { $_.filename -contains $vmdk}).id

    Write-Output "Mounting $vmdkId to VM: $vmId"
    ###
    # Live Mount Disk Snapshot
    $liveMountPayload = @{
        targetVmId = $vmId;
        vmdkIds = @($vmdkId)
    }
    $mountStatus = Invoke-RubrikRESTCall -api internal -method POST -Endpoint "vmware/vm/snapshot/$($snapshot.id)/mount_disks" -body $liveMountPayload

    Get-RubrikRequest -id $mountStatus.id -Type vmware/vm -WaitForCompletion
    ### 
    # Activate Disk
    $disk = Get-Disk | Where-Object isOffline -eq $true
    $disk | Set-Disk -isOffline $false
    $newDriveLetter = ($disk | Get-Partition).driveLetter

    $newDriveLetter | Out-File $tagmount
}

###
# File copy operation
#$destinationPath = $Destination
#$sourcePath = $newDriveLetter + $filePath.Substring(1) + $fileName
$modifedSource = $Source.Split('\')[-1]

Write-Output "Copying $($newDriveLetter + $modifedSource) to $Destination"
Copy-Item ($newDriveLetter + $modifedSource) $Destination

###
# Unmount
# By default, mounts will be cleaned up after a single file restore.
# If this is a multi-file restore, you must use -PersistMount until the last file.
if (!$PersistMount) {
    Remove-RubrikMount -id $mountStatus.id
    Remove-Item $tagmount
}