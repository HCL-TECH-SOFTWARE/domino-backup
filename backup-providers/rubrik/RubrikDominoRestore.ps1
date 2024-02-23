#Requires -Modules VMware.VimAutomation.Core, Rubrik

param (
    [Parameter()]
    [String]$Tag,
    
    [Parameter()]
    [String]$Source,

    [Parameter()]
    [String]$Destination,

    [Parameter()]
    [Switch]$PersistMount
    )

# The time we get from global file search is in epoch ms. We need to convert it.
function convertto-datetime($epochms) {
    Get-Date (Get-Date ((Get-Date "1970-01-01 00:00:00.000Z") + ([TimeSpan]::FromMilliSeconds($epochms)))).ToUniversalTime() -UFormat '+%Y-%m-%dT%H:%M:%S.000Z'
}

# PowerShell 5.1 does not have the -AsPlainText attribute for converting from SecureString. This function compensates.
function ConvertFrom-SecureStringToPlainText ([System.Security.SecureString]$SecureString) {

    [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
    
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    )            
}

# First Time Setup
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

# Using the tag as a filename to keep track of any mounts we have. 
# The file will contain the drive letter where it's mounted, and the mount id so we can unmount later.
$tagmount = $Tag.Split('\')[-1].Split('.')[0]

If(Test-Path .\$tagmount) {
    Write-Output "Found existing mount file for this tag: $tagmount."
    $mountData = Get-Content .\$tagmount | ConvertFrom-Json
    $newDriveLetter = $mountData.driveLetter
    $mountId = $mountData.mountId
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

    Write-Output "Global Search Result:"
    Write-Output "Drive: $drive"
    Write-Output "vmId: $vmId"
    Write-Output "vmName: $vmName"

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

    Write-Output "Mounting VMDK $vmdkId to VM: $vmId"
    ###
    # Live Mount Disk Snapshot
    $liveMountPayload = @{
        targetVmId = $vmId;
        vmdkIds = @($vmdkId)
    }
    $mountStatus = Invoke-RubrikRESTCall -api internal -method POST -Endpoint "vmware/vm/snapshot/$($snapshot.id)/mount_disks" -body $liveMountPayload

    Get-RubrikRequest -id $mountStatus.id -Type vmware/vm -WaitForCompletion
    $mountId = (Get-RubrikMount | Where-Object mountRequestId -eq $mountStatus.id).id
    ### 
    # Activate Disk
    $disk = Get-Disk | Where-Object isOffline -eq $true
    $disk | Set-Disk -isOffline $false
    $newDriveLetter = ($disk | Get-Partition).driveLetter + ":"
    Get-Volume -DriveLetter $newDriveLetter.split(":")[0] | Set-Volume -NewFileSystemLabel "Restore-$tagmount"

    # Save mount id and drive letter to file
    $mountData = @{driveLetter = $newDriveLetter; mountId = $mountId}
    $mountData | ConvertTo-Json | Out-File $tagmount

    Disconnect-VIServer -Force -Confirm:$false
    Disconnect-Rubrik
}

###
# File copy operation
#$destinationPath = $Destination
#$sourcePath = $newDriveLetter + $filePath.Substring(1) + $fileName
$modifedSource = $Source.Split(':')[-1]

Write-Output "Copying $($newDriveLetter + $modifedSource) to $Destination"
New-Item $Destination -Force
Copy-Item (Join-Path $newDriveLetter $modifedSource) $Destination -Force

###
# Unmount
# By default, mounts will be cleaned up after a single file restore.
# If this is a multi-file restore, you must use -PersistMount until the last file.
if (!$PersistMount) {
    Connect-Rubrik -Server $config.rubrikHost -id $config.rubrikClientId -Secret (ConvertFrom-SecureStringToPlainText $config.rubrikSecret)
    Remove-RubrikMount -id $mountId
    Remove-Item $tagmount
    Disconnect-Rubrik
}

