
# Domino Backup VSS Writer test script

The [Diskshadow](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/diskshadow) tool is a simple way to create a VSS Writer compliant backup including Auto Recovery.

The script provided is only intended for test and demo purposes.
It can be used as the base for an own simple backup integration.

`backup.txt` contains the steps to start/end the backup and simulate the backup by listing the files in the created snapshot without taking a real backup.


This example contains fixed directory names. You might need to move them to a different disk.
You also might need to adjust the disk the Domino databases are located.

The two directories are involved

- c:\backup_mount
- c:\backupvss

The backup mount is where the snapshot is mounted.
The backupvss directory contains the scripts and should be referenced with an absolute path.
Therefore it needs to be changed to the location where you cloned/copied the example directory.

