---
layout: default
title: HCL Domino Native Backup Concept
nav_order: 7
description: Cross-Cluster Backup Architecture with Tiered Storage
has_children: false
---

# HCL Domino Native Backup Concept

## Cross-Cluster Backup Architecture with Tiered Storage


# Executive Summary

This document describes a backup architecture for HCL Domino based on the Domino Native Backup functionality, combined with ZFS storage and a tiered backup model.

Domino creates application-consistent backups of NSF databases, transaction logs, and the DAOS repository, writing them directly to remote ZFS storage over a standard network share — NFS on Linux/Proxmox, SMB on Windows, or a Kubernetes PVC in containerized deployments — with no proprietary backup agent and no intermediate staging step.

The primary backup repository, protected by ZFS checksums, compression, deduplication, and snapshots, provides fast operational restores through Domino's own native restore functionality, and also allows experienced administrators to recover manually from standard files when a full restore workflow is not required. Retention of this primary repository is managed entirely by Domino.

A secondary backup tier — using ZFS replication or third-party backup software such as IBM Storage Protect, Veeam, or Proxmox Backup Server — protects the repository independently for long-term retention, offsite copies, and disaster recovery, without ever needing to understand Domino's data.

Encryption is handled per component (NSF, DAOS, transaction log) rather than as a single blanket decision, and daily ZFS snapshots taken after each backup provide resilience against ransomware, since they cannot be altered or destroyed from the same access path an attacker would use to reach the backup share.

The result is a simple, vendor-independent architecture — the same model applies whether Domino runs on Proxmox VMs, Kubernetes, or Windows — built around a clean separation of application consistency (Domino), storage protection (ZFS), and long-term retention (the secondary tier).


## Architecture at a Glance

```text
                    Domino Mail Cluster
        Mail01A    Mail01B    Mail02A    Mail02B
              \        |         |        /
               \       |         |       /
                -------+---------+------
                            |
                   Domino Native Backup
                            |
                            v
        +--------------------------------------------+
        |     Primary Backup Repository (ZFS)        |
        |--------------------------------------------|
        |  NSF Backups          Transaction Logs     |
        |  DAOS Repository      Daily Snapshots      |
        |  Compression          Deduplication        |
        +--------------------------------------------+
                            |
              +-------------+-------------+
              |                           |
       Domino Native Restore      Manual File Recovery
       (day-to-day operations)    (experienced admins)
                            |
                            v
        +--------------------------------------------+
        |          Secondary Backup Tier             |
        |  ZFS Send/Receive    IBM Storage Protect   |
        |  Veeam                Proxmox Backup Server|
        |  (offsite, long-term retention, DR)        |
        +--------------------------------------------+
```


# 1. Introduction

This document describes a backup architecture for HCL Domino environments based on the supported Domino Native Backup functionality introduced in Domino 12.0.
The concept is designed for highly available Domino mail environments running on Proxmox virtualization hosts in this example case.
But it applies in a similar way to other virtualization platforms. The concept can also be leveraged for other platforms like Kubernetes (K8s).
It combines the Domino Backup API with ZFS storage, NFS, and a tiered backup architecture to provide an efficient, scalable, and vendor-independent backup solution.

The Domino Backup API is application-aware, not a volume snapshot or a plain file copy. While a database stays fully online, Domino takes a raw copy of it, tracks every change made to it during that copy, and reconciles those changes into the backup image afterward — producing a transactionally consistent copy without requiring database downtime or a dedicated backup window.

The architecture deliberately separates three distinct responsibilities:

* **Domino** creates application-consistent backups.
* **ZFS** provides resilient and efficient storage.
* **A secondary backup tier** provides long-term retention and disaster recovery.

This separation allows each component to perform the task it is designed for while avoiding unnecessary complexity.

## Supported Platforms

The same architecture applies regardless of where Domino runs; only the backup target's network protocol changes:

| Platform                              | Backup Target                      |
| ------------------------------------- | ---------------------------------- |
| Linux (VM or physical, e.g. Proxmox)  | NFS                                |
| Windows                               | SMB                                |
| Kubernetes                            | PVC on an NFS-backed StorageClass  |


# 2. Design Goals

The solution provides:

* Fully supported Domino native backups
* Application-consistent NSF and transaction log backups
* No backup window — databases remain fully online throughout the backup
* Direct backup to remote storage
* No intermediate copy operations
* Cross-cluster protection
* Efficient storage utilization
* Fast operational restores
* Flexible long-term retention
* Vendor-independent secondary backup
* Simple disaster recovery

# 3. Infrastructure Overview

The example production environment consists of two Domino mail clusters distributed across four independent Proxmox hosts.

```text
                        Data Center

               Domino Mail Environment

   Cluster A                               Cluster B

+----------------+                    +----------------+
| Proxmox 1      |                    | Proxmox 3      |
| Mail01A        |<------------------>| Mail01B        |
+----------------+     Replication    +----------------+

+----------------+                    +----------------+
| Proxmox 2      |                    | Proxmox 4      |
| Mail02A        |<------------------>| Mail02B        |
+----------------+                    +----------------+
```

Each Proxmox cluster also provides storage services for the opposite cluster.


# 4. Backup Architecture

Each Domino server performs its native backup directly to a remote NFS share hosted by the opposite cluster.

```text
              Backup Traffic

Mail01A  ------------------------>  ZFS Storage Cluster Mail02B

Mail02A  ------------------------>  ZFS Storage Cluster Mail01B

Mail01B  ------------------------>  ZFS Storage Cluster Mail02A

Mail02B  ------------------------>  ZFS Storage Cluster Mail01A
```

- The backup target is a ZFS dataset exported via NFS.
- No local staging area is required.
- No secondary copy process is required before the backup becomes available.


# 5. Backup Components

## NSF Databases

Domino performs application-consistent backups of all configured NSF databases using the supported Domino Backup API writing to a file back-end.


## Transaction Logs

Transaction logs are backed up together with the NSF databases to the same remote ZFS storage.
This guarantees complete recoverability including transaction log replay when required.


## DAOS Repository

The DAOS repository is stored separately from the Domino server data.
Each data center maintains a shared DAOS repository located on a dedicated ZFS-backed NFS storage.


```text
                DC

Mail01A
Mail02A
Mail01B
Mail02B
     \
      \
       ---> Shared DAOS Repository with high availability
            NFS
            ZFS
            Compression
            Deduplication
```

Since DAOS already stores attachments only once, combining it with ZFS compression and deduplication provides excellent storage efficiency while simplifying administration.
The DAOS repository is protected independently through snapshots and the secondary backup tier.


### Cross-Server Deduplication

DAOS itself only deduplicates attachments — storing each one once — within a single repository.
If each server were instead given its own separate DAOS file share (its own NFS export / ZFS dataset)
rather than one literally shared repository, DAOS-level deduplication would stay scoped to that individual server.

That limitation can be recovered at the storage layer.
ZFS deduplication operates pool-wide, across all datasets in the pool, not just within a single dataset. It works at the block level: ZFS splits stored data into fixed-size blocks (for example 64K) and matches them against every other block already in the pool, keeping only one physical copy whenever two blocks are identical. As long as the separate per-server DAOS shares are provisioned from the same ZFS pool, identical attachment content written by different servers ends up as identical 64K blocks — and ZFS matches those blocks across server boundaries, without requiring the servers to share a single DAOS repository or coordinate locking with each other.

This cross-server benefit depends entirely on those blocks being identical across servers. **It requires DAOS encryption to be disabled — and DAOS encryption is enabled by default.** So long as it stays enabled, each server (or each database) encrypts its objects with its own key and initialization vector (a random value mixed into the encryption so the same input never produces the same output twice), so the same attachment ends up stored as different bytes on disk depending on where it was stored. The resulting 64K blocks no longer match, so ZFS finds nothing to deduplicate, even though the underlying attachment is identical.

In short: separate per-server DAOS shares on a shared ZFS pool are a valid way to get cross-server attachment deduplication without a shared repository, but only if an administrator deliberately turns DAOS encryption off — it does not happen by leaving settings at their default. This is a direct trade-off against the encryption discussion in chapter 16 and needs to be a deliberate decision, not an afterthought.


# 6. Backup Principles

The architecture is based on several important principles.


## Domino is responsible for backup consistency

Domino knows how to create a consistent backup of its databases.
Only Domino understands transaction logging, NSF consistency, DAOS references, and recovery requirements.
For this reason, Domino is responsible for creating the backup.


## Storage is responsible for protecting the backup

Once Domino has successfully written the backup, the storage layer becomes responsible for protecting it.

ZFS provides:

* End-to-end checksums
* Compression
* Deduplication
* Copy-on-write consistency
* Snapshots
* Optional replication

The storage layer does not need any knowledge of Domino.

Snapshots deserve special attention: because the backup share is always online and writable, snapshots are also this architecture's primary defense against ransomware. See chapter 17.


## Backup software protects the backup repository

If a secondary backup solution is used, it operates on the backup repository rather than the production Domino data.
This means the backup application does not require a Domino agent or Domino-specific integration.
The secondary backup solution simply protects files that have already been created by Domino.
This significantly simplifies backup integration and allows the backup software to be changed independently of the Domino environment.


# 7. Primary Backup Repository

The primary backup consists of the Domino backup repository stored on the remote ZFS storage.
The Domino backup process writes directly to the remote NFS share.
Retention of the primary backup is managed entirely by Domino.
Domino automatically removes expired backup generations according to the configured retention policy for:

* NSF backups
* Transaction log backups

No additional storage-side cleanup process is required.

> **Important — Domino owns retention.** Unlike traditional backup products, Domino itself manages the lifecycle of the primary backup repository. Domino determines which backup generations and archived transaction logs are still needed for recovery, and automatically expires the rest according to the configured retention policy. The storage layer never needs to interpret Domino backup metadata or make application-level retention decisions — it only needs to protect whatever Domino has already written.


# 8. Operational Restore

The primary backup repository provides the fastest restore option.
Because the backup is maintained in the native Domino backup format, operational restores are fully integrated with Domino and supported out of the box.

Typical operational restores include:

* Deleted mail databases
* Corrupted databases
* Point-in-time recovery using transaction logs
* Server recovery

This is the primary recovery mechanism for day-to-day operations.


# 9. Manual File Recovery

An important characteristic of the Domino backup format is that each completed backup represents a fully consistent point-in-time copy of the database.

While the database stays fully online, Domino takes a raw copy of it and simultaneously tracks every change made to the database during that copy. Once the copy is finished, those tracked changes are reconciled into the backup file, producing a single, internally consistent image of the database as it was at the exact moment the backup started.

The completed backup file is more than a plain copy of the database: it carries extra information tying it to the transaction log, which is what allows it to be rolled forward later. If this backup file is ever opened directly in Domino or Notes before going through the proper recovery step, that information is lost — the file becomes just a static point-in-time copy that can no longer be rolled forward. For this reason, a completed backup should always be brought back into service through Domino's supported recovery procedure — take the affected database offline, put the backup file in its place, recover it, and bring it back online — rather than simply copying it into the data directory and starting it directly. (The underlying mechanism — before-image tracking and change reconciliation — is documented in the ["Backup and Recovery" chapter of the HCL Domino C API documentation](https://opensource.hcltechsw.com/domino-c-api-docs/howto/user_guide/Backup_and_Recovery/).)

This still means a completed backup can be recovered without any third-party backup-vendor tooling: an administrator can take the affected database offline, put the backup file — and, if roll-forward is required, the relevant archived transaction logs — in place, and bring it back online, using only Domino's own recovery functionality.

This provides an additional recovery option for experienced administrators when a full Domino restore workflow through a third-party backup catalog is not required.

Typical examples include:

* Recovering a deleted database
* Restoring a single application
* Recovering configuration files
* Manual disaster recovery scenarios

While Domino Native Restore remains the recommended and fully supported recovery method, the backup repository itself consists of standard file-system objects, and recovering from it requires no backup-vendor-specific tooling — only Domino's own supported offline/recover/online workflow.


# 10. Secondary Backup Tier

The primary backup repository is a complete and fully supported Domino backup solution on its own — it is not a staging step waiting for a "real" backup to happen elsewhere.
The secondary backup tier described in this chapter is optional, and is introduced only when business requirements call for longer retention periods, offsite protection, or disaster recovery beyond what the primary repository provides.

The primary backup repository serves as the source for a second backup copy on different media — not just an extension of retention on the same storage, but an independent copy that survives the loss of the primary ZFS pool itself.

Possible implementations include:

* ZFS send/receive replication
* IBM Storage Protect (formerly IBM TSM)
* Veeam
* Proxmox Backup Server
* Other backup solutions capable of protecting standard file-systems

The secondary backup solution operates entirely independently from Domino.

Its responsibility is to provide:

* Long-term retention
* Offsite copies
* Disaster recovery
* Compliance retention
* Immutable storage if required

Since Domino has already created an application-consistent backup, no Domino backup agent is required.


# 11. Restore Scenarios

| Scenario                                     | Recovery Method                                    |
| -------------------------------------------- | -------------------------------------------------- |
| Deleted database                             | Domino Native Restore                              |
| Corrupted database                           | Domino Native Restore                              |
| Point-in-time recovery                       | Domino Restore + Transaction Logs                  |
| Lost Domino server                           | Restore backup to replacement server               |
| Lost Proxmox host (mail service impact)      | Domino cluster failover to the mate server         |
| Lost Proxmox host (VM needs to be rebuilt)   | Restore backup to a new VM                         |
| Lost storage pool                            | Secondary backup tier                              |
| Site disaster                                | Secondary backup tier                              |
| Ransomware / backup share compromised        | Roll back to a ZFS snapshot (chapter 17)           |


# 12. Advantages

The proposed architecture offers several important benefits.

## Simplicity

The solution uses only supported Domino functionality and standard storage technologies.
No proprietary Domino backup agents are required.


## Separation of Responsibilities

Each layer has a clearly defined responsibility.

**Domino**

* Backup consistency
* Transaction log handling
* Restore integration

**ZFS**

* Compression
* Deduplication
* Snapshots
* Data integrity
* Optional replication

**Secondary Backup**

* Long-term retention
* Disaster recovery
* Compliance
* Offsite protection

Each component can evolve independently without affecting the others.


## Efficient Storage

Direct backup to ZFS provides:

* Transparent compression
* Block-level deduplication
* Efficient snapshots
* High storage efficiency across multiple backup generations


## Fast Recovery

Operational restores remain completely integrated into Domino.
Additional manual recovery through standard file-system copy operations is possible because
every completed Domino backup represents a complete and internally consistent file-system image.


## Vendor Independence

The architecture does not depend on any specific backup application.
Organizations can adopt or replace secondary backup solutions without changing the Domino backup process.


## Platform Flexibility

The same architecture and the same responsibility model apply regardless of where Domino runs. Only the network share protocol changes: NFS on Linux/Proxmox (chapters 3–4), SMB on Windows (chapter 15), or a PVC/StorageClass on Kubernetes (chapter 14). Domino, ZFS, and the secondary tier keep exactly the same roles in every case.


## Security by Design

Encryption (chapter 16) and ransomware resilience (chapter 17) are not bolted on afterward — they follow directly from the same separation of responsibilities. Each component (NSF, DAOS, transaction log) carries its own encryption decision, made once at the Domino/storage layer and inherited by the backup rather than re-decided per tier, and daily ZFS snapshots taken after each backup give the architecture protection against a compromised backup share without requiring an offline or air-gapped copy.


# 13. Summary

This architecture combines Domino Native Backup with ZFS-based storage to create a simple, scalable, and highly resilient backup solution.

Domino is responsible for creating application-consistent backups of NSF databases and transaction logs. These backups are written directly to remote ZFS storage over NFS, where compression, deduplication, checksums, and snapshots provide efficient and reliable primary backup storage.

Retention of the primary backup repository is managed by Domino itself, while it provides fully integrated operational restores through Domino Native Restore. Because each completed backup is stored as a complete and consistent file-system image, administrators also have the flexibility to perform manual file-based recovery when appropriate.

The primary backup repository can optionally be protected by a secondary backup tier using ZFS replication or enterprise backup software, providing long-term retention and disaster recovery without requiring any Domino-specific backup agents.

The same architecture extends beyond the Proxmox/VM example used throughout this document: it applies equally to Domino on Kubernetes, using an NFS-backed StorageClass and a backup PVC (chapter 14), and to Domino on Windows, using an SMB share instead of NFS — deliberately in place of a VSS-based backup (chapter 15). Encryption is handled per component — NSF, DAOS, and the transaction log each need their own decision rather than assuming one covers the others (chapter 16) — and because the backup share is always online, daily ZFS snapshots taken after each backup provide the architecture's defense against ransomware (chapter 17).

The result is a clean separation of application consistency, storage protection, and long-term retention that reduces operational complexity while providing a robust and future-proof backup architecture for HCL Domino environments, across platforms and independent of any specific backup vendor.


# 14. Kubernetes Deployment Variant

As noted in the introduction, the same architecture principles apply beyond Proxmox/VM-based environments.
This chapter describes how the concept maps onto a Kubernetes-based Domino deployment.


## 14.1 Principle stays the same

The separation of responsibilities described in this document does not change:

* Domino (running as a pod) creates the application-consistent backup.
* The storage layer (ZFS, exposed into the cluster) protects it.
* A secondary tier protects the backup repository.

Kubernetes only changes how the backup target is made available to the Domino pod, not what creates or protects the backup.


## 14.2 NFS as a Kubernetes StorageClass

Instead of mounting the ZFS-backed NFS export directly on a VM, a StorageClass is defined pointing to the same NFS export served from the ZFS storage (for example via an NFS CSI driver or an external NFS provisioner).
This keeps the storage layer identical to the VM-based deployment; only the provisioning mechanism changes.


## 14.3 Backup PVC

A PersistentVolumeClaim backed by this NFS StorageClass is mounted into the Domino pod, for example at `/local/backup`.
Domino writes its native backup (NSF, transaction logs) to this path exactly as it would to a local backup directory in the VM-based model.
From Domino's perspective, the backup target is just a file-system path — it is not aware that the path is backed by an NFS-based PVC.


## 14.4 Result

The backup principles from chapters 6 and 7 apply unchanged:

* Domino remains responsible for backup consistency.
* The ZFS storage behind the StorageClass remains responsible for protecting the backup (checksums, compression, deduplication, snapshots).
* The secondary backup tier continues to operate on the same backup repository, independent of whether it is reached via a VM mount or via a PVC.

This means a single backup concept covers both the Proxmox/VM-based environment and a Kubernetes-based Domino deployment, with only the storage provisioning mechanism differing between the two.


# 15. Windows Deployment Variant

## 15.1 Principle stays the same

The same idea applies to Domino running on Windows: it backs up directly to a remote SMB share backed by the same ZFS storage used elsewhere in this concept. Domino remains responsible for consistency, ZFS remains responsible for protecting the backup, and the secondary tier remains unchanged. Only the network file-sharing protocol changes: NFS for Linux, SMB for Windows, a PVC/StorageClass for Kubernetes.


## 15.2 SMB as the backup target

The ZFS storage exports an SMB share (for example via Samba, or a NAS front end) instead of, or alongside, the NFS export used by the Linux servers. A Domino server running on Windows points its backup target at this SMB share (UNC path or mapped network drive), exactly as a Linux server points at its NFS mount.

Domino writes NSF, transaction log, and DAOS backups to this path the same way, using the same Domino Backup API.
Windows does not require different Domino backup technology — only a different network share protocol to reach the same ZFS pool.


## 15.3 Why this approach is better than VSS

VSS-based backup is the approach most Windows administrators already know, so it is worth explaining explicitly why the Domino Native Backup approach used in this document is the better choice, not just a different one.

Domino ships a supported VSS writer, so using VSS is a legitimate, available option on Windows. This concept deliberately does not use it, in favor of the direct file-based Domino Backup API approach described in this chapter. The reasoning below explains why.


### What VSS actually does

Volume Shadow Copy Service (VSS) is a Windows OS framework, not a backup solution by itself. It coordinates three separate roles:

* **Requester** — the backup software that asks for a snapshot.
* **Writer** — an application-specific component (a "Domino VSS writer") that briefly quiesces Domino I/O so the data is in a consistent state at the moment of the snapshot.
* **Provider** — the storage or OS component that actually creates the shadow copy.

VSS's entire job is to get Domino into a momentarily consistent state so that the storage snapshot underneath it is safe to use.
It has no concept of backup generations, retention, transaction log replay, or restore.
Once the shadow copy exists, a separate backup application is still required to read data out of it, move it elsewhere, catalog it, retain it, and eventually restore it.

A shadow copy also grows the longer it is kept open: it works by copying the original content of a block into the diff area just before that block is overwritten, so every write made to the live database while the shadow copy exists adds more data to it. Against a large, actively-changing database like a Domino mail file, that adds up quickly — which is why shadow copies are routinely deleted immediately after the backup job finishes rather than left in place.


### Summary for administrators

VSS is a mechanism for obtaining a point-in-time consistent snapshot — it is not, by itself, a backup architecture.
It still needs a Domino-aware writer and a Domino-aware backup product layered on top to become useful, and even then it does not provide Domino's own retention, generation tracking, or native restore integration.
The Domino Native Backup approach used throughout this concept produces the same kind of consistent, complete image, but does so as a first-class Domino capability: no VSS writer, no third-party Domino agent, native retention, and native restore — using the exact same cross-platform storage model (NFS, SMB, or a Kubernetes PVC) as every other server in the environment.

This distinction carries through to ransomware resilience as well: A VSS shadow copy and a ZFS snapshot are not the same kind of protection, even though both are casually called "a snapshot." See chapter 17.6 for why that difference matters.


# 16. Encryption

Encryption is treated as a separate concern from the core backup architecture.
It is described here at a conceptual level; concrete implementation (key management, algorithms, NFS transport security) is out of scope for this document.


## 16.1 Encryption follows the data, not the backup process

The backup preserves whatever consistency and encryption state the source data already has. The backup process itself neither adds nor removes protection. NSF databases, the DAOS repository, and the transaction log are each covered independently — encrypting one does not automatically encrypt the others.


## 16.2 Defaults matter: NSF and DAOS start from opposite states

NSF (database) encryption and DAOS encryption do not share a default:

* **NSF local encryption is off by default.** It has to be explicitly enabled per database if confidentiality at rest is required.
* **DAOS encryption is on by default.** It has to be explicitly disabled if it is not needed — for example, to get the cross-server ZFS deduplication benefit described in chapter 5.

This means getting cross-server DAOS deduplication requires a deliberate action (turning DAOS encryption off); doing nothing leaves DAOS encrypted and the dedup benefit unavailable. The reverse is true for NSF: doing nothing leaves it unencrypted.


## 16.3 If Domino databases are encrypted

Domino's local database (NSF) encryption is a per-database setting, and it only covers the NSF files themselves. Two things are commonly assumed to come along with it but do not:

* **Transaction logs are not covered.** There is no separate transaction log encryption feature in Domino — the transaction log is written in the clear regardless of whether the databases being logged are encrypted. If confidentiality of transaction log content at rest is required, that has to be provided by another layer, such as encrypting the underlying ZFS storage, not by database encryption.
* **DAOS is not covered by the NSF setting.** DAOS encryption is a separate, independently configured setting (see 16.2), on by default regardless of whether NSF encryption is enabled.

This means "the databases are encrypted" does not by itself mean the whole backup repository is protected — only the NSF backup files are covered.
The transaction logs are never covered, and DAOS is covered only as long as its default-on encryption has not been turned off.

Where NSF encryption is enabled, the NFS transport and the ZFS storage layer do not need to duplicate that protection for the NSF portion — encrypting them as well is optional defense-in-depth, not a requirement. Transaction log confidentiality at rest, if required, has to come from the ZFS storage layer instead, since Domino provides no equivalent for the log.

Turning DAOS encryption off is what removes the byte-level redundancy that cross-server ZFS deduplication relies on (see chapter 5, "Cross-Server Deduplication"). Left at its default, identical attachments stored by different servers no longer end up as identical bytes on disk, so cross-server ZFS deduplication provides no benefit until DAOS encryption is deliberately disabled. Whether to disable it is a trade-off between attachment confidentiality at rest and the storage efficiency cross-server deduplication would otherwise deliver.


## 16.4 If Domino databases are not encrypted

If NSF encryption is not enabled, the primary backup stored within the same data center does not need to be held to a higher security standard than the production data it is a copy of. No additional encryption is required for the primary backup repository in this case. DAOS, left at its default, remains encrypted independently of the NSF setting.


## 16.5 Secondary tier / offsite encryption

The secondary backup tier is where encryption becomes relevant independently of whether the Domino databases themselves are encrypted,
because this tier is the one that typically leaves the data center — offsite replication, tape, or a remote site.
If the Domino databases are not encrypted, the secondary tier can still add encryption on its own, without changing anything on the primary ZFS storage or in Domino:

* **ZFS send/receive** supports raw encrypted sends, so an encrypted dataset can be replicated offsite while remaining encrypted in transit and at the destination, without ever decrypting on the source side.
* **IBM Storage Protect (TSM)** or similar solutions typically provide their own encryption for offsite or tape/virtual-tape media as data leaves the primary storage.

This keeps a clear two-layer model that administrators need to understand:

* The **primary ZFS storage** remains the fast, local operational restore source and simply follows the encryption state of the Domino databases.
* The **secondary tier** carries its own, independent encryption when required, since it protects a copy that leaves the data center rather than the day-to-day restore path.


## 16.6 Recommendation

Decide encryption per component and per requirement, rather than assuming the defaults already match what is needed:

* Enable NSF encryption at the Domino layer if mail file content needs data-at-rest protection — it is off by default (16.2) and must be turned on deliberately. This propagates through to the backup automatically for the NSF portion only. Where local encryption is used, protect the server ID file with a password: the ID's key material is what the encryption relies on, so an unprotected server.id undermines the protection NSF encryption is meant to provide.
* Leave DAOS encryption at its default (on) unless there is a specific reason to turn it off — disabling it trades attachment confidentiality at rest for the cross-server ZFS deduplication benefit from chapter 5.
* Transaction logs are never covered by Domino's own encryption. If their content needs protection at rest, that has to come from the ZFS storage layer, independent of what is decided for NSF and DAOS.
* Encrypt the secondary/offsite tier when data leaves the data center, independent of what is decided above.
* Avoid stacking multiple encryption layers without a specific reason — this keeps performance and key management simple, and keeps the primary ZFS tier positioned purely for fast restore.


# 17. Ransomware Protection


## 17.1 The backup share is always online — that is a risk, not just a convenience

The NFS/SMB backup share described in this concept is a live, writable target: Domino writes to it directly, with no offline or air-gapped step in between (chapter 4). That is what makes the architecture simple and fast, but it also means the backup share is reachable by anything that can reach the storage — including a compromised Domino server, a compromised admin workstation, or ransomware that has obtained valid credentials. Unlike an offline tape or an air-gapped copy, an always-online backup share can, in principle, be encrypted or deleted by an attacker the same way the production data can.


## 17.2 Daily snapshots after each backup

To compensate for that, the ZFS dataset behind the backup share should be snapshotted daily, immediately after that day's Domino backup has completed.
Taking the snapshot after the backup finishes — not before or during — matters: it guarantees each snapshot captures a complete, consistent backup generation rather than a backup job still in progress.
A ZFS snapshot is read-only from the moment it is created.
Files inside it cannot be modified or deleted through the NFS or SMB share, no matter what happens to the live data afterward.
If ransomware later reaches the backup share and encrypts or deletes the current backup files, the snapshots taken on previous days are unaffected and still hold a good copy of the backup as it existed at that point in time.


## 17.3 Why this matters specifically for ransomware

Ransomware attacks often have a dwell time — the attacker gains access well before triggering encryption, and may deliberately target backup repositories once discovered, since destroying backups is what prevents a victim from recovering without paying.
A backup repository protected only by ordinary file-system permissions offers no defense against this: if the same credentials that can write to the share can also delete from it, they can destroy it.
Daily ZFS snapshots break that assumption. Even a fully successful attack against the live backup share only affects that day's copy — anything captured in an earlier snapshot remains recoverable, because rolling back or destroying a snapshot is an operation on the ZFS storage itself, not something reachable through the NFS or SMB share.

## 17.4 Restricting who can destroy a snapshot

This protection only holds if snapshot destruction is not available to the same credentials used to access the backup share.
If a Domino server, its administrator account, or anything with write access to the NFS/SMB share can also destroy or roll back snapshots on the storage, an attacker with that level of access could remove the protection along with the live data.
For this reason, snapshot management — destroying old snapshots as part of retention, or any rollback — should be restricted to the storage administrators and performed on the ZFS host itself, kept separate from the credentials Domino servers use to reach the share. This separation of duties is what actually gives daily snapshots their value against ransomware, not the snapshot mechanism alone.

## 17.5 Snapshot retention

Daily snapshots should be kept for a rolling window long enough to cover realistic ransomware dwell times, independent of Domino's own backup generation retention described in chapter 7. Domino's retention governs how many backup generations exist on the live share; snapshot retention governs how far back an administrator can roll the storage back if the live share itself is compromised. The two retention policies serve different purposes and should be sized independently.


## 17.6 ZFS snapshots are not the same thing as VSS

Chapter 15.3 explains why Domino Native Backup does not rely on VSS.
It is worth being explicit here that a VSS "shadow copy" and a ZFS snapshot are not the same kind of object, even though both get called a snapshot in everyday use — and the difference is exactly what makes one useful against ransomware and the other not.

VSS is fundamentally a coordination mechanism for getting one consistent read of an application at a single moment — it is a way to *take* a backup, not a way to *keep* one. The shadow copy it produces:

* typically lives in a diff area on the same volume as the original data, with Windows capping the storage reserved for it and silently discarding the oldest shadow copies once that space fills up;
* is meant to be consumed by a backup job shortly after creation, not retained as a standing recovery point going back weeks;

A ZFS snapshot is a true point-in-time, storage-level object: creating one is instantaneous (copy-on-write, metadata only), it is read-only from the moment it exists, it persists for as long as it is explicitly kept (17.5), and — critically — it lives on the storage system, not on the Domino or Windows server that wrote the data. As chapter 17.4 describes, destroying or rolling back a ZFS snapshot requires privileged access to the ZFS host itself; nothing reachable from the backup share, including a fully compromised Domino server, can remove it.

This is the real reason daily ZFS snapshots provide ransomware protection where relying on VSS would not: a VSS shadow copy is defended by nothing more than whatever access control exists on the same machine an attacker has likely already compromised, while a ZFS snapshot is defended by a genuinely separate administrative boundary.

