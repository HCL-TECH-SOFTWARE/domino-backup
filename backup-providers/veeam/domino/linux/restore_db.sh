#!/bin/sh

# ----------------------------------------------------------------------
# Domino Veeam database and *.DELTA file restore script
# ----------------------------------------------------------------------

# Copyright 2021 HCL America, Inc.
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
# ----------------------------------------------------------------------


# --- Begin Configuration ---

# Veeam server ssh connection
VEEAM_SERVER_SSH=notes@192.168.1.1

# Timeout for SSH connection
TIMEOUT=60

# Log file
LOGFILE=/local/backup/log/restore_db.log

# --- End Configuration ---


# Internal variables
SSH_CMD=ssh

# Restore mount path where Veeam mounts restores as a start point to search
VEEAM_RESTORE_BASE_PATH=/tmp


logfile()
{
  if [ -z "$LOGFILE" ]; then return 0; fi
  echo "$@" >> $LOGFILE
}

copy_restore_file()
{
  # Create directory if not present
  local DIRNAME=$(dirname $2)


  if [ ! -e "$1" ]; then
    echo " Source database not found [$1] -- Cannot copy database" 
    return 0
  fi

  if [ ! -e "$DIRNAME" ]; then
    mkdir -p "$DIRNAME"
  fi

  cp "$1" "$2"
}


TARGET=$9
FILE_EXT=$(echo $9 | rev | cut -d. -s -f 1 | rev)

# Unique tag used to verify/identify the backup when mounted
DOMBACK_TAG_FILE=dominobackup_$7.tag

logfile "[$(date '+%F %T')] --- RESTORE DB ---"
logfile "PhysicalFileName : $1"
logfile "FileName         : $2"
logfile "BackupReference  : $3"
logfile "BackupNode       : $4"
logfile "BackupName       : $5"
logfile "BackupMode       : $6"
logfile "BackupStartDT    : $7"
logfile "BackupTargetDir  : $8"
logfile "RestoreFileName  : $9"
logfile "FileExtension    : $FILE_EXT"

# Delta files are restored from a different location

if [ "$FILE_EXT" = ".DELTA" ]; then
  logfile "Found DELTA Extension"

  set SOURCE=$8/$4/$6/$7/$2

  if [ -n "$SOURCE" ]; then
    logfile "copy [$SOURCE] [$TARGET]"
    copy_restore_file "$SOURCE" "$TARGET"
  fi

else

  # Ensure the restore request always uses a .DAD extension
  if [ "$FILE_EXT" = ".DAD" ]; then
    logfile "Already has .DAD extension"
  else
    logfile "Appending missing .DAD extension"
    TARGET=$TARGET.DAD
  fi

  logfile "Mouting snaphot"
  timeout $TIMEOUT $SSH_CMD $VEEAM_SERVER_SSH mount $7 >> $LOGFILE 2>&1

  # Search mounted directories for backup tag file to verify the right mount and get the Domino data directory
  FOUND_FILE_PATH=
  FOUND_NOTESDATA=

  FOUND_FILE_PATH=$(find $VEEAM_RESTORE_BASE_PATH -name "$DOMBACK_TAG_FILE" | head -1 2>/dev/null)

  if [ -n "$FOUND_FILE_PATH" ]; then
    FOUND_NOTESDATA=$(dirname $FOUND_FILE_PATH)
    SOURCE=$FOUND_NOTESDATA/$2
  fi

  logfile "DOMBACK_TAG_FILE: [$DOMBACK_TAG_FILE]"
  logfile "FOUND_FILE_PATH : [$FOUND_FILE_PATH]"
  logfile "FOUND_NOTESDATA : [$FOUND_NOTESDATA]"
  logfile "SOURCE          : [$SOURCE]"

  if [ -n "$SOURCE" ]; then
    logfile "copy [$SOURCE] [$TARGET]"
    copy_restore_file "$SOURCE" "$TARGET"
  fi

  logfile "Unmounting snaphot"
  timeout $TIMEOUT $SSH_CMD $VEEAM_SERVER_SSH unmount >> $LOGFILE 2>&1

fi

# Log additional fields with same alignment
logfile "SOURCE : [$SOURCE]"
logfile "TARGET : [$TARGET]"
logfile
logfile "[$(date '+%F %T')] Restore operation completed"
logfile

if [ -e "$TARGET" ]; then
  echo "Return: PROCESSED ($TARGET)"
  exit 0
fi

echo "Return: ERROR - Cannot copy file"
exit 1
