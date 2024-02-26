# Rubrik Domino Restore
The Rubrik Domino restore script provides capability to live-mount a VMDK from Rubrik storage to a MS Windows server running Domino.


## Requirements
* Windows Server running Domino and PowerShell 5.1+
* Rubrik CDM
* VMware vCenter
* VMware PowerCLI
* Rubrik SDK for PowerShell

## Setup
Install prerequisite PowerShell modules on the Domino Server

```
Install-Module Rubrik, VMware.PowerCLI
```

Copy the `RubrikDominoRestore.ps1` file to the directory of your preference. It's generally advisable to put this script in it's own directory, as we'll be creating additional files for tracking state and storing encrypted credentials.

Run the `RubrikDominoRestore.ps1` file with no parameters. This will invoke the first-time setup for doing restores. You will need the following information prepared for first time setup:

* vCenter FQDN/IP
* vCenter username
* vCenter password
* Rubrik FQDN/IP
* Rubrik Service Account Client ID
* Rubrik Service Account Secret

The Rubrik Service Account requires permissions to read snapshots and perform live-mounts. The vSphere account requires permissions to modify a VM and attach a VMDK.

The first time setup will save an XML file to the same folder/directory where the .ps1 file resides. The FQDNs, usernames and encrypted passwords are stored in this XML file. It's important to note that you should run first time setup with the same account that is going to be running the script, as this account is the only one that can decript the passwords in the XML file.


## Running a Single File Restore
Once first time setup has been complete and the XML file exists, `RubrikDominoRestore.ps1` can be executed to restore Domino files.

```
RubrikDominoRestore.ps1 -Tag <TAG FILE PATH> -Source <PATH TO BE RESTORED> -Destination <DESTINATION PATH>
```

Example:
```
RubrikDominoRestore.ps1 -Tag D:\notes\data\backup-20240118.tag -Source D:\notes\data\log.nsf -Destination D:\notes\data\restore\log.nsf
```

## Running a Multi-File Restore
The script can be run multiple times to restore multiple files with the same mount/tag. It is executed the same way, but we add a `-PersistMount` at the end to indicate we are going to continue using the same mount later. The last file in the multi-file restore should leave off the `-PersistMount` to clean up the mounted drive at the end.

Example:
```
RubrikDominoRestore.ps1 -Tag D:\notes\data\backup-20240118.tag -Source D:\notes\data\log.nsf -Destination D:\notes\data\restore\log.nsf -PersistMount
RubrikDominoRestore.ps1 -Tag D:\notes\data\backup-20240118.tag -Source D:\notes\data\log1.nsf -Destination D:\notes\data\restore\log1.nsf -PersistMount
RubrikDominoRestore.ps1 -Tag D:\notes\data\backup-20240118.tag -Source D:\notes\data\log2.nsf -Destination D:\notes\data\restore\log2.nsf #NO MORE PERSISTMOUNT
```