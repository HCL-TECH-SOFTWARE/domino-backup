---
layout: default
title: Domino Snapshot Backup
nav_order: 4
description: "HCL Domino Snapshot Backup"
has_children: false
---

# Leveraging snapshots for Domino Backup

## Introduction

`Snapshot technology` is a modern and very powerful concept in current backup solutions.  
The term can stand for different types of methods depending on the platform and storage used.  

Usually snapshots alone are **not** a backup solution or a way to keep backup data stored.  
In most cases a snapshot is used to generate a short living frozen state of a disk to allow an consistent, application independent state.

For all different snapshot types it is important to know that changes in data will result in data growth of storage at least in the size of the change!  

Therefore it is essential to

- Keep snapshots only as long as absolutely needed
- Separate NSF data to allow snapshots of NSF data alone
- Avoid changes to NSF files as much as possible ( e.g. reduce the number of snapshots, pre-allocate storage with DBMT )

## Types of snapshots

Snapshots are implemented on different levels, which results in different types of backup approaches they can be used for.  

### File system snapshots

File system snapshots are available for different type of file systems on Windows and Linux.  
On Windows Volume Shadow Copy ( VSS ) is built into the out of the box file system NTFS already.  
For Linux the standard file systems don't support snapshots. But the available file systems are very powerful and reliable and offer more than just the snapshot capability.

#### Windows Volume Shadow Copy ( VSS )

The VSS technology is build into Windows and the file-system. It is mainly intended to create an application consistent snapshot for backup.  
Keeping VSS snapshots for a longer time can cause performance impact and should be avoided.  

The VSS concept supports

- **VSS requestors** usually backup applications creating a consistent state for a backup
- **VSS writers** application which are VSS aware and register their application to be put into snapshot mode for a **VSS requestor** to backup the consistent state.

Due to the nature of Domino NSF databases and transaction log, a Domino server does not implement a **VSS writer**.  
But in combination with Domino Backup VSS can still be leveraged for backup using the Domino Backup snapshot support.

1. Bring all databases into backup mode
2. Create a VSS snapshot
3. Get all databases back into normal operation mode and collect potential delta data in *.DELTA files stored separately
4. Let a backup application backup the snapshot ( e.g. mount the snapshot read-only and backup the consistent state )
5. Release the snapshot

For Domino the backup is done after getting all databases back into normal operation mode.  
This allows a very short time window for backup and the application taking care of the actual backup has time to backup the consistent snapshot and finally release it.

For more details check the official Microsoft documentation for [Microsoft VSS](https://docs.microsoft.com/en-us/windows-server/storage/file-server/volume-shadow-copy-service)

#### Diskshadow utility to create VSS snapshots

All supported Windows server versions ship with the VSS command-line tool to create and manage snapshots.  
Domino Backup leverages [diskshadow.exe](https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/diskshadow) instead of implementing and own solution and benefits in all functionality out of the box.

#### Linux File system snapshot using LVM

The most commonly used file systems like [ext4](https://en.wikipedia.org/wiki/Ext4), [XFS](https://en.wikipedia.org/wiki/XFS) are not snapshot aware on it self. But Linux [LVM](https://en.wikipedia.org/wiki/Logical_Volume_Manager_(Linux) can be used to create snapshot.  

This is not a commonly used technology and bares some risk and complexity.  
For Linux snapshots one of the following file system with build-in snapshot support is highly recommended.

#### Linux btrfs file system snapshots

[btrfs](https://btrfs.wiki.kernel.org) is one of the newer file-systems, which is not included in all Linux distibutions. All SUSE distributions include it and also leverage it for root file systems.

In addition to snapshots btrfs also supports compression and data deduplication.  

#### Linux OpenZFS file system snapshots

[OpenZFS](https://openzfs.github.io/openzfs-docs/index.htm) has been around for quite a while. It was introduced introduced in Sun Solaris first and has been later ported to Linux, FreeBSD and other platforms. 

OpenZFS 2.0 has been a major shift to align OpenZFS on FreeBSD and other platforms. Also OpenZFS 2.0 has introduced many advanced features and tuning options.

OpenZFS is a completely different concept than other file-systems and it installed and operated with own tools (zpool and zfs). See the[OpenZFS presentation](https://papers.freebsd.org/2020/linux.conf.au/paeps_the_zfs_filesystem/) details.

Most widely used Linux distributions used with Domino still do not include OpenZFS out of the box. But it can be installed from their official repository for Domino supported Linux platforms.

### VM level snapshots

Modern virtualization platforms like VMware, Microsoft Hyper-V, KVM, Proxmox and others support VM level snapshots. Those snapshots are usually initiated by backup vendors to backup data to their own backup repositories. Keeping VM snapshots for a longer time for Domino databases can increase the storage footprint and performance dramatically.

VM snapshots without application aware processing to bring all databases into backup mode would only be crash consistent -- even the snapshot usually takes a very short time.

So it must be used in combination with Domino Backup or other Domino aware backup solutions.

### Storage level snapshots

Modern storage appliances like NetApp support snapshots also on storage level and are usually deeply integrated into VM level platforms.

In the same way VM snapshots would only provide crash consistent snapshots the underlying storage infrastructure would provide snapshots on the same level.

## Backup provider snapshot support

Modern Backup applications like [Veeam Backup & Replication](https://www.veeam.com/vm-backup-recovery-replication-software.html), [IBM Spectrum protect](https://www.ibm.com/products/data-protection-and-recovery) and others can leverage snapshot technology for their backups, but require application aware processing to allow consistent Domino backups.

There is not a one solution fits all approach when it comes to snapshot backups.  
A snapshot backup implementation always needs integration between the involved components.

## Domino Backup snapshot support

Given the different types of snapshot implementation, Domino Backup implements a very flexible snapshot interface, which can be adopted for different snapshot solution needs.

But due to the nature of those different snapshot technologies used, this requires integration scripting for each of the different technologies used.

Backup and restore flows would like outlined below.

### Snapshot backup flow

1. Bring all databases into backup mode
2. Create a snapshot
3. Get all databases back into normal operation mode and collect potential delta data in *.DELTA files stored separately
4. Let a backup application backup the snapshot ( e.g. mount the snapshot read-only and backup the consistent state )
5. Release the snapshot

Domino Backup does only need to control the first three steps. Backup and releasing the snapshot can be implemented using any kind of solution depending on the used technology and platform.

### Snapshot restore flow

1. Identify and mount the "right" snapshot
2. Find and copy the physically file from the mounted snapshot to the desired restore location
3. Check if restored databases wrote a *.DELTA file during backup and restore it from the backup location to the same directory where the physical database is copied (depending on the implementation).
4. Domino Backup applies changes from the *.DELTA file using the Domino backup API automatically
5. Recovers the database leveraging the Domino backup API.
6. Removed the *.DELTA file
7. Unmount the snapshot
8. Optionally: Roll the database forward to a given point in time in case of archive transaction logging.
