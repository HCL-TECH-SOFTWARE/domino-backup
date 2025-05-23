# Rubrik Domino Restore
The Rubrik Domino restore script provides capability to live-mount a VMDK from a specific snapshot on a Rubrik cluster.


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

Create a folder and copy the `RubrikDominoRestore.ps1` file to the newly created folder.

Run the `RubrikDominoRestore.ps1` file with no parameters. This will invoke the first-time setup for doing restores. The following information will be needed for first time setup:

* vCenter FQDN/IP
* vCenter username
* vCenter password
* Rubrik FQDN/IP
* Rubrik Service Account Client ID
* Rubrik Service Account Secret

The Rubrik Service Account requires permissions to read snapshots and perform live-mounts. The vSphere account requires permissions to modify a VM and attach a VMDK.

The first time setup will save an XML file to the same folder where the .ps1 file resides. The FQDNs, usernames and encrypted passwords are stored in this XML file. ***Run first time setup with the same account that is going to be running the script.*** The account used in first-time setup is the only one that can decrypt the passwords in the XML file.


## Running a File Restore
Once first time setup has been complete and the XML file exists, `RubrikDominoRestore.ps1` can be executed to restore Domino files.

```
RubrikDominoRestore.ps1 -Tag <TAG DATE STRING> -Source <PATH TO FILE YOU WANT TO RESTORE> -Destination <DESTINATION PATH FOR RESTORE>
```

Example:
```
RubrikDominoRestore.ps1 -Tag "2024011800000" -Source D:\notes\data\log.nsf -Destination D:\notes\data\restore\log.nsf
```

The `-Tag`,`-Source`, and `-Destination` parameters can also be provided as positional parameters required by Domino Backup. The Rubrik restore script only requires the source, destination and tag date provided by Domino Backup.

Example:
```
powershell.exe -File RubrikDominoRestore.ps1 "D:\notes\data\log.nsf" "..." "..." "..." "..." "..." "2024011800000" "..." "D:\notes\data\restore\log.nsf"
```

## Unmounting
By default, the live-mount will continue to exist. To unmount, the `-RemoveMount` switch must be included.

```
RubrikDominoRestore.ps1 -Tag "2024011800000" -RemoveMount
```

