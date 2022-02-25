# Backup Retention explained

## Introduction

Domino Backup can be configured very flexible depending on the target backup environment. The standard configuration provided with the template is a simple file backup configuration.  
In the case of external backup application integrations more complex backup, restore and retention operations can be configured.  
Those back-ups, restore and prune operations need to be aligned with each other.

The configuration contains a retention day field `BackupRetentionDays`. This field is used to write retention information into every log and inventory document.

## Log documents

Log documents contain the following two fields calculated based on the configured `retention days`.

- `BackupRetentionDateTime` (example: 20.12.2021 12:42:42 CET)

- `BackupRetentionDateTimeText` (example: `2021209114242`)

## Inventory documents

`domoinobackup.nsf` contains one document per database in the backup, containing a `List` field with an entry for each backup.  
The list entry contains a long `|` separated list with information for the backup of the database.  
This includes the backup retention time calculated based on the retention days specified in the configuration.

## Custom retention database for a backup

The configured retention days can be overwritten on command-line via the `-g <number of days>` option.  
For example `load backup -g 11` to allow a custom backup retention time.

### Known issue with the backup retention configuration field in Domino 12.0

Domino 12.0 did not read the `BackupRetentionDays` correctly. This has been addressed in Domino 12.0.1.  
The `-g` switch was used as a workaround to specify the `BackupRetentionDays` field.

There is a remaining issue with the field when using the `Test Formula` action.  
The action is used to test formulas and inserts computed for display fields into the document with sample values. The `BackupRetentionDays` field is one of those sample fields and causes the field to be removed on write when the formula test action is used.

A workaround is to update the backup retention days field in the main tab before saving the document. This is currently required any time the formula test action is used.

An alternate workaround is to remove the field from the code logic in the design of the action button.

## Retention days for integrations

The retention days are passed to other backup integrations to allow backup retention for external backup repositories or backups integrations to align backup retention between backup repositories and the database inventory and logs.  
This option can be used if there is no direct integration option to prune backups and you want to pass backup retention information to the backup operation.

## Prune backups when the retention date is reached

A prune operation searches for backups older than the retention time. The retention removes the following data:

- Log documents
- Log files stored on disk
- Database inventory documents

When the inventory document for a database is processed the database prune operation is invoked if configured.  
And finally configured backup prune operations are executed.

Domino backup retention distincts two different types of operations:

- Prune DB command
- Prune backup command

In most cases, a prune operation per database should be configured. This is a 1:1 operation per backup database which is usually aligned with the backup operation leveraging the `Prune DB command`.  
The operation is used for databases and delta files. The same type of logic is used for transaction log files.

For snapshot backups and full backup integrations pruning a full backup can make sense in most cases.  
In this case, a `Prune backup command` can be configured to delete a full backup.


### How prune works internally

During backup a field `BackupRetentionDateTime` is calculated by the backup retention time currently configured is written.
This field is used for the backup retention. For inventory documents there is a corresponding entry in the `List` field.

In case of the missing wrong interpreted retention time, this data is not set and a prune will not work.

A work-around in Domino 12.0 is to specify the retention time manually using the `-g <number of days>` option.
This command-line option overwrites the field. This approach will only work for **new backups**.


### Domino 12.0.1 does not support a "Prune backup command" for "File" backup integrations

Beginning with Domino 12.0.1 the `Prune backup command` (prune complete backup with a directory delete file operation) cannot be used for `File` operations. An error is logged when trying to prune a complete backup with a `File` operation.  
This change has been introduced in 12.0.1 to prevent unwanted deletes of the wrong folder if configured incorrectly.  
Admins can replace the `Prune backup command` by specifying a `Prune DB command` to align it with the backup operation.  
For file backup integration the backup, restore and prune formulas are usually the same.  
But for more complex operations those operations might differ.

## Manual prune operations

Besides backup retention, Domino Backup also supports explicit prune operations by specifying the number of prune days.  
The command-line option used is `-p <number of days>` (example: load backup -p 7).  
Beginning with Domino 12.0.1 the prune operation `load backup -p` can be used to initiate a prune operation for

- Expired backups older than the backup retention time.
- Selected prune operations marked to prune manually (log documents in `dominobackup.nsf`).

### Selective prune operations

Selected prune operations are triggered by marking backup documents for deletion.  
Backup log documents contain the backup tag which is used to identify the inventory documents.

Inventory documents are used to identify the backup target to leverage prune operations to remove expired backup data.  
The operations depend on the backup back-end used. In the case of `File backup` operations, this is a file delete operation per file.

