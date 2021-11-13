
# ----------------------------------------------------------------------
# Domino Backup Restore mount and unmount command for Windows and Linux
# ----------------------------------------------------------------------

# Copyright 2021 HCL America, Inc.
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
# ----------------------------------------------------------------------

# Commands:

# mount    : mounts a specified restore point. exmaple: "mount 20210601082959"
# unmount  : unmounts all restore points for requesting server
# check    : check configuration - also invoked from remote via SSH

# Configuration:

$DominoBackupConfigFile = "c:\dominobackup\dominobackup.cfg"
$CheckCommand   = $False
$UnmountCommand = $False
$RestoreClockSkewMinutes = 5


# Get parameters from SSH command

$RestoreCommand = -split $Env:SSH_ORIGINAL_COMMAND | select -first 1
$RestoreTarget  = -split $Env:SSH_CONNECTION | select -first 1

# Validate paramters

if ( $RestoreCommand -eq "mount" )
{
  $RestoreDate = -split $Env:SSH_ORIGINAL_COMMAND | select -skip 1 | select -first 1

  if ([string]::IsNullOrEmpty($RestoreDate))
  {
    Write-Host "Error: No restore date specified"
    return 1
  }

  if ([string]::IsNullOrEmpty($RestoreTarget))
  {
    Write-Host "Error: No restore target specified"
    return 1
  }
}
elseif ( $RestoreCommand -eq "unmount" )
{
  $UnmountCommand = $True
}
elseif ( $RestoreCommand -eq "check" )
{
  $RestoreDate = -split $Env:SSH_ORIGINAL_COMMAND | select -skip 1 | select -first 1
  $CheckCommand = $True
}
elseif ([string]::IsNullOrEmpty($RestoreCommand))
{
  Write-Host "Error: No command specified"
  Return 1
}
else
{
  Write-Host "Error: Invalid command specified"
  return 1
}

# Read configuration (JSON cfg file)

$DominoBackupCfg = Get-Content -Raw -Path $DominoBackupConfigFile | ConvertFrom-Json

$RestoreVmHost  = ""
$RestoreAccount = ""
$RestoreOS      = ""
$MountFUSE      = $False

foreach ($SearchCfg in $DominoBackupCfg)
{
  if ( $RestoreTarget -eq $SearchCfg.IpAddress) 
  {
    $RestoreVmHost  = $SearchCfg.VmHost
    $RestoreAccount = $SearchCfg.AccountName
    $RestoreOS      = $SearchCfg.OS

    if ( $SearchCfg.OS -eq "Linux")
    {
      $MountFUSE = $True
    }
  }
}

Write-Host
Write-Host "-------------------------------------------------------------------------------------"
Write-Host "Domino Backup for Veeam Restore"
Write-Host "-------------------------------------------------------------------------------------"
Write-Host "Command      : [$RestoreCommand]"
Write-Host "Date         : [$RestoreDate]"
Write-Host "Connect      : [$RestoreTarget]"
Write-Host "VM Host      : [$RestoreVmHost]"
Write-Host "RestoreOS    : [$RestoreOS]"
Write-Host "Account      : [$RestoreAccount]"
Write-Host "MountFUSE    : [$MountFUSE]"
Write-Host "ClockSkewMin : [$RestoreClockSkewMinutes]"
Write-Host "-------------------------------------------------------------------------------------"
Write-Host

if ([string]::IsNullOrEmpty($RestoreVmHost))
{
  Write-Host "Error: Host [$RestoreTarget] not found in configuration"
  return 1
}

if ( $CheckCommand -eq $True )
{
  if ([string]::IsNullOrEmpty($RestoreDate))
  {
    Write-Host "Error: No restore date specified"
  }
  else
  {
    $DominoBackupTime = [datetime]::ParseExact($RestoreDate + "Z", "yyyyMMddHHmmssZ", $null)
    Write-Host "DominoBackup UTC [$RestoreDate] in local time: [$DominoBackupTime]"
  }
  
  Get-WinSystemLocale | Select *
  Write-Host "-------------------------------------------------------------------------------------"
  Get-ChildItem Env: | %{"{0}={1}" -f $_.Name,$_.Value} | sort
  Write-Host "-------------------------------------------------------------------------------------"

  return 0
}

# Run unmount command if requested
if ( $UnmountCommand -eq $True )
{
  $RestoreSessions = Get-VBRPublishedBackupContentSession | Where-Object{ ($_.PublicationName -eq $RestoreVmHost)}

  if ( @($RestoreSessions).Count -eq 0 )
  {
    Write-Host "Info: No Backups Mounted"
    return 0
  }
    
  $BeforeUnmount = Get-Date

  Write-Host $BeforeUnmount.ToString() "Unmounting" @($RestoreSessions).Count "backup(s) ..."

  foreach ($Session in $RestoreSessions)
  {
    Unpublish-VBRBackupContent $Session
  }

  $AfterUnmount = Get-Date
  $Duration = $AfterUnmount - $BeforeUnmount

  Write-Host $AfterUnmount.ToString() "Unmount operation fishined (" $Duration.TotalSeconds.ToString("0.0") "seconds )"

  Write-Host "OK: Backup(s) unmounted"
  return 0
}

$TargetAdminCreds = get-vbrcredentials | where {$_.description -like $RestoreAccount}

if ( @($TargetAdminCreds).Count -eq 0 )
{
  Write-Host "Error: No admin account found"
  return 1
}

if ( @($TargetAdminCreds).Count -gt 1 )
{
  Write-Host "Error: More than admin acccount found"
  return 1
}

$OrigDominoBackupTime = [datetime]::ParseExact($RestoreDate.Trim() + "Z", "yyyyMMddHHmmssZ", $null)

if ([string]::IsNullOrEmpty($OrigDominoBackupTime))
{
  Write-Host "Error: Invalid restore date specified"
  return 1
}

$DominoBackupTime = $OrigDominoBackupTime.AddMinutes(-$RestoreClockSkewMinutes)

if ([string]::IsNullOrEmpty($DominoBackupTime))
{
  Write-Host "Error: Cannot convert timedate"
  return 1
}

Write-Host "Backup Time String       : $RestoreDate"
Write-Host "Backup Time (local time) : $OrigDominoBackupTime"
Write-Host "Backup Search Time       : $DominoBackupTime"
Write-Host "RestoreVmHost            : $RestoreVmHost"
Write-Host "Credentials used:        : $TargetAdminCreds"
Write-Host


$BeforeSearch = Get-Date

$RestorePoint = Get-VBRRestorePoint | Where-Object{ ($_.VMname -eq $RestoreVmHost) -and ($_.CreationTime -gt $DominoBackupTime)} | sort CreationTime |  Select-Object -First 1

$AfterSearch = Get-Date
$Duration = $AfterSearch - $BeforeSearch

Write-Host "Backup search:" $Duration.TotalSeconds.ToString("0.0") "seconds )"
Write-Host

if ( @($RestorePoint).Count -eq 0 )
{
  Write-Host "Error: No restore point found"
  return 1
}

if ( @($RestorePoint).Count -eq 1 )
{
  $BeforeMount = Get-Date

  Write-Host $BeforeMount.ToString() "Mounting backup restore point: " $RestorePoint.ID " Backup Time UTC: " $RestorePoint.CreationTimeUtc

  if ($MountFUSE)
  {
    $RestoreSession = Publish-VBRBackupContent -RestorePoint $RestorePoint -EnableFUSEProtocol -TargetServerName $RestoreTarget -TargetServerCredentials $TargetAdminCreds -Reason "Domino Restore operation"
  }
  else
  {
    $RestoreSession = Publish-VBRBackupContent -RestorePoint $RestorePoint -TargetServerName $RestoreTarget -TargetServerCredentials $TargetAdminCreds -Reason "Domino Restore operation"
  }

  $AfterMount = Get-Date
  $Duration = $AfterMount - $BeforeMount

  Write-Host $AfterMount.ToString() "Mount operation fishined (" $Duration.TotalSeconds.ToString("0.0") "seconds )"
  Write-Host
}
else
{
  Write-Host "Error: Multiple restore points found"
  return 1
}

if ( $RestoreSession -eq $null )
{
  Write-Host "Error: No restore session created"
  return 1
}

Write-Host "Backup Job Name :" $RestoreSession.BackupName 
Write-Host "Restore Point   :" $RestoreSession.RestorePoint 
Write-Host "VM Name         :" $RestoreSession.PublicationName
Write-Host

$RestoreContentInfo = Get-VBRPublishedBackupContentInfo -Session $RestoreSession

if ( $RestoreContentInfo -eq $null )
{
  Write-Host "Error: No restore content found"
  return 1
}

foreach ($RestoreContentType in $RestoreContentInfo)
{
  $RestoreDisks = $RestoreContentType.Disks

  Write-Host "-------------------------------------------------------------------------------------"
  Write-Host "Mounted Disk   :" $RestoreDisks.DiskName
  Write-Host "Mounted At     :" $RestoreDisks.MountPoints
  Write-Host "Mounted As     :" $RestoreDisks.Mode
  Write-Host "Available From :" $RestoreContentType.ServerIps "(Port:"  $RestoreContentType.ServerPort ")"
  Write-Host "Available Via  :" $RestoreDisks.AccessLink
  Write-Host "-------------------------------------------------------------------------------------"
  Write-Host
}

Write-Host "OK: Mount operations successfully completed"
Write-Host

return 0
