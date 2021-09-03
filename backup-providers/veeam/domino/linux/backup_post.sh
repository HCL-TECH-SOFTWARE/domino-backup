#!/bin/sh

# ----------------------------------------------------------------------
# Domino Backup Snapshot Script to finalize the snapshot backup operation
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

# Domino data directory
DOMINO_DATA_PATH=/local/notesdata

# Log file
LOGFILE=/local/backup/log/backup_post.log

# --- End Configuration ---


# Internal variables
DOMBACK_STATUS_FILE=$DOMINO_DATA_PATH/dominobackup_snapshot.lck


logfile()
{
  if [ "$LOGFILE" = "" ]; then return 0; fi
  echo "$@" >> $LOGFILE
}

logfile "--- POST BACKUP ---"
logfile "PhysicalFileName : $1"
logfile "FileName         : $2"
logfile "BackupReference  : $3"
logfile "BackupNode       : $4"
logfile "BackupName       : $5"
logfile "BackupMode       : $6"
logfile "BackupStartDT    : $7"
logfile "BackupTargetDir  : $8"
logfile "RestoreFileName  : $9"

if [ -e "$DOMBACK_STATUS_FILE" ]; then
  rm -f "$DOMBACK_STATUS_FILE"
fi

echo Return: PROCESSED

exit 0
