@echo off
echo > c:\backupvss\backup.log
echo --------------------------------------- >> c:\backupvss\backup.log
dir /s c:\backup_mount\domino\data >> d:\backupvss\backup.log
echo --------------------------------------- >> c:\backupvss\backup.log
echo >> c:\backupvss\backup.log