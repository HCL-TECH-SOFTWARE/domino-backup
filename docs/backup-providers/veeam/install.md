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

### Configuration for first Domino on Linux server

Log into the Domino server as `root` user.

Copy the backup scripts from the `domino/linux` directory to the `/opt/hcl/domino/backup/veeam` directory.

```
mkdir -p /opt/hcl/domino/backup/veeam
cp veeam/domino/linux/* /opt/hcl/domino/backup/veeam
```

Ensure the files can e executed

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

### Configure the restore script

The restore script requires a connection to the Veeam server.  
To ensure proper communications a DNS entry should be in place.  
An IP address would be usually only used in test environments.

Edit the file `/opt/hcl/domino/backup/veeam/restore_db.sh` to bind the restore_db.sh script to your Veeam server.

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

Add `veeam-mount` user to sudo confiugration to allow operations requiring root permissions

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

### Create SSH key for notes user

Login with the `notes` user and run the following command to create a modern EC25519 key.  
The key will be used for SSH connections from Linux to the OpenSSH server installed on the Veeam server.

```
ssh-keygen -t ed25519
```

Confirm the location of the key. The key should not have a passphrase

The result look like the following output:

```
Generating public/private ed25519 key pair.
Enter file in which to save the key (/home/notes/.ssh/id_ed25519):
Created directory '/home/notes/.ssh'.
Enter passphrase (empty for no passphrase):
Your identification has been saved in /home/notes/.ssh/id_ed25519.
Your public key has been saved in /home/notes/.ssh/id_ed25519.pub.
The key fingerprint is:
SHA256:lWsOr0kwhXJEFxcooHl2W+XG9BG18pR425zYka5jT3o notes@jupiter.amce.loc
The key's randomart image is:
+--[ED25519 256]--+
|    .oo oo=.oo.  |
|   o ..o.* o o o.|
|  o + +.o * + =o |
|   o + + o . =++o|
|      + S o  .o+o|
|       o =    .  |
|        . o  + . |
|       . o  . =E |
|        o    ... |
+----[SHA256]-----+
```

Your key file `/home/notes/.ssh/id_ed25519` should look similar to the following line:

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOxdxrII+d10+EmUAIOvbXJm/EFMAorfApm5VZc+GcxK notes@jupiter.amce.loc
```

The public key is located in `/home/notes/.ssh/id_ed25519.pub` and is added in the next step to the `notes` user on your Veeam server.

## Veeam Backup and Replication server configuration

### Copy configuration and script files

Copy the configuration files from the `veeam_server` directory to `c:\dominobackup` directory.

The directory contains the following files

- PowerShell script to search and mount Veeam Restore Points (separate sub directories)
- JSON configuration file
- pre-freeze and post-thaw scripts for Linux

### Setup OpenSSH server

The OpensSSH server is part of Windows 2019. To install the optional component refer to the [OpenSSH official Microsoft documentation](https://docs.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse)

The most convienient option is to install and enable the OpenSSH server using PowerShell as described in the referenced documentation.

After you installed the OpenSSH server make sure the OpenSSH server configuration is updated with the following configuration.

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

Note: If your user is listed in the Windows administrator group, disabled the following default configuration (you can also replace the the whole configuration).

```
# Match Group administrators
#        AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys
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
command="powershell.exe c:/dominobackup/DominoRestore.ps1" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOxdxrII+d10+EmUAIOvbXJm/EFMAorfApm5VZc+GcxK notes@jupiter.amce.loc
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

### Test veeam-mount user access

To ensure the communication between the Veeam server and the Domino server works as expected, log into the Domino server from the Veeam server using the SSH private key added earlier.

```
ssh veeam-mount@domino.acme.loc -i veeam_private.key
```

### Test server OpenSSH connection from the Domino server

Switch back to your Domino server to test the connection and confirm the public key of the OpenSSH server.

The following command connects to the server and tests the connection to the PowerShell script.

```
ssh notes@veeam-server.acme.loc check
```

The first time you connect you are prompted to trust the certificate on the OpenSSL server.

Confirm the following prompt:

```
The authenticity of host 'veeam-server.acme.loc (veeam-server.acme.loc)' can't be established.
ECDSA key fingerprint is SHA256:DepsvLuZPubqRgGr1J6AXu9B4DdtUrrMjRqX7V77IZc.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added 'veeam-server.acme.loc' (ECDSA) to the list of known hosts.

```

After confirming the connection check the output of the command.
The output should show the environment variables and configuration found.
