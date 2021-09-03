---
layout: default
title: Backup to file system 
nav_order: 2
description: "HCL Domino Backup to a file system"
has_children: false
---


# Storage back-end file copy implementation

By default Domino Backup is configured to perform a file copy backup to a location you define in the main configuration tab.  
But running a full backup on all your NSF files to a central location every night doesn't really scale from resource usage point of view.

If you have **de-duplicating** and **compression** storage, it can still be a valid option also for larger environments.

There are many solutions and even the free [OpenZFS](https://openzfs.github.io/openzfs-docs/) file-system does offer dramatic storage reduction for nightly backup on Domino databases if your maintenance operations are properly aligned as explained below.

Beside OpenZFS there is for example also the backup vendor Cohesity offering a file share (internally called: view) to backup data compressed and deduplicated.

You can have similar storage optimization also on storage appliances from NetApp and on other storage platforms.

One very interesting applicance which can run on also on existing infrastucture is [TrueNAS/FreeNAS](https://www.truenas.com/).  
The platform uses OpenZFS as the base with all the storage optimization benefits.

Deduplication and compression allows a simple backup approach without duplicating the NSF storage every night.  
But special care needs to be taking to for Domino storage optimization.

One of the advantages file backup integrations is that delta files created during backup, can be automatically applied to the databases.
And the resulting backup is consistent on it's own -- without the need of a restore operation.

# Domino storage optimization first

Domino provides many storage optimization option to ensure the nightly backup size is reduced.
Storage optimization not only reduces the backup time but also provides better performance.

## Database compression

Database design and document compression is integrated into the Domino on disk structure ( ODS ) since Version 8.x.  
Enabling compression reduces the database design and document data up to 50%.

Enable compression using the following compact options.  
If executed without a copy style the options are enabled for new or updated documents.  
Existing database notes are compressed leveraging a copy style compact.

```
load compact -n -v 
```

## Domino Attachment Object Serivce ( DAOS )

DAOS allows you to move attachments out of the NSF files. This have multiple advanges also from backup point of view.

- Reduce the size of the NSF file dramatically.
  Up to 70% of a mail database can be moved to DAOS.
  This would reduce the requiremends for NSF backup by the same amount

- DAOS creates a hash of the attachment object. Multiple attachments with the same hash are deduplicated -- which leads to 30-40% storage reduction in most environments.

- DAOS files don't need a Domino backup agent for backup. Any backup solution can backup DAOS files on-line. They are written once and only read afterwards.

- The newer DAOS T2 offers additional optimization and since Domino V12 also allows deduplication for data from multiple servers. However DAOS T2 brings new challenges for synchronizing backups and restore operations.  
DAOS T2 can be used to move older attachment data to less expensive storage.

```
load compact -DAOS ON
```

A compact without copy-style will not move attachments to the DAOS store. But new attachments are automatically stored in DAOS. Combine this option with a scheduled `DBMT` compact.

### Domino restore DAOS

Backup for the DAOS reposity requires a separate solution. But the restore operations can be integrated into a Domino Backup restore operation.

## Considerations for compact

### DBMT

The Domino database maintenance tool "DBMT" is the best option for database compacts.  
It can be also used to compress design & documents and move attachments to the DAOS repository.  
This means you can use a two step approach when enabling database storage setting.

- Enable the setting via `compact` task as shown above
- Run `dbmt` which always compacts the database in copy style mode to compress or move data

DBMT comes with another advantage. It calculates the new databases size and pre-allocates the new database file in one step.  
This gives the file-system the opportunity to optimize disk alignment. After a DBMT compact the database is defragmented on file-system level as well.

### Run compact once per week before the backup

Specially in combination with archive style transaction log compacts should only performed if needed.  
Each compact will change the `DBIID` of a database and requires a new backup of the database.

But also when using compression and deduplication for backup compacting too often, causes a lot of backup storage overhead.

## Special considerations for snapshot backups

Separate the NSF data to backup from the remaining part of the server data to a different volume to keep the snapshot small.

The following parts should be separated from the NSF data.  
On larger servers it usually makes sense to store each of them separately from each other on different disks.

Translog and logs often are stored on the system disk to avoid too many separate disks.

- Transaction log
- DAOS
- FT files
- NIFNSF data
- Logs

## DAOS backup considerations

DAOS files are written once and will never be modified. A DAOS backup can be invoked independent from NSF backups.
However the backup and the retention time should be general in sync to always restore all NLOs referenced by a database.

The nature of the NLOs is that they remain on disk for a longer retention time ( configured in the server document ) after the last reference of a NLO is removed.

## Special considerations for transaction log

In general there are two different types of transaction log modes.

- **Circular & Linear style**
  Mainly intended for database consistency and performance.
  With only a very limited option to restore point in time
  
- ** Archive style**
  Using the archive style transaction log allows true point in time recovers but adds complexity to your backup infrastructure.
  Translog extends ( `*.txn` files ) have to be backed up by the backup application in time.
  And the backup application has to restore `txn` files when requested by the backup API in a restore operation on demand.

Domino Backup supports all translog modes. The backup operation for translog txn files always writes one `txn` file after another and is best implemented with a file level backup or storing those files on a S3 drive.

## Domino archiving

Domino comes with full integrated archive functionality build into every database.  
For mail databases archiving can even be implemented leveraging policies.  
This includes home server groups to assign archive server targets.

Having a larger archive copy and a smaller live database if beneficial for performance and backup optimization.

A server based monthly archive also reduces the need for weekly or daily backups on archive servers.

### Archive DAOS support

When creating an archive an archive database is not automatically DAOS enabled. You have to specify the `-DAOS ON` option explicitly.

```
load compact -a -DAOS ON
```