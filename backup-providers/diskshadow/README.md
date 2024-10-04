
# Domino Backup VSS Writer test script

The [Diskshadow](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/diskshadow) tool is a simple way to create a VSS Writer compliant backup including Auto Recovery.

The script provided is only intended for test and demo purposes.
It can be used as the base for an own simple backup integration.

`backup.txt` contains the steps to start/end the backup and simulate the backup by listing the files in the created snapshot without taking a real backup.

