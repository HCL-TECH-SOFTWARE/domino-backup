---
layout: default
title: Domino Backup Introduction
nav_order: 1
description: "HCL Domino Introduction"
permalink: /
---

# Domino Backup and Restore

Domino V12 introduces a Backup & Restore which is designed for easy integration with 3rd party backup solutions.

The server tasks `backup` and `restore` are accompanied by a new `dominobackup.ntf` which holds all the configuration, logs and a database inventory.
A Notes UI allows you to restore databases with many options including restoring deleted documents and folders into the original database.

The solution is intended to complement existing backup solutions and to make it easier for customers and partners to integrate with existing backup solutions which are not Domino aware today.  
Integrated solutions from a backup vendor should always be the prefered backup option if available!

Out of the box Domino Backup is configured to use a file back-end with integrated copy operations directly performed by core Domino.  
This default configuration can be used with different file back-ends. But Domino Backup can also be extended using custom scripts.  

## Integration options and scope

Integrations might consist of the following types
  
- Integrated file backup operations
- Custom scripted integration
- Snapshot backups

Domino Backup & Restore itself is not intended to be a full backup application in the classical way.  
It is more a middle-ware and an integration point on the one side and it is providing flexible restore operations on the other side.

The focus is on the files which are in use on a running Domino server and which need special care.

- NSF backup ( *.nsf, *.ntf, *.box )
- Transaction log backup ( *.txn )

NSF and TXN files require a Domino Backup API integration - a so called "**backup agent**".  
Domino Backup provides this interface to leverage it for Backup applications which provide no direct integration.

You still have to backup additional files in the data directory with a standard file-backup or have them included in a snapshot

- notes.ini server.id etc
- DAOS repository

## Purpose and content of this repositiory

This repository is intended for integration scripts for

- Backup vendor solutions without Domino integration, leveraing Domino Backup
- Storage solutions with optimized storage
- Integrations with other storage providers like S3 storage
- And other command line scriptable backup targets

You also find detailed information about the integration options available for Domino Backup.  
This is the main documentation for the Backup integration complementing the HCL Domino Backup documentation which is focusing on the administration side of the Backup integration and how to leverage integration scripts.

## Repository structure

Integration scripts often consist of script files which aredeployed on Domino server host operating system level.  
The configuration of those scripts is stored in a DXL file. There is an import action in the Domino Backup database to import those default configuration settings for a backup integration.

Each integration or integration example is stored in a separate directory.  
