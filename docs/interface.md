---
layout: default
title: Configuration Interface
nav_order: 2
description: "HCL Domino Backup Configuration Interface"
has_children: false
---


# Server Configuration

A server configuration is the main configuration for all backup/restore/prune operations.
Each server has exactly one configuration which could be either a dedicated server configuration, a default configuration.
This becomes important when you share a configuration database between multiple servers.

## Main Tab

### Status

Enables and disables a configuration document

### Config Type

There are different configuration types:

a.) Server
Defines an explicit server

b.) Default
Default configuration which can be defined per platform.

### Platform

For default configurations a platform can be defined.
The configuration comes with a set of default configurations per platforms.
If you need different configurations for different server, you have to use a NamedConfiguration or per server configuration.

### ServerName

This field is only available for a server specific configuration and defines the server name.

### Node Name

Optional note name for a server specific configuration. 
By default the note name is the CN of the Domino server name. Spaces are converted to underscores.

If you want to change the note name for a global or named configuration use the following notes.ini parameter nshback_node

### Excluded Databases (Pattern)

This parameter allows to define exclude patterns.
Those exclude entries are using regular expressions as defined for @matches operations.
If you want to exclude a directory you have to add a wild-card parameter like mydirectory/* 

### Backup Target Dir Databases

Directory defining the backup directory for NSF files.
This parameter will be assigned to the  BackupTargetDir variable and can be used in database backup/restore/prune command formulas

### Backup Target Dir Translog

Directory defining the backup directory for Translog TXN files.
This parameter will be assigned to the  BackupTargetDir variable and can be used in translog backup/restore/prune command formulas

### Backup Log Dir

Directory defining the log file directory.

### Backup Target Dir Files

Directory defining the backup directory for files backed up using the file backup functionality.
This parameter will be assigned to the  BackupTargetDir variable and can be used file backup command formulas

### Backup Retention (Days)

Defines the default restore retention days set for a restore operation

### Script Directory

Defines the script directory used for all command scripts if a relative path is used.

### Description

Description shows in the configuration view

### Comments

Comment field for additional comments

## Backup Tab

### Backup DB Command

Command for NSF and delta file backup operations

### Backup Translog Command

Command for Translog backup operations

### Backup disable direct Apply

In case of a file backup target where the NSF file can be accessed after the backup operation, the delta data is automatically applied and no delta file needs to be written. The database is in a consistent state and needs no recovery. This option disables this functionality.

### Pre-Backup Command

This command will be executed before the backup is started

### Post-Backup Command

This command will be executed before the backup is started

### Backup Log File

Defines if the type of logging used. The name of the log file is defined by server name, node. mode and start time.

- **None** - No log file
- **Disk** - Write a log file to the log file directory
- **Attachment** - Write an attachment to the backup log document
- **Disk&Attachment** - Write a log file and attach it to the log document as well

### Backup OK String

Backup result string matched for **successful** backup

### Backup Error String

Backup result string matched for **unsuccessful** backup

If error is matched the result is always error.
If OK String is set the OK string must be matched for a successful operation

### Snapshot Tab

The snapshot backup mode can be used in two different scenarios

- Full snapshot of a file-system
- Leverage snapshot technology like Microsoft VSS to bring a Domino server into consistent state before performing a regular file-system backup

For a snapshot assisted file backup Domino!Backup writes a file-list of files to be backed up.
This file-list is generated in Backup Snapshot Command state and the absolute file-name is passed to the first cmd #1 parameter or PhysicalFileName when using formula commands.

For a full snapshot you should disable generating the file-list.

The file-list is passed to the command and needs to be deleted once the operation completes.

### Backup Snapshot Mode

Enable Snapshot mode for backup operations.
This will be used for full backups and as well for incremental and delta backups.

### Snapshot Start Command

This command is used to start a snapshot after all database have been set into backup mode.
For example when leveraging a VSS snapshot on Windows

### Backup Snapshot Command

After the snapshot has been completed, all databases are switched back to normal operations.
This might lead to DELTA files for databases (same name than the database with the extension .DELTA appended).
Those files will backed up with the **Backup DB Command** command.

In this stage the backup operation for the snapshot should be invoked.
This will allow not Domino aware backup applications to backup all databases in one backup step.
At the end of the backup operation, the script should also remove the snapshot.

You can also combine **DELTA file backup** to another disk with the **Backup DB Command** command and backup **DELTA** files along with the snapshot to have all data in one backup set.

### Backup Snapshot File List

By default the snapshot mode generates a file-list of databases to backup.
This is useful for incremental/delta backups where the the generated snapshot does not need to be backed up completely.
But it is also useful for full backup with excludes.

On the other side in many cases a full backup should backup the whole data directory with all files in snapshot mode.

This allows to create a snapshot and pass a list of files to be backed up to a backup application which isn't Domino aware.

The file-list by default only contains the full physical path. But it could be useful to also have the logical path from the data directory.
When specifying this option both will be added with a default separator of ";".

- Disabled
- PhysicalPath
- Physical&LogicalPath

### Snapshot Start OK String

Backup result string matched for successful operation

### Snapshot Start Error String

Backup result string matched for **unsuccessful** backup

If error is matched the result is always error.
If OK String is set the OK string must be matched for a successful operation

### Backup Snapshot OK String

Backup result string matched for successful operation

### Backup Snapshot Error String

Backup result string matched for **unsuccessful** backup

If error is matched the result is always error.
If OK String is set the OK string must be matched for a successful operation

## Restore Tab

### Restore Db Command

Command for NSFand delta file restore operations

### Restore Translog Command

Command for Translog restore operations

### Restore Snapshot Command

Command for Snapshot restore operations.
This option is command is only used for explicit snapshot operations.
If you enable snapshots for normal backups, the normal restore commands are used.
For *.DELTA files always the normal restore command is used.

This command allows to use different logic for snapshot operations than for normal backup operations.

### Restore OK String

Restore string matched for a successful restore operation

### Restore Error String

Restore string matched for an **unsuccessful** restore operation

If error is matched the result is always error.
If OK String is set the OK string must be matched for a successful operation

### Restore DAOS Command

Command for build-in DAOS restore operations

### Restore DAOS is single File Cmd

Defines if the restore command will be executed per NLO file or for a full text file containing all NLOs

### Restore Target Dir DAOS

Defines the DAOS directory to restore into if the DAOS directory is not set.
By default notes.ini **DAOSBasePath** is used.

## Notification Tab

This tabe defines the status and notification options. You can define which events should be notified and also the notification recipient.
Beside the standard operations, there are specific @formula options.

### Notification for

Defines which events should be notified.

- Errors
- Warnings
- OK

### Backup Notification Recipient (or Formula)

This entry either defines a recipient by string or by formula executed on the log document.

### Backup Status Formula

By default an internal logic is used to determine the status.
This formula is executed on the log document and allows specific status evaluation.

Result of the formula should be:

- **O** = OK
- **W** = Warning
- **E** = Error

### Backup Report Sender

By default the server name is used a the sender.
This settings defines the Notes sender.

### Backup Report Internet Sender

Defines the internet sender optionally used

### Backup Report Agent Formula

You can run an agent on the log document to define your specific reporting logic

### Backup Notification append Doc

Defines if the original log document is appended (without attachment)

### Check Backup Week Days

Defines at which weekdays a backup check should be performed.
An optional agent checks the last backup on those days.

### Check Backup Timerange

Defines the backup time range within the backup agent isn't checking the backup status.
Backup status should be only checked after outside this interval.

### Prune Tab

Prune operations are used to remove old backup files.
Each prune operation removes the files matching the backup operation.

### Prune Backup Command

Command to prune a whole backup.
This is useful when the backup can be removed by a single command.
For example when a full directory can be deleted.

### Prune Db Command

Command to prune a single database and delta files

### Prune Translog Command

Command to prune translog files

### Prune Snapshot Command

Command to prune a snapshot backup

### Prune OK String

Prune string matched for a successful prune operation

### Prune Error String

Prune string matched for a **unsuccessful** prune operation

If error is matched the result is always error.
If OK String is set the OK string must be matched for a successful operation

### Advanced Tab

### Backup Result String

Backup result string matched to get the backup result.
The resulting file name is used to apply delta files.

### Backup Ref String

This string is matched for reference results. 
Those references can be used for backup restore operations to identify backups

### Notification Form

This optional form can be used to overwrite the notification form used to format the notification message for NSF backups

### Notification Form Translog

This optional form can be used to overwrite the notification form used to format the notification message for Translog backups

### Restore DB Title Formula

Formula used when specifying the "**Restore DB Title Formula**" restore option.
The formula is executed on the restore request document.

### Backup keep empty Delta Files

A delta backup file is holding the delta backup information created by NSF backup operations.
This option would create empty delta file if not delta occurs. This can be useful for specific backup back-ends

### 3rd Party Date Formula

Allows to use your specific formatted date for a restore operation.
The formula is executed against the restore document.

