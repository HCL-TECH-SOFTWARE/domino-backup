---
layout: default
title: "Domino Veeam Installation"
nav_order: 3
parent: Veeam
grand_parent: "Backup Providers"
description: "Install Domino Backup Veeam Integration"
---

## Domino Backup Veeam Integration Step by Step Installation

## Configuration Settings

This instruction uses the following configuration settings:

- `notes` is the Linux user which runs your Domino server.
- `veeam-mount` is the user mounting Veeam backups to your Domino server.
- `veeam-server.acme.loc` sample host name for Veeam Backup and Replication server.
  Note: In production environments The Veeam server should be referenced by DNS entry.
  In case no DNS is available, the IP address can be specified.
- `domino.acme.loc` DNS name of the Domino on Linux server.
- `192.168.1.12` sample address for Domino on Linux server.
  The IP address is used to identify the Domino server connection.
- `Domino01-Linux` sample VM name for the Domino server on Linux.

## Domino Server on Linux configuration

In preparation for the Veeam server Domino Backup configuration the following configuration is performed on a first Domino on Linux server.

The keys created can be used for multiple servers and should be well protected on transfer between machines.

- SSH key for the `veeam-mount` user
  used by the Veeam server to authenticate with the Domino server Linux hosts

- SSH key for the `notes` user located on the Domino server to authenticate with the OpenSSH server on the Veeam server

### Copy and configure integration scripts

Log into the Domino server as `root` user.

Copy the backup scripts from the `domino/linux` directory to the `/opt/hcl/domino/backup/veeam` directory.

```
mkdir -p /opt/hcl/domino/backup/veeam
cp veeam/domino/linux/* /opt/hcl/domino/backup/veeam
```

Ensure the files can be executed

```
chmod 755 /opt/hcl/domino/backup/veeam/*
```

The following files are copied

- **backup_domino_snapshot.sh**  
  Snapshot script executed by the Veeam server to bring Domino into snapshot mode ( `pre-freeze` )
- **backup_domino_snapshot_done.sh**  
  Snapshort script to release the freeze on the Domino server ( `post-thaw` )
- **backup_snapshot_start.sh**  
  Domino snapshot script called when the snapshot starts and to return to **backup_domino_snapshot.sh** the snapshot can start
- **backup_snapshot.sh**  
  Domino snapshot script called when Domino processed and performed a backup for potential delta files.  
  This script integrates with the **backup_domino_snapshot_done.sh**
- **backup_post.sh**  
  Final script executed at the end of the backup operation on the Domino side.
- **restore_db.sh**  
  Restore script for requesting database restores from Veeam.  
  This script mounts the backup and copies over databases back to Domino as reuqested by the administrator.
- **restore_post.sh**  
  Post restore script to unmount Veeam mounts used during restore operations.  

### Configure the restore script

The restore script requires a connection to the Veeam server.  
To ensure proper communications a DNS entry should be in place.  
An IP address would be usually only used in test environments.

Edit the file `/opt/hcl/domino/backup/veeam/restore_db.sh` and `/opt/hcl/domino/backup/veeam/restore_post.sh` configure to your Veeam server connection.

The `VEEAM_SERVER_SSH` variable should point to the user specified on the Veeam server side ( usually `notes` ) @ the DNS name of the Veeam server as shown in the following example.

```
# Veeam server ssh connection
VEEAM_SERVER_SSH=notes@veeam-server.acme.loc
```

### Add a new veeam-mount user

Create a new user for Veeam mount operations.

```
useradd -U -m veeam-mount
```

Add `veeam-mount` user to sudo configuration to allow operations requiring root permissions

```
visudo
```

Add the following line (veem-mount needs all permissions to find and mount volumes)

```
%veeam-mount ALL= NOPASSWD: ALL
```

### Check if veeam-mount user can use sudo

Switch to the new account

```
su - veeam-mount
```

Run a test command with sudo

```
sudo whoami
```

The `whoami` command should return `root`

### Create a SSH key for the veeam-mount user

Create a new RSA key (in RSA Key format instead of OpenSSH format).
The following command prompts for a file name and a passphrase.

```
ssh-keygen -t rsa -m pem
```

The file content should look like the following output and is needed to authenticate the `veeam-mount` user when connecting over SSH to the Domino server.

This key will be used on Domino Linux server and just needs to be added to `.ssh/authorized_keys` on each Domino target server.

In our example the key is created with a passphrase.  
Veeam supports RSA keys with and without password/passphrase for application aware processing and mount operations on Linux.

```
-----BEGIN RSA PRIVATE KEY-----
Proc-Type: 4,ENCRYPTED
DEK-Info: AES-128-CBC,07365FFE74CB09EDCDE22A17AF4663FC
...
-----END RSA PRIVATE KEY-----
```

### Add veeam-user public key to authorized keys

To authorize the ssh key generated on the Veeam server copy the public key created on the Veeam server for the `veeam-mount` account to the authorized keys:

Create a `.ssh` directory and set the right permissions

```
mkdir .ssh
chmod 700 .ssh
cd .ssh
```

Add the public key created earlier to `authorized_keys` file and set the permissions

```
cat id_rsa.pub >> authorized_keys
chmod 600 authorized_keys
```

Tip: An easy way to test if the key can remotely login, is to use it on the local machine via.

```
ssh 12.7.0.0.1
```

### Create SSH key for notes user

Login with the `notes` user and run the following command to create a RSA key.  
The key will be used for SSH connections from Linux to the OpenSSH server installed on the Veeam server.

```
ssh-keygen -t rsa -m pem
```

Confirm the location of the key. The key should not have a passphrase

The result look like the following output:

```
Generating public/private rsa key pair.
Enter file in which to save the key (/home/notes/.ssh/id_rsa):
Created directory '/home/notes/.ssh'.
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in /home/notes/.ssh/id_rsa.
Your public key has been saved in /home/notes/.ssh/id_rsa.pub.
The key fingerprint is:
SHA256:mk78rr/f0UCziYeWr9UNyFy5T8nOqeR0kanPw3J/H0k notes@acme.com
The key's randomart image is:
+---[RSA 3072]----+
|                 |
|               . |
|            o o  |
|           B *..+|
|        S = O oE.|
|     . o . o +==+|
|      =     +++Bo|
|     o .   ++o=+o|
|      o+=oo .oooB|
+----[SHA256]-----+
```

Your key file `/home/notes/.ssh/id_rsa` should look similar to the following line:

```
-----BEGIN RSA PRIVATE KEY-----
MIIG4wIBAAKCAYEAuDnKa/WVCQND5sQTY3rl6sNGZjjpI0TohmE3tUoGhEFDzS5P
...
xxVYXpd9cfLAjfbV8/mU2w1YZOdopOEVseiRCJiM/xVRRQTfA5W9D2rxIze39/zg
ysHnnj1jppKySQA3yhr8Scdu3Zr6eAIKh/46G0sQavaJUkqqtFA3
-----END RSA PRIVATE KEY-----
```

#### Add the authorized key for the notes user

```
cd ~/.ssh
cat id_rsa.pub >> authorized_keys
chmod 600 authorized_keys
```

Tip: An easy way to test if the key can remotely login, is to use it on the local machine via.

```
ssh 127.0.0.1
```

The public key is located in `/home/notes/.ssh/id_rsa.pub` and is added in the next step to the `notes` user on your Veeam server.

## Domino Server on Windows configuration

In preparation for the Veeam server Domino Backup configuration the following configuration is performed on a first Domino on Windows server.

The key created can be used for multiple servers and should be well protected on transfer between machines.

The SSH key is created for the user your Domino server is running with located on the Domino server to authenticate with the OpenSSH server on the Veeam server.

### Copy and configure integration scripts

Log into the Domino server on Windows

Copy the backup scripts from the `domino\windows` directory to the `c:\dominobackup\veeam` directory.

```
cd \D c:\
mkdir c:\dominobackup\veeam
copy veeam\domino\windows c:\dominobackup\veeam
```

The following files are copied

- **backup_domino_snapshot.cmd**  
  Snapshot script executed by the Veeam server to bring Domino into snapshot mode ( `pre-freeze` )
- **backup_domino_snapshot_done.cmd**  
  Snapshort script to release the freeze on the Domino server ( `post-thaw` )
- **backup_snapshot_start.cmd**  
  Domino snapshot script called when the snapshot starts and to return to **backup_domino_snapshot.cmd** the snapshot can start
- **backup_snapshot.cmd**  
  Domino snapshot script called when Domino processed and performed a backup for potential delta files.  
  This script integrates with the **backup_domino_snapshot_done.cmd**
- **backup_post.cmd**  
  Final script executed at the end of the backup operation on the Domino side.
- **restore_db.cmd**  
  Restore script for requesting database restores from Veeam.  
  This script mounts the backup and copies over databases back to Domino as requested by the administrator.
- **restore_post.cmd**  
  Post restore script to unmount Veeam mounts used during restore operations.  


### Windows system account configuration

Most Domino servers are leveraging the Windows system account.  
This is a build-in account used by Windows services by default.  
Due to security changes in Domino 12.0, all Domino processes have to either

- Use the same user for all processes started (e.g. system account)
- Or require special authorization(configuration) for the administrative user

See technote for details https://support.hcltechsw.com/csm?id=kb_article&sysparm_article=KB0090343.

If the server is started by the system account, the Domino backup servertask should be started also with the system account.  
Microsoft offers a helper utility to allow command execution with the system account.  


#### Download Microsoft psexec.exe

Download the zip file for the ps-tools and extract the `psexec.exe` binary to your server (e.g. `c:\psexec.exe`).

https://docs.microsoft.com/en-us/sysinternals/downloads/psexec

Ensure the `PSEXEC_BIN` variable in `backup_domino_snapshot.cmd` points to this location.

Note: Not having `psexec.exe` in the path and only invoke the exe using the absolute path is recommended.

The `psexec.ex` helper tool is used to start the Domino backup servertask and also to configure the SSH connection for the system account later.


### Configure script variables

Edit all scripts and modify the parameter section based on your configuration

- Data directory
- Binary directory
- Location of PSEXEC if used
- Log and tracefile directories if used


### Configure the restore script

The restore script requires a connection to the Veeam server.  
To ensure proper communications a DNS entry should be in place.  
An IP address would be usually only used in test environments.

Edit the file `c:\dominobackup\veeam\restore_db.cmd` and `c:\dominobackup\veeam\restore_post.cmd` configure to your Veeam server connection.

The `VEEAM_SERVER_SSH` variable should point to the user specified on the Veeam server side ( usually `notes` ) @ the DNS name of the Veeam server as shown in the following example.

```
# Veeam server ssh connection
VEEAM_SERVER_SSH=notes@veeam-server.acme.loc
```

### Create SSH key for the system account or your Domino server user

For Domino servers using the system account open a cmd.exe window in the following way.
Open a administrator cmd window and run the following command:

```
PsExec.exe -ids cmd.exe
```

Verify the user is the system account

```
whoami
nt authority\system
```

#### Create a new SSH key

Create a RSA key to be used for connecting to the OpenSSH server.

```
ssh-keygen -t rsa
```

Confirm the location of the key. The key should not have a passphrase

The result looks like the following output:

```
ssh-keygen -t rsa
Generating public/private rsa key pair.
Enter file in which to save the key (C:\Windows\system32\config\systemprofile/.ssh/id_rsa):
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in C:\Windows\system32\config\systemprofile/.ssh/id_rsa.
Your public key has been saved in C:\Windows\system32\config\systemprofile/.ssh/id_rsa.pub.
The key fingerprint is:
SHA256:cjy6nZc7MtlBf2CkwoLyaNCrykQo2Iz/ILvQQCd9GHw nt authority\system@WIN-BS7M1PB2KQE
The key's randomart image is:
+---[RSA 3072]----+
|  ..             |
|  ..oE      .    |
| + +.o .   o     |
|=+= o ..o o o    |
|*oo=  ..So o .   |
|o++ .  + .. . .  |
|o++   .  o o .   |
|=o o   o+.=      |
|=o  . . o+.o     |
+----[SHA256]-----+
```

Your public file `C:\Windows\system32\config\systemprofile\.ssh\id_rsa.pub` should look similar to the following line:

```
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCwJnDDLtRLbz4x4n12ticC4vEQLCohFnvihpkiJ6ak1xJDGl3wbNKtyn6yJ3rrZ8xigyGzDH7mFe/0gxTAw9xlR4wPE3BEY7b2ejt9mvxbumNr+UhxlFclgsYO/YNGXd8J+I4eOIpXvu7F5zfPfU0ZAv4b9J+GsSP6UPDeNhToqpm0KnLsgQiCazSmzNYofSgrvRcqST8Cr+TBG7oEnSeoQX1BSyXhw7pe3BtATDt2BBypBdSOkxr+Q1zh6MCG5ilATB2hEo2KG/pe0XOv2FITKlmeOD/XzwVcEAHbX3zRfM+y6Y8tkCWY3cmK6k1laBM7yLNyAmtQjHnY0r40o1BLAQP3MbReFkB8T+AvS4fd4CJHapA6MXuSl4Ksu0lrl0IqHd6EHiXNCK1xKsfHY/WJeg0f6p2gKfWvS2PElJSUgntM5xUfFYu1V4BzY+Hwo7cwbl7IQe/XfqfyRCFeubTU5tEAopI0kYznweXK33wXhD23DzsnrI1Q9gWgWlRcG3E= nt authority\system@WIN-BS7M1PB2KQE
```

The public key is added in Veeam configuration step to the `notes` user on your Veeam server.  
Once the public key is added to the `authorized_keys` file on the Veeam server, the SSH connection is verified with the same command window.  


## Veeam Backup and Replication server configuration

### Copy configuration and script files

Copy the configuration files from the `veeam_server` directory to `c:\dominobackup` directory.

The directory contains the following files

- PowerShell script to search and mount Veeam Restore Points (separate sub directories)
- JSON configuration file
- pre-freeze and post-thaw scripts for Linux

### Setup OpenSSH server

The integration uses a SSH connection between the Domino an the Veeam server.  
The following documentation describes the setup setups for a basic OpenSSH server configuration to allow SSH key authentication.  
Consult your system administrator for further configurations steps required in your environment.

The minimum required version for the OpenSSH server is **OpenSSH_for_Windows_8.1p1, LibreSSL 3.0.2** (first included in Windows 2022).  
The OpensSSH server was first shipped with Windows 2019, but needs to be updated at least to version 8.1 manually (Windows updated does not update OpenSSH).  

In general it is recommended to use the latest stable version provided by Microsoft in their official GitHub repository.  

- Download and install via MSI installer from [OpenSSH PowerShell release page](https://github.com/PowerShell/Win32-OpenSSH/releases).  
- Example file name: **OpenSSH-Win64-v8.9.1.0.msi**
- Verify your are running at least version **OpenSSH 8.1** by running `sshd -V` and `sshd -?` (there is no official option but an invalid option prints help including the version).

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

The following information is important for setting up the SSH user access:

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


### Create a local user "notes" to be used for Domino server requests over SSH

Create a local administrator account `notes` and log in with the new user.

### Additional Info: PowerShell operations for command-line configuration

To create an user account on command line the following commands might be helpful.

```
New-LocalUser -Name notes -Description "Notes Veeam integration user"
Add-LocalGroupMember -Group Administrators -Member "notes"
Get-LocalGroupMember -Group "Administrators"
```

Run the following command as user to create home dir. The home directory is important to add the `.ssh` directory for the `authorized_keys` file later.

```
runas /user:notes "cmd.exe /c quit"
```

### Add account to OpenSSH configuration on Veeam server

Switch to the user's home and create a new directory for SSH `.ssh`

```
  cd /users/notes
  mkdir .ssh
```

Create the file `C:\Users\notes\.ssh\authorized_keys` and add a line with the command and the public key of the `notes` user you created earlier.

The line also needs to contain the PowerShell command to restrict restrict OpenSSH access to the PowerShell script used for integration.

```
command="powershell.exe c:/dominobackup/DominoRestore.ps1" ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCwJnDDLtRLbz4x4n12ticC4vEQLCohFnvihpkiJ6ak1xJDGl3wbNKtyn6yJ3rrZ8xigyGzDH7mFe/0gxTAw9xlR4wPE3BEY7b2ejt9mvxbumNr+UhxlFclgsYO/YNGXd8J+I4eOIpXvu7F5zfPfU0ZAv4b9J+GsSP6UPDeNhToqpm0KnLsgQiCazSmzNYofSgrvRcqST8Cr+TBG7oEnSeoQX1BSyXhw7pe3BtATDt2BBypBdSOkxr+Q1zh6MCG5ilATB2hEo2KG/pe0XOv2FITKlmeOD/XzwVcEAHbX3zRfM+y6Y8tkCWY3cmK6k1laBM7yLNyAmtQjHnY0r40o1BLAQP3MbReFkB8T+AvS4fd4CJHapA6MXuSl4Ksu0lrl0IqHd6EHiXNCK1xKsfHY/WJeg0f6p2gKfWvS2PElJSUgntM5xUfFYu1V4BzY+Hwo7cwbl7IQe/XfqfyRCFeubTU5tEAopI0kYznweXK33wXhD23DzsnrI1Q9gWgWlRcG3E=
```

Note: In case your Windows server does not allow to execute unsinged scripts, either sign the script according to Microsoft documentation or exlicitly run the script bypassing the execution policity. It is not recommended to generally change the policy to allow execution of all unsigned scripts.

To allow a single script to bypass the policy change the invoked command to line smiliar to shown below:

```
command="powershell.exe -noprofile -executionpolicy bypass -file c:/dominobackup/DominoRestore.ps1" ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCwJnDDLtRLbz4x4n12ticC4vEQLCohFnvihpkiJ6ak1xJDGl3wbNKtyn6yJ3rrZ8xigyGzDH7mFe/0gxTAw9xlR4wPE3BEY7b2ejt9mvxbumNr+UhxlFclgsYO/YNGXd8J+I4eOIpXvu7F5zfPfU0ZAv4b9J+GsSP6UPDeNhToqpm0KnLsgQiCazSmzNYofSgrvRcqST8Cr+TBG7oEnSeoQX1BSyXhw7pe3BtATDt2BBypBdSOkxr+Q1zh6MCG5ilATB2hEo2KG/pe0XOv2FITKlmeOD/XzwVcEAHbX3zRfM+y6Y8tkCWY3cmK6k1laBM7yLNyAmtQjHnY0r40o1BLAQP3MbReFkB8T+AvS4fd4CJHapA6MXuSl4Ksu0lrl0IqHd6EHiXNCK1xKsfHY/WJeg0f6p2gKfWvS2PElJSUgntM5xUfFYu1V4BzY+Hwo7cwbl7IQe/XfqfyRCFeubTU5tEAopI0kYznweXK33wXhD23DzsnrI1Q9gWgWlRcG3E=
```

### Add notes user to Veeam as Restore Operator

- In the Veeam Backup and Replication client, open `User and Roles` from the menu in the upper left corner.

- Add the `notes` user and grand access with at least `Veeam Restore Operator` role.

### Create mount admin credential in Veeam configuration

Open `Manage Credentials` in the upper left menu and create a new entry `Linux private key`.

- Enter `veeam-mount` for the user name
- Select the private key file to use
- Add the password if the key has a password/passphrase
- Specify an unique description for the user and specify the name.
- Ensure privilege elevation is selected to allow the Veeam server to use `sudo` for mount operations

For detailed instructions an information check [Veeam Backup & Replication: Linux Private Keys (Identity/Pubkey)](https://helpcenter.veeam.com/docs/backup/hyperv/credentials_manager_linux_pubkey.html)

### Add Domino server to JSON configuration on the Veeam server

Each Domino server requires a configuration entry in the JSON confiugration file to authorize the Domino server to request mount operations.

Specify the followiong information:

`c:/dominobackup/dominobackup.cfg`

The configuration contains the following information:

- IP address
- Veeam admin credential description to find the right credential for mounting
- Operating system (Linux|windows)
- Name of the operating system VM/host (the name used by Veeam to identify the virtual machine)

```
[
  {
    "VmHost"      : "Domino01-Linux",
    "IpAddress"   : "192.168.1.12",
    "AccountName" : "veeam-mount",
    "OS"          : "Linux"
  }

]
```

#### Tip finding VmHost names

Depending on your configuration the `VmHost` can be a different name. You need to make sure the IpAddress matches the name referenced for the Domino instance. In case you are not sure which name to use, open a Powershell prompt on your Veeam server to find backups via `Get-VBRRestorePoint` command. Depending on the size of your environment you might want to narrow down the search. Each backup references the name, leveraged by the PowerShell script mounting the snapshot.

Check the Veeam [Powershell Command reference Get-VBRRestorePoint](https://helpcenter.veeam.com/docs/backup/powershell/get-vbrrestorepoint.html) for details.


### Test veeam-mount user access

To ensure the communication between the Veeam server and the Domino server works as expected, log into the Domino server from the Veeam server using the SSH private key added earlier.

```
ssh veeam-mount@domino.acme.loc -i veeam_private.key
```

### Test server OpenSSH connection from the Domino server

Switch back to your Domino server to test the connection and confirm the public key of the OpenSSH server.

The following command connects to the server and tests the connection to the PowerShell script.

Note: On Windows using the system account, switch back to the existing cmd window with running with the system account.

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
