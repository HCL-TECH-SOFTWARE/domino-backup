---
layout: default
title: .delta files 
nav_order: 5
description: ".delta file handling"
has_children: false
---


# Handling .delta files during backup and restore

Domino backup leverages the Domino backup C-API interface in the exact same way other backup applications.
When you bring a database into backup mode via **NSFBackupStart(..)**, changes to the database are captured in memory.
Once the file copy operation of a database is performed the backup for the NSF file is stopped via **NSFBackupStop(..)**.

## Database is not frozen for write I/O during backup
Database changes are still written to the original database during backup.
The backup API does **not** prevent changes to the database.
A file backup application has to allow file modifcations during backup (open file backup). But does not need to take care about any changes occurring during backup.

## Database change info captured in delta files
The changes in the database are captured by the Domino backup API and are returned to the backup application using "**NSFBackup..**"-operations.
Those changes *must* be applied to ensure the database is **consistent**!

There are two strategies applying database change information. 
- Apply delta to the backup file after backup
- Apply delta to the restore file at restore time

Applying the change information directly to the backup has advantages and is the preferred method to ensure the backup files are consistent on their own.  
By default if the backup file is available after restore Domino backup applies the change information directly to the backup file.  
But depending on your selected backup back-end it is not possible to apply the change information directly into the backup file.  
This is for example the case for snapshot backups where no writable backup file is available.
In this case the delta information has to be stored separately.

## .delta files
Change information is stored in .delta files and are backed up using the same integration used for NSF files.
An backup integration has to take care of storing and restoring .delta files.
Domino restore automatically takes care of restoring .delta files and apply the changes back into the restore database before removing the temporary *.delta file.

## .delta files during snapshot backups
Even snapshot backups make it less likely that changes occur during backup, a snapshot solution has to take care about change info and .delta files!
The change information has always to be applied to the database to ensure consistency!

## Strategies for backup and restore .delta files
The most common integration is a file copy operation. 
Usually you choose the same kind of integration which you might use for archive style transaction logs, because the files have a similar nature.
Another strategy would be to write them to another disk and create a snapshot of this disk.
The post backup operation can be used to trigger a snapshot or other operation to backup .delta files to another location.

Cleanup of .delta files stored using the NSF integration point will be automatically pruned when the referencing backup is pruned.
Note: In case .delta files are moved by this backup operation, you have to take care that the prune operation takes into account the files are moved.



