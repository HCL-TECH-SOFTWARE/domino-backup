---
layout: default
title: "Veeam Domino Integration"
nav_order: 2
parent: Veeam
grand_parent: "Backup Providers"
description: "HCL Domino Backup Veeam Integration"
---

## Domino V12 Veeam Backup and Replication Integration

## Introduction

The Domino Backup integration for Veeam Backup and Replication provides integrated end to end backup and restore experiences.  
Veeam Backup and Replication uses application aware processing integrating with the new Domino V12 Backup leveraging pre-freeze and post-thaw scripts.
This Domino V12 Backup integration provides full Domino application support bringing all databases into an consistent state (Domino backup API) in combination with Veeam snapshot technology.

- Backup operations are scheduled and initiated by Veeam Backup and Replication.

- Domino restore operations are initiated by a Domino administrator leveraging the feature rich Domino based restore UI in the Domino Backup database `dominobackup.nsf`.

This integration is supported on Windows64 and Linux64.

## High Level Architecture

### Domino Backup

Backups are initiated by Veeam Backup and Replication leveraging `pre-freeze` and `post-thaw` scripts to allow application aware processing.
Those scripts are executed on the Domino server before and after a Veeam snapshot and run Domino scripts installed on the Domino server to allow integrated Domino Backup operations.

- The `pre-freeze` script triggers a Domino Backup snapshot operation to bring all Domino databases into backup mode.

- The `post-thaw` script triggers Domino Backup to bring all databases back from backup mode into normal operation mode and backup delta data accumulated while databases have been in backup mode.

This integration allows full and incremental backups with Veeam Backup and Replication. The inventory of backups is listed in the Veeam repository ("`restore points`") and also in the Domino backup database (`dominobackup.nsf`). The restore operation is always initiated by the Domino administrator in the Domino native UI for restore leveraging the database inventory on the Domino side.

### Domino Restore

Restore operations are fully integrated and initiated in the Domino Backup `dominobackup.nsf` database.
A Domino admin creates a restore request for databases.

Request are performed by the restore server task on the Domino server
The restore task leverages scripts (batch/shell script) to

- Find the right restore point
- Mount a restore point to the Domino server
- Copy databases (nsf/ntf/box) and backup delta (\*.DELTA files) from a Veeam backup into the Domino data directory.

The Domino restore server task takes care of bringing the database on-line and performs post processing like disable replication, change replia-id, restore documents and folders into the original database.

### Backup Retention

In this scenario Veeam ensures the retention of backup data as defined in the backup job and Domino maintains the inventory, log database retention and delta file retention via "prune" operations.

## Mount and Restore Operation Implementation

The mount operation requires direct communication with the Veeam Backup and Restore server and leverages the Veeam PowerShell command line interface to control the Veeam Backup and Replication server.

- A Powershell script on the Veeam server identifies and mounts the right restore point to perform mount operations on the Domino server to allow Domino to restore databases.

- The mount request is initiated by a Domino restore script triggered by the restore server task on the Domino server requesting the restore.

- The mount operation on the traget Domino machine uses Admin credentials already defined for application aware scripts ( `pre-freeze` & `post-thaw` ).

- The restore script on the Domino server machine finds the desired database in the mounted restore point and copies the database to the requested restore location

- And finally, Domino sends an unmount request for the restore mount to the Veeam server.

## Windows OpenSSH Server Configuration

The communication between the Domino servers and the Veeam Backup and Replication server leverages the Secure Shell protocol (ssh) authenticated via private/public key security. User/Password authentication is disabled by design.

This integration provides a safe and reliable cross platform communication channel and doesn't require servers to belong to the same Windows domain or PowerShell remote execution.
All Domino servers can use the same SSH key or individual keys for authentication.

### Public/Private Key Authentication

This integration leverages the Microsoft OpenSSH with a restricted configuration only allowing restore mount and unmount operations for each Domino server.  
A SSH key is configured via `.ssh/authorized_keys` for a Windows user account with Veeam restore operator permissions.

The command execution is restricted to a single mount/unmount PowerShell script via `authorized_keys` configuration to allow tight control of requested operations.

### OpenSSH Server Configuration

Install Microsoft OpenSSL Server with the following type of configuration

The open OpenSSL server has been tested with Windows 10 and Windows 2019 Server on the Veeam Backup and Replication server.
The installation instruction contains step by step instructions including references to the original Microsoft documentation for the OpenSSH server.

### Configurating User and Access

A user with with Veeam restore administrator permissions is required to invoke the PowerShell operations.  
The PowerShell script can distinguish between different servers by requesting IP address (environment variable `SSH_CONNECTION`) and will only map the configured VM to the requesting host.

In case separate keys are required by platform or server, multiple entries can be added to the authorized_key file as shown in the example below. The command request is passed to the PowerShell script via `SSH_ORIGINAL_COMMAND` environment variable.

Example for a user "domino"

`C:\Users\domino\.ssh\authorized_keys`

```
command="powershell.exe c:/domino/veeam/DominoRestore.ps1" ssh-ed25519 AAAAC3NzaC1lZD...
command="powershell.exe c:/domino/veeam/DominoRestore.ps1" ssh-rsa AAAAB3NzaC1yc2EAAA...
```

`Note:` OpenSSH requires strict permission on the authorizied_keys. Make sure the file is only readable by admins and the user

## Configuration File

An agent-less backup leveraging backup via a virtualization back-end like `VMware` or `Hyper-V` does not provide a direct mapping between the guest operation systems and their IP addresses.
The restore operation triggered from the Domino server only provides the IP address of the requesting server and the requested restore time.

Therefore for mapping and verifying restore requests this integration leverages a central configuration file in JSON format on the Backup and Replication server.

The configuration defines which Domino server can perform mount/unmount operations (in addition to the SSH public/private key authentication) and also ensures each server can only restore from it's own restore points.

For access control and mapping of Domino servers to the corresponding VMs a configuration file is used.  
The file is located by default in the following location and is read by the PowerShell script.

`c:/dominobackup/dominobackup.cfg`

The configuration contains the following information:

- IP address
- Veeam admin credential description to find the right credential for mounting
- Operating system (Linux|windows)
- Name of the operating system VM/host (the name used by Veeam to identify the virtual machine)

Example: dominobackup.cfg

```
[
  {
    "VmHost"      : "Domino01-Linux",
    "IpAddress"   : "192.168.96.236",
    "AccountName" : "Domin-root",
    "OS"          : "Linux"
  },
  {
    "VmHost"      : "Domino02-Win2019",
    "IpAddress"   : "192.168.96.220",
    "AccountName" : "Domino-WinAdmin",
    "OS"          : "Windows"
  }
]
```

### Pre-Freeze/Post Thaw Scripts for Windows and Linux

A Veeam backup application copies and executes the `pre-freeze` and `post-thaw` to a temporary location on the guest machine. Those scripts are configured to call the corresponding Domino Backup integration scripts by the Veeam server.

Add following scripts to the backup job configuration. The scripts point to the default script location on the Domino server. To custom install directories adjust the scripts accordingly.

Windows

```
c:/scripts/domino/windows/pre-freeze.sh
c:/scripts/domino/windows/post-thaw.sh
```

Linux

```
c:/scripts/domino/linux/pre-freeze.sh
c:/scripts/domino/linux/post-thaw.sh
```

### Domino Server Backup Configuration

Domino Backup integrates with Veeam for backup and restore operation leveraging batch (Windows) and shell scripts (Linux).

The scripts should be copied to the following directories. Ensure the files are executable by the Domino user (usually: notes) and root.

- Windows:
  `c:/Program Files/HCL/Domino/backup/veeam`

- Linux:
  `/opt/hcl/domino/backup/veeam`

The DXL configuration file provided in this repository contains the corresponding configuration and can be imported directly into the `dominobackup.nsf` database.  
For custom installation directories adjust the script directory in the configuraiton accordingly.

The following scripts are used for integration:

- `backup_domino_snapshot.cmd/sh`  
  Veeam snapshot script invoked by the pre-freeze script to start Domino backup in snapshot mode  
  (brings databases into consistent/freeze state before a Veeam snapshot is started)

- `backup_snapshot_start.cmd/sh`  
  Helper script started by Domino Backup to indicate databases are in consistent state  
  (communicates the status back to `backup_domino_snapshot.cmd/sh`)

- `backup_domino_snapshot_done.cmd/sh`  
  Veeam snapshot script invoked by the `post-thaw` script to signal the snapshot has been created

- `backup_snapshot.cmd/sh`  
  Helper script started by Domino Backup to capture post snapshot operations.  
  The script waits until Veeam has performed a snapshot and communicated back via `post-thwa` script to Domino.

- `backup_post.cmd/sh`  
  Script executed when the backup is finished on the Domino server side to allow post processing.  
  Future integration point for scheduling backup of delta files created during backup.

- `prune_backup.cmd/sh`  
  Script to prune backup delta files and logs

- `restore_db.cmd/sh`  
  Restore script to mount Veem backups, find/copy databases and delta files.  
  Invokes a restore mount/unmount request via SSH connection to the Veeam Backup and Replication server.

- `backup_translog.cmd/sh`  
  Script to backup a translog extend -- Not implemented yet

- `prune_translog.cmd/sh`  
  Script to prune transaction log files and logs -- Not implemented yet

- `restore_translog.cmd/sh`  
  Restore script for translog extends -- Not implemented yet

### Special Consideration and Settings

The `BackupStartDT` is always stored in UTC time and will be converted by the PowerShell script.  
Domino and Veeam times need to be in sync. To ensure poper restore operations the clock skew time parameter `RestoreClockSkewMinutes` can be set in the PowerShell script.

## Technical Background

### Sequence of Backup Operations

A Veeam backup job is scheduled for backup operations.  
The integration into Domino Backup is implemented via `pre-freeze` and `post-thaw` scripts as described below.

- Veeam Backup Job --> `pre-freeze.cmd` --> `backup_domino_snapshot.cmd/sh` --> `load backup -s` (Domino Backup)

- Domino Backup --> `backup_snapshot_start.cmd/sh` --> Brings all databases into backup mode and writes status file to confirm Domino is in snapshot backup mode

- Domino Backup --> `backup_snapshot.cmd/sh` --> Waits until snapshot status is confirmed

- Veeam Backup Job "Snapshot Created" --> `post-thaw.cmd` --> `backup_domino_snapshot_done.cmd/sh` --> sets snapshot status to "DONE" to terminate the `backup_snapshot.cmd/sh` and return control to Domino Backup

- Domino Backup --> Gets all databases back from backup mode and stores delta files if needed --> `backup_post.cmd/sh` (currently no special operations)

### Sequence of Restore Operations

Domino databases can be restored directly from the Domino Backup database (dominobackup.nsf). The integration used, leverages the Veeam Powershell integration on the Veeam Backup and replication server.

The restore operation leverages SSH with public/private key authentication with the Veeam server.

- Domino Restore server task (restore) starts `restore_db.cmd/sh` on the Domino server.

- The `restore_db.cmd/sh` invokes a restore operation requesting a backup for a defined backup time (`BackupStartDT`)

- The script sends a restore mount request with the desired backup date via `BackupStartDT` variable via SSH to the Veeam Backup and Replication server.

- On the Veeam server a PowerShell script is started to find the matching restore point and mounts it to the Domino server

- `restore_db.cmd/sh` leverages the mount and searches for the right database to restore

- The restore operation looks for a backup timestamp tag file (e.g. `/local/notesdata/dominobackup_20210514112233.tag`) added by Domino Backup to the Notes data directory before the snapshot was taken to identify matching backup location and to ensure the right backup was mounted.

- Once located the script copies the files to the target location (usually the restore directory with a .DAD extension)

- Finally the restore script sends an unmount request for the restore point to the Veeam server
