---
layout: default
title: Domino K8s Backup
nav_order: 6
description: Domino on K8s Storage and Backup Architecture
has_children: false
---

# Domino on K8s: Storage and Backup Architecture

## Overview

This document covers two distinct storage topics for HCL Domino running on Kubernetes:

1. **Standard Domino storage** — persistent volumes for NSF databases, transaction logs, DAOS, and other Domino data directories, provisioned through standard Kubernetes CSI storage classes.
2. **Backup storage** — a dedicated backup target outside the Kubernetes cluster, built on a ZFS appliance exposed via NFS.

These two concerns are intentionally separated.
Standard Domino storage is a Kubernetes-internal concern.
Backup storage exists outside the cluster and operates independently.

Domino is not the classical Kubernetes type of application.
Usually containers are mainly compute focused and access databases in separate Kubernetes services or outside the cluster (e.g. PostgreSQL, Mongo DB, etc.).

Because Domino is an application server and also the databases server, Domino requires much higher I/O rates and data transfers than classical K8s applications.
Therefore looking into Domino storage in a Kubernetes environment is important.

---

## Part 1: Standard Domino Storage on Kubernetes

Domino requires several categories of persistent storage.
Each maps to a dedicated Persistent Volume Claim (PVC) backed by a standard CSI StorageClass with ReadWriteOnce (RWO) access.
In contrast some other applications like HCL Samtime need storage which can be read and written by multiple serves at the same time with ReadWriteMany (RWX) access.


### Domino Data Directories

| Directory          | Purpose                   | Notes                                                            |
|--------------------|---------------------------|------------------------------------------------------------------|
| `/local/notesdata` | NSF databases &templates  | Primary data volume which should be SSD backended                |
| `/local/translog`  | Transaction log           | High I/O; benefits from SSD-backed storage class                 |
| `/local/daos`      | DAOS object store         | Large object storage; can use cost-optimized storage class       |
| `/local/nif`       | NIF view rebuild cache    | Fast storage required; no backup needed — rebuilds from NSF      |
| `/local/ft`        | Full-text indexes         | Fast storage required; no backup needed — rebuilds from NSF/DAOS |
| `/local/backup`    | Domino backup output      | Dedicated backup volume — see Part 2                             |


### CSI StorageClass Considerations

Standard Kubernetes CSI storage classes provide what Domino needs:

- **ReadWriteOnce (RWO)**      — all Domino data volumes are single-pod access; RWO is correct and sufficient
- **Volume expansion**         — CSI volume expansion allows growing individual volumes without redeployment; size quotas per volume enable monitoring and alerting
- **Storage class separation** — transaction logs and NSF data benefit from different performance tiers; separate storage classes allow this without changing application configuration
- **Dynamic provisioning**     — PVCs are created per Domino server instance; each server gets its own isolated volumes


### Example PVC Layout

| Directory          | Example Size | Storage Class                   | I/O Pattern                             |
|--------------------|--------------|---------------------------------|-----------------------------------------|
| `/local/notesdata` | 500 Gi       | Fast SSD, 16K block size        | Random 4–16K block I/O, fully buffered  |
| `/local/translog`  |   5 Gi       | Fast SSD, 4K block size         | Sequential synchronous 4K writes; synced I/O |
| `/local/daos`      | 900 Gi       | Cost-optimized, 128k block size | Sequential 128K block read/write; written once |
| `/local/nif`       | 100 Gi       | Fast SSD                        | Random read/write, latency-sensitive    |
| `/local/ft`        | 100 Gi       | Fast SSD                        | Random read, bulk rebuild writes        |
| `/local/backup`    | 500 Gi       | NFS-backed (ZFS)                | Sequential write, throughput-oriented   |

Each Domino server instance has its own set of PVCs. There is no shared storage between Domino servers (RWO).


### Volume Expansion

CSI volume expansion is the standard mechanism for growing Domino volumes in Kubernetes.

Requirements:

- StorageClass must set `allowVolumeExpansion: true`
- The underlying storage provider must support online expansion (most modern CSI drivers do)

Procedure:
1. Edit the PVC and increase `spec.resources.requests.storage`
2. Kubernetes resizes the volume and the file-system online
3. No pod restart required for most CSI drivers

This applies equally to NSF data volumes, DAOS volumes, and the backup target volume.


---

## Part 2: Backup Storage Architecture

### Design Goals

Backup storage for Domino on Kubernetes has specific requirements that differ from standard application storage:

- Backup data must exist **outside the Kubernetes cluster** so that cluster failures, administrative errors, or ransomware cannot destroy backups
- The backup target must provide **snapshot-based protection** independent of the application
- **Deduplication and compression** reduce storage costs for backup data, which often contains repeated content across incremental backups
- **Independent retention management** — the storage platform enforces retention, not the application or Kubernetes
- **Simple integration** — Domino writes backups to a mounted filesystem path; no special backup client or agent inside the container


### Architecture

```text
+-----------------------------+
| Kubernetes Cluster          |
|                             |
|   Domino Pod                |
|     |                       |
|     v                       |
|   /local/backup  (PVC)      |
+-------|---------------------+
        |
        |  NFS CSI StorageClass
        |
        v
+-----------------------------+
| NFS / ZFS Backup Appliance  |
|                             |
|   ZFS Dataset per server    |
|   Compression               |
|   Deduplication             |
|   Scheduled Snapshots       |
+-------|---------------------+
        |
        |  Optional Tier-2
        |
   +----+----+
   |         |
   v         v
S3 / Kopia   Remote Site /
/ Restic     Second Appliance
```

The Kubernetes cluster is aware only of an NFS-backed PVC. The ZFS appliance and all its capabilities are completely transparent to Domino.


### Why ZFS for Backup Storage

ZFS provides capabilities that are directly relevant to backup storage:

- **Compression** — backup files compress well; LZ4 compression has negligible CPU cost and routinely achieves 2:1 or better ratios on Domino backup data
- **Deduplication** — incremental backups share significant data; deduplication avoids storing duplicate blocks across backup runs and across servers
- **Snapshots** — ZFS snapshots are instantaneous, space-efficient, and independent of the application; they protect against deletion or modification of backup files
- **Send/receive replication** — ZFS datasets can be replicated to a second appliance or remote site incrementally and efficiently
- **Checksumming** — ZFS detects and corrects silent data corruption


### Storage Layout on the Appliance

Each Domino server receives a dedicated ZFS dataset and NFS export.

```text
backup/
├── domino-mail01   -> /export/domino-mail01
├── domino-mail02   -> /export/domino-mail02
├── domino-admin    -> /export/domino-admin
└── domino-dev01    -> /export/domino-dev01
```

All datasets share the pool's compression and deduplication tables, so the efficiency benefits apply across all servers.


### Backup Flow

```text
Domino Backup Job  (inside container)
  |
  v
/local/backup  (mounted PVC)
  |
  v
NFS Export on ZFS Appliance
  |
  v
ZFS Dataset  (compressed, deduplicated)
  |
  v
ZFS Snapshot  (independent of cluster)
```

Domino's built-in backup writes backup files to a configured backup directory — `/local/backup` in the container.
Because the backup target is a plain file-system path mounted as a PVC, no backup agent, plugin, or additional software is required inside the container.
Domino backup works exactly as it does on a physical or virtual server.

The filesystem-level target is intentional. Domino backup is designed around writing to a local path.
Presenting the ZFS appliance as a mounted volume means the full Domino backup flow — including selective database
backup, transaction log backup, and restore — works out of the box without any Kubernetes-specific adaptation.

The same applies to transaction log backup. Because the transaction log backup target is also a file-system path,
Domino writes transaction log extents to `/local/backup` in the same way.
ZFS snapshots of the backup dataset then provide an additional layer of protection — even if a backup file is overwritten or corrupted, a recent snapshot preserves the previous state.

Domino creates the backup data. The ZFS appliance protects it. The cluster has no role in snapshot creation or retention.


### ZFS Snapshots

A ZFS snapshot is a point-in-time, read-only copy of a dataset.
Snapshots are created instantly and initially consume no additional storage.

ZFS uses a copy-on-write mechanism. When data in the active dataset is modified or deleted, the original blocks are preserved and referenced by the snapshot.
Only the changed blocks consume additional space. A snapshot of a 500 GB dataset costs nothing at creation and grows only as the live data diverges from it.

Key properties relevant to backup storage:

- **No performance impact at creation** — snapshots are instantaneous regardless of dataset size
- **Space-efficient** — only changed blocks are retained per snapshot; unchanged blocks are shared
- **Independent of the filesystem** — a snapshot cannot be deleted or modified from within the NFS export; it is managed exclusively on the ZFS appliance
- **Consistent** — a snapshot captures the exact state of all files in the dataset at the moment it was taken

Snapshots are managed on the appliance using standard ZFS tools.
The Kubernetes cluster and Domino are not involved.
A pod cannot delete or modify a ZFS snapshot, which is the core ransomware protection property.


### Ransomware Protection

The separation between the Kubernetes cluster and the ZFS appliance provides a meaningful security boundary.


```text
Kubernetes cluster  (writable access to NFS export)
  |
  |  cannot access
  |
  v
ZFS snapshots  (managed only on appliance)
```

If backup files inside `/local/backup` are deleted, encrypted, or corrupted from within the cluster, ZFS snapshots on the appliance remain unaffected. Recovery requires access to the appliance directly, not through Kubernetes.


### NFS Security

NFS export access should be restricted to Kubernetes node IP addresses only.
Pods access backup storage exclusively through mounted volumes provided by Kubernetes, not by direct NFS connections.

Recommended controls:

- Export access list restricted to Kubernetes node addresses
- Dedicated storage network segment preferred
- Host-level firewall on the appliance to enforce network restrictions


### Tier-2 Backup

The ZFS appliance is the first backup tier.
A second tier can be added independently without changing Domino or Kubernetes configuration.

Options:
- **S3** — `zfs send` piped to a tool such as Kopia or Restic targeting an S3 bucket
- **Remote ZFS appliance** — `zfs send | zfs receive` for efficient incremental replication
- **Borg / Restic on appliance** — agent running on the appliance reads the NFS export directly

The application layer is not involved in tier-2 backup.


### DAOS Backup

DAOS stores large binary objects — primarily mail attachments and embedded content — separately from the NSF databases that reference them.
This separation means DAOS can be backed up independently from Domino.

Because DAOS objects are written once and never modified, they are ideal candidates for file-level backup tools.
Any backup solution that can read a filesystem path can back up DAOS:

- Standard file backup agents (e.g. IBM Spectrum Protect, Veeam)
- Restic or Kopia targeting S3 or any repository
- ZFS snapshots of the DAOS volume directly, if DAOS is on a ZFS-backed PVC
- Simple rsync to a remote target

The write-once nature of DAOS objects means incremental backups are highly efficient.
Once an object is backed up it will never change, so subsequent incremental runs only need to transfer newly created objects.
Deleted objects are handled by DAOS pruning, not by the backup tool.

DAOS has a configurable retention period for deleted NLOs. When an NSF deletes a reference to a DAOS object,
Domino does not remove the object immediately — it is held for the configured retention period before pruning.
This retention period must be aligned with the backup retention window.
If DAOS prunes a deleted object before the corresponding NSF backup has aged out, a restore from that backup will reference objects that no longer exist.

For a complete Domino restore, both the NSF backup and the DAOS backup must be consistent with each other.
The Domino backup process handles this when using the built-in backup flow.
When backing up DAOS independently, the backup schedule should be coordinated so that DAOS objects referenced by the NSF backup are present in the DAOS backup as well.

**In practice, full DAOS restores are rare**

DAOS includes a cluster repair function that detects and recovers missing or damaged objects by reconstructing them from other cluster members.
Enabling cluster repair is strongly recommended — it handles the majority of object-level issues without requiring a backup restore at all.

For this reason Domino Backup does not provide an integration to backup DAOS.
But the restore flow can be configured to restore missing NLOs.
Because of the mentioned reasons this is integration is usually not required and would depend on the choosen DAOS backup backend.


### Appliance Sizing

Deduplication requires memory proportional to the size of the pool. A correctly sized appliance is essential.

Minimum recommended specification for a backup appliance serving 5-10 Domino servers:

| Resource   | Minimum | Recommended |
|------------|---------|-------------|
| CPU cores  | 8       | 16          |
| RAM        | 32 GB   | 64 GB       |
| Storage    | SSD     | SSD         |
| Network    | 1 GbE   | 10 GbE      |

RAM sizing rule of thumb: approximately 1 GB RAM per 1 TB of deduplicated pool capacity for
deduplication tables, plus ARC cache. For a 10 TB pool, 64 GB RAM is a reasonable starting point.

Cloud example:

```text
16 vCPU
64 GB RAM
1 Ti SSD  (OS + ZFS pool)
+ additional SSD capacity as needed
```

---

## Summary

| Concern                      | Mechanism                          | Location           |
|------------------------------|------------------------------------|--------------------|
| NSF, Translog, DAOS storage  | CSI StorageClass (RWO PVC)         | Inside Kubernetes  |
| Volume growth                | CSI volume expansion               | Inside Kubernetes  |
| Backup data creation         | Domino backup job writing to PVC   | Inside Kubernetes  |
| Backup data protection       | ZFS snapshots                      | Outside Kubernetes |
| Backup retention             | ZFS snapshot retention policy      | Outside Kubernetes |
| Long-term / offsite backup   | Tier-2 to S3 or remote appliance   | Outside Kubernetes |

Standard Domino storage and backup storage are provisioned through the same Kubernetes PVC mechanism but serve fundamentally different purposes.
Standard volumes hold live data and are managed as part of the Domino workload lifecycle.
The backup volume connects to an external ZFS appliance that operates independently of the cluster and enforces its own protection and retention policies.


