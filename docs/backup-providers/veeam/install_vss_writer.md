---
layout: default
title: "Domino 12.0.2 Win Veeam"
nav_order: 4
parent: Veeam
grand_parent: "Backup Providers"
description: "Install Domino 12.0.2+ Windows Backup VSS Veeam Integration"
---

# Domino 12.0.2 Backup Veeam restore integration step by step installation

 !! **The new integration is only available on Windows leveraging the VSS Writer interface** !!

Starting with Domino 12.0.2 the new **VSS Writer implementation** is the recommended backup integration.  
For backup no integration scripts are required supporting VSS snapshots on Windows.  
Restore operations still require to mount snapshots to the Domino server.  
The following document describes a simplified restore integration for Domino in combination with Veeam.  
This integration is a reference implementation, which might be adopted for other integrations.

## Backup configuration on Domino server

For VSS Writer backup integration the only requirement is to ensure the new `backupvss` server task is always running.  
It should be added to the `servertasks=` notes.ini entry or added to a start-up only program document.

For troubleshooting start the task with the debug option `backupvss -d`.

This document mainly focuses on restore integration. For more details about the backup VSS Writer integration check Domino 12.0.2 Admin documentation.

## Summary of required steps

- Copy the restore Powershell script on Veeam server
- Install OpenSSH on Veeam server
- Create "notes" user on Veeam server
- Configure dominobackup.cfg for your Domino server

- Copy the restore scripts to the Domino Windows server
- Create SSH key and configured it to access the Veeam server
- Test the SSH connection from Domino server to Veeam server

## Veeam Backup & Replication server configuration

### Copy configuration and script files

Copy the configuration files from the `veeam_server` directory to `c:\dominobackup` directory.

The directory contains the following files:

- PowerShell script to search and mount Veeam Restore Points (separate subdirectories)
- JSON configuration file

### Setup OpenSSH server on Veeam server

The integration uses a SSH connection between the Domino and the Veeam server.  
The following documentation describes the setup setups for a basic OpenSSH server configuration to allow SSH key authentication.  
Consult your system administrator for further configuration steps required in your environment.

The minimum required version for the OpenSSH server is **OpenSSH_for_Windows_8.1p1, LibreSSL 3.0.2** (first included in Windows 2022).  
The OpensSSH server was first shipped with Windows 2019, but needs to be updated at least to version 8.1 manually (Windows update does not update OpenSSH).  

In general, it is recommended to use the latest stable version provided by Microsoft in their official GitHub repository.  

- Download and install via MSI installer from [OpenSSH PowerShell release page](https://github.com/PowerShell/Win32-OpenSSH/releases).  
- Example file name: **OpenSSH-Win64-v8.9.1.0.msi**
- Verify you are running at least version **OpenSSH 8.1** by running `sshd -V` and `sshd -?` (there is no official option but an invalid option prints help including the version).

After installing the OpenSSH server make sure the OpenSSH server configuration is updated with the following configuration, start the OpenSSH service and ensure it is set to start automatically.

Edit `C:\ProgramData\ssh\sshd_config` to check and enable the following settings:

```
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PasswordAuthentication no
StrictModes no
PermitEmptyPasswords no
GSSAPIAuthentication no
AllowAgentForwarding no
AllowTcpForwarding no
PermitTunnel no
```

The following information is important for setting up SSH user access:

- The user for requesting restore operations is required to be listed in the Windows administrator group
- To allow individual keys for the account make sure to disable the following default configuration
- Even the user is an administrator, the user will not be able to log-in interactively if you don't set a password
- The user is only running the restore command invoking the PowerShell script. No interactive login is required
- Ensure the following settings are not enabled to allow individual SSH keys for each admin account needed

```
# Match Group administrators
#        AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys
```

### Restart OpenSSH server

After the configuration change is saved, restart the OpenSSH server:

```
powershell -command "Restart-Service sshd"
```

### Create a local user "notes" for Domino server requests over SSH

Create a local administrator account `notes` and log in with the new user.

### Additional Info: PowerShell operations for command-line configuration

To create an user account on the command-line the following PowerShell commands might be helpful.
This method only works for local uses.

Note: In case you are running a server which is also an AD Domain Controller no local user management is available and the user would need to be a domain user.

### Permissions

The user can be either part of the local Administrators group or can configured as a Veeam Backup Admin.
Both configurations have been successfully deployed.

### Example

The following command shows how to create a local admin user.

```
New-LocalUser -Name notes -Description "Notes Veeam integration user"
Add-LocalGroupMember -Group Administrators -Member "notes"
Get-LocalGroupMember -Group "Administrators"
```

Once the user is created run the following command as the user to create home dir.
The home directory is important to add the `.ssh` directory for the `authorized_keys` file later.

```
runas /user:notes "cmd.exe /c quit"
```

To create the SSH configuration it could also make sense to start a local session as the "notes" user.

A command-line could be opened like this:

```
runas /user:notes "cmd.exe"
```

### Add account to OpenSSH configuration on Veeam server

Switch to the user's home and create a new directory for SSH `.ssh`

```
  c:
  cd c:/users/notes
  mkdir .ssh
```

### Configure SSH connection for the "notes" user on the Veeam server

Note: The public key might not be available yet and will be created in a next step on the Domino server side.

The public key added in this configuration step will be created in a configuration step on a Windows based Domino server.  
Refer to the section **Domino Server on Windows Veeam configuration**.

Add the public key of the SSH key created on your Domino server to the file `C:\Users\notes\.ssh\authorized_keys` 

Multiple Domino servers could share the same key. In case multiple keys are used, each key requires a separate configuration line.

The line also needs to contain the PowerShell command to restrict OpenSSH access to the PowerShell script used for integration.  
The resulting line starts with the command and ends with the public key:

```
command="powershell.exe c:/dominobackup/DominoRestore.ps1" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEFUAH/EaO7yK0QrRRLiAeOzAm+4gZVBFqUL37V4T9TQ
```

Note: In case your Windows server does not allow execution of unsinged scripts, either sign the script according to Microsoft documentation or explicitly run the script bypassing the execution policy. It is not recommended to generally change the policy to allow the execution of all unsigned scripts.

To allow a single script to bypass the policy change the invoked command to a line similar to the following:

```
command="powershell.exe -noprofile -executionpolicy bypass -file c:/dominobackup/DominoRestore.ps1" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEFUAH/EaO7yK0QrRRLiAeOzAm+4gZVBFqUL37V4T9TQ
```


### Add notes user to Veeam as restore operator

- In the Veeam Backup and Replication client, open `User and Roles` from the menu in the upper left corner.

- Add the `notes` user and grand access with at least `Veeam Restore Operator` role.


### Add Domino server to JSON configuration on the Veeam server

Each Domino server requires a configuration entry in the JSON configuration file to authorize the Domino server to request mount operations.

Specify the following information:

`c:/dominobackup/dominobackup.cfg`

The configuration contains the following information:

- IP address
- Veeam admin credential description to find the right credential for mounting
- Operating system (Windows)
- Name of the operating system VM/host (the name used by Veeam to identify the virtual machine)

```
[
  {
    "VmHost"      : "127.0.0.1",
    "IpAddress"   : "127.0.0.1",
    "AccountName" : "Administrator",
    "OS"          : "Windows"
  }

]
```

#### Tip finding VmHost names

The `VmHost` is the name configured in your Veeam Backup configuration. In the previous example, the local server is configured.
For Veeam backup agent configurations it is usually the DNS name of the server. For VM backup integrations like VMware Vsphere it is usually a VM name.
You need to make sure the `IpAddress` matches the name referenced for the Domino instance.
In case you are not sure which name to use, open a Powershell prompt on your Veeam server to find backups via `Get-VBRRestorePoint` command. Depending on the size of your environment you might want to narrow down the search. Each backup references the name, leveraged by the PowerShell script mounting the snapshot.

Check the Veeam [Powershell Command reference Get-VBRRestorePoint](https://helpcenter.veeam.com/docs/backup/powershell/get-vbrrestorepoint.html) for details.

#### Account Name configuration

The `AccontName` in the Veeam configuration is actually the `description` of the user specified, because the name of the user is the user name on the target OS.
Those user names are not unique. Therefore ensure the description of the account can be used as an unique mapping.

Check the Veeam [Powershell Command reference Get-VBRCredentials](https://helpcenter.veeam.com/docs/backup/powershell/get-vbrcredentials.html) for details.


### Test server OpenSSH connection from Domino server to Veeam server

Switch back to your Domino server to test the connection and confirm the public key of the OpenSSH server.  
The connection check needs to be executed in the context of the user running your Domino server.

For the system account open a shell via

```
PsExec.exe -ids cmd.exe
```

The following command connects to the server and tests the connection to the PowerShell script.

```
ssh notes@veeam-server.acme.loc check
```

The first time you connect you are prompted to trust the certificate on the OpenSSH server.

Confirm the following prompt:

```
The authenticity of host 'veeam-server.acme.loc (veeam-server.acme.loc)' can't be established.
RSA key fingerprint is SHA256:DepsvLuZPubqRgGr1J6AXu9B4DdtUrrMjRqX7V77IZc.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added 'veeam-server.acme.loc' (RSA) to the list of known hosts.

```

After confirming the connection check the output of the command.
The output should show the environment variables and configuration found.

## Domino Server on Windows Veeam configuration

In preparation for the Veeam server Domino Restore configuration the following steps are required.

### Copy and configure integration scripts to Domino on Windows server

Log into the Domino server on Windows

Copy the backup scripts from the `domino\windows` directory to the `c:\dominobackup\veeam` directory.

```
cd \D c:\
mkdir c:\dominobackup\veeam
copy veeam\domino\windows c:\dominobackup\veeam
```

The following files are required for  restore configuration:

- **restore_db.cmd**  
  Restore script for requesting database restores from Veeam.  
  This script mounts the backup and copies over databases back to Domino as requested by the administrator.

- **restore_post.cmd**  
  Post restore script to unmount Veeam mounts used during restore operations.  


### Configure the restore scripts on Domino Window server

The restore scripts require a connection to the Veeam server.  
Edit the file `c:\dominobackup\veeam\restore_db.cmd` and `c:\dominobackup\veeam\restore_post.cmd` configure to your Veeam server connection.

The `VEEAM_SERVER_SSH` variable should point to the user-specified on the Veeam server-side ( usually `notes` @ the DNS name of the Veeam server as shown in the following example).

```
# Veeam server ssh connection
VEEAM_SERVER_SSH=notes@veeam-server.acme.loc
```

Note: DNS entries are preferred. IP addresses should be avoided (but work in the same way).

### Create SSH key for the the user running your Domino service

The SSH configuration needs to be performed for the user running your server.

- In older installations this user is the Windows System account
- In newer installations the user is often the Windows Local Service account
- If your user is running with an assigned local or Windows domain user, the configuration needs to be performed with this user

For Domino servers using Windows system account or local service account, an interactive shell can be opened using the Windows `psexec` application from Windows Internals.
Note: To ensure the connection to the Veeam server also works when the server is started in the foreground instead of a service, the SSH key must be also copied to the account used to start the server!

### Download Microsoft psexec.exe to Domino Server

The `psexec` helper tool is only needed when running with an user which does not have a password and usually not login.

Download the [ps-tools ZIP file](https://docs.microsoft.com/en-us/sysinternals/downloads/psexec) and extract the `psexec.exe` binary to your server (e.g. `c:\psexec.exe`).

The `psexec.exe` helper tool is used to configure the SSH connection for the system account later.
It can be removed after the configuration is performed. But keeping the helper binary could be useful for troubleshooting.

## Start cmd.exe for Windows System Account

```
PsExec.exe -ids cmd.exe
```

Verify the user is the system account

```
whoami
nt authority\system
```

## Start cmd.exe for Windows Local Service Account

```
PsExec.exe -i -u "NT AUTHORITY\LOCAL SERVICE" cmd.exe
```

Verify the user is the local service account

```
whoami
nt authority\local service

```

#### Create a new SSH key

Create a ED25519 key to be used for connecting to the OpenSSH server.
Don't specify a password for the key.

```
ssh-keygen -t ed25519
```

In case you want to use the same SSH key for multiple Domino servers,
Copy the private key created to `C:\Windows\system32\config\systemprofile\.ssh\id_ed25519`


Confirm the location of the key.

The result looks like the following output:

```
ssh-keygen -t ed25519
Generating public/private ed25519 key pair.
Enter file in which to save the key (C:\Windows\system32\config\systemprofile/.ssh/id_ed25519):
Created directory 'C:\Windows\system32\config\systemprofile/.ssh'.
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in C:\Windows\system32\config\systemprofile/.ssh/id_ed25519.
Your public key has been saved in C:\Windows\system32\config\systemprofile/.ssh/id_ed25519.pub.
The key fingerprint is:
SHA256:/x0wurKBnfe7KrILfttwHh6wkMOFx8Dk34McbciZ2hk nt authority\system@WIN-BS7M1PB2KQE
The key's randomart image is:
+--[ED25519 256]--+
|   oo            |
|   ..= =         |
|    o E o        |
|   . O B         |
|    * B S   o    |
|     o = + . o   |
|    . + B +   .  |
|   . .o*o= + . . |
|    ..+==+o.=o.  |
+----[SHA256]-----+
```

Your public file `C:\Windows\system32\config\systemprofile/.ssh/id_ed25519.pub` should look similar to the following line:

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEFUAH/EaO7yK0QrRRLiAeOzAm+4gZVBFqUL37V4T9TQ nt authority\system@WIN-BS7M1PB2KQE
```

The public key is added in Veeam configuration step to the `notes` user on your Veeam server.  
Once the public key is added to the `authorized_keys` file on the Veeam server, verify the connection from the Domino server to the Veeam server in the same context where the SSH key was created (usually the system account).



## VSS Application aware restore operations with Local Service account

Starting with Domino 14.0 the standard configuration uses the **Windows Local Service account** instead of the Windows Local System account.
To merge changes into the snapshot Domino needs to mount the snapshot in the post snapshot phase.
Mounting and unmounting disks or snapshots requires admin permissions.

Beginning with Domino 14.5.1 Domino ships with a small helper service which only performs those mount operations.
`nvssadmin_service.exe` is copied to the Domino binary directory by default.
To register and start the service perform the following operation:

```
nvssadmin_service.exe -p d:\domino\data -i
nvssadmin_service.exe -p d:\domino\data -s
```

Once installed the service is started automatically and needs no additional configuration.


### Full command line reference

```
nvssadmin_service.exe

Error: Insufficient arguments.2026-05-18 18:44:10  Usage: vssadmin_service -p <path> [command]
2026-05-18 18:44:10   Example: vssadmin_service.exe -p "C:\Domino\Data" -status
2026-05-18 18:44:10  Commands:
2026-05-18 18:44:10    -i | -install     - Installs the service.
2026-05-18 18:44:10    -u | -uninstall   - Uninstalls the service.
2026-05-18 18:44:10    -s | -start       - Starts the installed service.
2026-05-18 18:44:10    -x | -stop        - Stops the installed service.
2026-05-18 18:44:10    -t | -status      - Status of the installed service.
2026-05-18 18:44:10    -r | -restart     - Restart installed service.
2026-05-18 18:44:10    -h | -?           - Displays this help message.
2026-05-18 18:44:10  If no command is provided, the application assumes service mode and runs as a background service.
```


