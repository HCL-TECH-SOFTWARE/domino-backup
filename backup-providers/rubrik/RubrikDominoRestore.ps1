#Requires -Modules VMware.VimAutomation.Core, Rubrik

### Parameter positions dictated by Domino Backup. This does not appear to be documented anywhere.
param (
    # Domino tag file path (e.g. 20250101.tag)
    [Parameter(Position=6)]
    [ValidateNotNullOrEmpty()]
    [String]$Tag,
    
    # Source file path to restore (e.g. E:\notes\data\example.log)
    [Parameter(Position=0)]
    [String]$Source,

    # Destination file path to restore (e.g. E:\notes\restore\example.log)
    [Parameter(Position=8)]
    [String]$Destination,

    # Unmount the live-mount associated with the provided tag
    [Parameter()]
    [Switch]$RemoveMount
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

function restoreFailed() {
    Write-Output "RESTORE FAILED"
    Exit 1
}


$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$CredentialFile = "rubrik.xml"
$CredentialPath = Join-Path -Path $ScriptDir -ChildPath $CredentialFile

# First Time Setup
if(!(Test-Path $CredentialPath)) {
    $config = @{}
    Write-Output "Welcome to the first time setup!"
    $config.vcenterHost = Read-Host -Prompt "vCenter FQDN"
    $config.vcenterUser = Read-Host -Prompt "vCenter User"
    $config.vcenterPass = Read-Host -Prompt "vCenter Password" -AsSecureString
    $config.rubrikHost = Read-Host -Prompt "Rubrik FQDN"
    $config.rubrikClientId = Read-Host -Prompt "Rubrik Service Account Client ID"
    $config.rubrikSecret = Read-Host -Prompt "Rubrik Service Account Secret" -AsSecureString
    $config | Export-Clixml $CredentialPath
    exit
    }
else {
    $config = Import-Clixml $CredentialPath
}

# The following operations are for managing live-mount state. We keep a state file named after the $Tag parameter. 
# The live mounts are persisted across individual file restores, as there could be multiple files to be restored from the same live-mount.
# This greatly increases efficiency as we would otherwise have to perform the same live-mount multiple times.
$TagPath = Join-Path -Path $ScriptDir -ChildPath $Tag

# If a tag exists and we want to remove the mount, then call Rubrik to perform the unmount, and delete the state file.
If((Test-Path $TagPath) -and $RemoveMount.IsPresent) {
    $mountData = Get-Content $TagPath | ConvertFrom-Json
    $newDriveLetter = $mountData.driveLetter
    $mountId = $mountData.mountId
    Write-Output "Removing Rubrik Live Mount $mountId located on $newDriveLetter"
    Connect-Rubrik -Server $config.rubrikHost -id $config.rubrikClientId -Secret (ConvertFrom-SecureStringToPlainText $config.rubrikSecret)
    Remove-Item $TagPath
    Remove-RubrikMount -id $mountId -ErrorAction SilentlyContinue
    Disconnect-Rubrik
    Exit 0
}

# If we find existing mount state for this tag, use it and just do the file copy from the already mounted snapshot. 
# Otherwise, Connect to Rubrik and vCenter, find the snap of the indexed tag file, perform the live-mount, and assign a drive letter.
If(Test-Path .\$TagPath) {
    Write-Output "Found existing mount file for this tag: $Tag."
    $mountData = Get-Content .\$TagPath | ConvertFrom-Json
    $newDriveLetter = $mountData.driveLetter
    $mountId = $mountData.mountId
} else {
    ###
    # Connect to vCenter and Rubrik Cluster
    try {
        Connect-VIServer -Server $config.vcenterHost -Username $config.vcenterUser -Password (ConvertFrom-SecureStringToPlainText $config.vcenterPass)
    }
    catch {
        Write-Error "Connection to vCenter failed: $($PSItem.Exception.Message)" -ErrorAction Stop
        restoreFailed
    }
    try {
        Connect-Rubrik -Server $config.rubrikHost -id $config.rubrikClientId -Secret (ConvertFrom-SecureStringToPlainText $config.rubrikSecret)
    }
    catch {
        Write-Error "Connection to Rubrik Cluster failed: $($PSItem.Exception.Message)" -ErrorAction Stop
        restoreFailed
    }
    
    # Tag Search
    # We can only search for tag files after the snapshot has been indexed.
    $tagFileName = "dominobackup_$Tag.tag"
    Write-Output "Performing global search for file named $tagFileName..."
    $globalSearchResult = Invoke-RubrikRESTCall -api internal -Method POST -Endpoint "search/global" -Body @{regex = $tagFileName}
    Write-Output $globalSearchResult
    
    if ($globalSearchResult.total -eq 0) {
        Write-Error -Message "No snapshot found with tag $Tag"
        restoreFailed
    }

    $snapshotTime = convertto-datetime($globalSearchResult.data[0].snapshotTime)
    $drive = $globalSearchResult.data[0].dirs.Split('/')[1]
    $vmId = $globalSearchResult.data[0].snappableId
    $vmName = $globalSearchResult.data[0].snappableName

    Write-Output "Global Search Result:"
    Write-Output "Drive: $drive"
    Write-Output "vmId: $vmId"
    Write-Output "vmName: $vmName"

    # Get vmdk from drive letter
    # This requires VMware Tools
    $harddrives = Get-VM $vmName | Get-HardDisk
    $vmdk = ""
    foreach ($hd in $harddrives) {
        if (($hd | Get-VMGuestDisk).DiskPath.Contains($drive)) {
            $vmdk = $hd.ExtensionData.Backing.FileName
        }
    }

    Write-Output "VMDK File: $vmdk"

    # Get Snapshot
    $snapshot = Get-RubrikSnapshot -id $vmId -Date $snapshotTime

    # Get VMDK ID
    $virtualDisks = Invoke-RubrikRESTCall -api internal -method GET -endpoint "vmware/vm/virtual_disk" 
    $vmdkId = ($virtualDisks.data | Where-Object { $_.filename -contains $vmdk}).id

    Write-Output "Mounting VMDK $vmdkId to VM: $vmId"

    # Live Mount Disk Snapshot
    $liveMountPayload = @{
        targetVmId = $vmId;
        vmdkIds = @($vmdkId)
    }
    $mountStatus = Invoke-RubrikRESTCall -api internal -method POST -Endpoint "vmware/vm/snapshot/$($snapshot.id)/mount_disks" -body $liveMountPayload

    Get-RubrikRequest -id $mountStatus.id -Type vmware/vm -WaitForCompletion
    $mountId = (Get-RubrikMount | Where-Object mountRequestId -eq $mountStatus.id).id
    
    # Activate Disk
    $disk = Get-Disk | Where-Object isOffline -eq $true
    $disk | Set-Disk -isOffline $false
    $newDriveLetter = ($disk | Get-Partition | Where-Object {$_.DriveLetter -ne [char]"`0"}).driveLetter + ":"

    # Save mount id and drive letter to file
    $mountData = @{driveLetter = $newDriveLetter; mountId = $mountId}
    $mountData | ConvertTo-Json | Out-File $TagPath

    Disconnect-VIServer -Force -Confirm:$false
    Disconnect-Rubrik
}

###
# File copy operation
$modifedSource = $Source.Split(':')[-1]

$mountedSource = Join-Path $newDriveLetter $modifedSource
if (!(Test-Path $mountedSource)) {
    Write-Error "The source file does not exist on this live-mount: $mountedSource"
    Exit 1
}
Write-Output "Copying $mountedSource to $Destination"
try {
    New-Item $Destination -Force -ErrorAction Stop
    Copy-Item (Join-Path $newDriveLetter $modifedSource) $Destination -Force -ErrorAction Stop
    Write-Output "RESTORE SUCCEEDED"
}
catch {
    Write-Error "An error occurred during the restore operation: $($_.Exception.Message)"
    restoreFailed
}