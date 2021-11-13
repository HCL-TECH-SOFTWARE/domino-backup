#!/bin/sh

# ----------------------------------------------------------------------
# Domino Veeam database and *.DELTA file restore script
# Last updated: 21.10.2021
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

# --- End Configuration ---


# Internal variables
SSH_CMD=ssh

# Restore mount path where Veeam mounts restores as a start point to search
VEEAM_RESTORE_BASE_PATH=/tmp


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

echo "[$(date '+%F %T')] --- RESTORE DB ---"
echo "PhysicalFileName : $1"
echo "FileName         : $2"
echo "BackupReference  : $3"
echo "BackupNode       : $4"
echo "BackupName       : $5"
echo "BackupMode       : $6"
echo "BackupStartDT    : $7"
echo "BackupTargetDir  : $8"
echo "RestoreFileName  : $9"
echo "FileExtension    : $FILE_EXT"

# Delta files are restored from a different location

if [ "$FILE_EXT" = ".DELTA" ]; then
  echo "Found DELTA Extension"

  set SOURCE=$8/$4/$6/$7/$2

  if [ -n "$SOURCE" ]; then
    echo "copy [$SOURCE] [$TARGET]"
    copy_restore_file "$SOURCE" "$TARGET"
  fi

else

  # Ensure the restore request always uses a .DAD extension
  if [ "$FILE_EXT" = ".DAD" ]; then
    echo "Already has .DAD extension"
  else
    echo "Appending missing .DAD extension"
    TARGET=$TARGET.DAD
  fi

  # Search first in already mounted restores
  FOUND_FILE_PATH=
  FOUND_NOTESDATA=

  FOUND_FILE_PATH=$(find $VEEAM_RESTORE_BASE_PATH -name "$DOMBACK_TAG_FILE" | head -1 2>/dev/null)

  if [ -n "$FOUND_FILE_PATH" ]; then
    FOUND_NOTESDATA=$(dirname $FOUND_FILE_PATH)
    SOURCE=$FOUND_NOTESDATA/$2
  fi


  # If not found mount a backup
  if [ -z "$FOUND_FILE_PATH" ]; then

    echo "Mouting snaphot"
    timeout $TIMEOUT $SSH_CMD $VEEAM_SERVER_SSH mount $7 2>&1

    # Search mounted directories for backup tag file to verify the right mount and get the Domino data directory
    FOUND_FILE_PATH=
    FOUND_NOTESDATA=

    FOUND_FILE_PATH=$(find $VEEAM_RESTORE_BASE_PATH -name "$DOMBACK_TAG_FILE" | head -1 2>/dev/null)

    if [ -n "$FOUND_FILE_PATH" ]; then
      FOUND_NOTESDATA=$(dirname $FOUND_FILE_PATH)
      SOURCE=$FOUND_NOTESDATA/$2
    fi
  fi

  echo
  echo "DOMBACK_TAG_FILE : [$DOMBACK_TAG_FILE]"
  echo "FOUND_FILE_PATH  : [$FOUND_FILE_PATH]"
  echo "FOUND_NOTESDATA  : [$FOUND_NOTESDATA]"
  echo "SOURCE           : [$SOURCE]"
  echo "TARGET           : [$TARGET]"

  if [ -n "$SOURCE" ]; then
    echo "COPY             : [$SOURCE] [$TARGET]"
    copy_restore_file "$SOURCE" "$TARGET"
  fi

  # echo "Unmounting snaphot"
  # timeout $TIMEOUT $SSH_CMD $VEEAM_SERVER_SSH unmount 2>&1

fi

# Log additional fields with same alignment
echo
echo "[$(date '+%F %T')] Restore operation completed"
echo

if [ -e "$TARGET" ]; then
  echo "Return: PROCESSED ($TARGET)"
  exit 0
fi

echo "Return: ERROR - Cannot copy file"
exit 1
