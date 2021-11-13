#!/bin/sh

# ----------------------------------------------------------------------
# Domino Snapshot Backup Script
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

# Domino data directory
DOMINO_DATA_PATH=/local/notesdata

# Log and trace files
TRACEFILE=/tmp/dominoveeam_trace.log

# --- End Configuration ---


# Internal variables
DOMBACK_STATUS_FILE=$DOMINO_DATA_PATH/dominobackup_snapshot.lck
DOMBACK_TAG_FILE=$DOMINO_DATA_PATH/dominobackup_$7.tag

tracefile()
{
  if [ -z "$TRACEFILE" ]; then return 0; fi
  echo "[$(date '+%F %T')] $@" >> $TRACEFILE
}

echo "[$(date '+%F %T')] --- BACKUP SNAPSHOT START ---"

echo "--- RESTORE DB ---"
echo "PhysicalFileName : $1"
echo "FileName         : $2"
echo "BackupReference  : $3"
echo "BackupNode       : $4"
echo "BackupName       : $5"
echo "BackupMode       : $6"
echo "BackupStartDT    : $7"
echo "BackupTargetDir  : $8"
echo "Status File      : $DOMBACK_STATUS_FILE"
echo "Tag File         : $DOMBACK_TAG_FILE"

SNAPSHOT_STATUS=
if [ -e "$DOMBACK_STATUS_FILE" ]; then
  SNAPSHOT_STATUS=$(head -1 $DOMBACK_STATUS_FILE)
fi

echo "SNAPSHOT_STATUS : $SNAPSHOT_STATUS"

tracefile "STATUS: [$SNAPSHOT_STATUS] [$0]"

if [ "$SNAPSHOT_STATUS" = "REQUESTED" ]; then

  echo "Writing [$7] into [$DOMBACK_TAG_FILE]"
  echo $7 > $DOMBACK_TAG_FILE

  # Make sure all dirty buffers have been written and the file-system contains all data for the snapshot
  sync
  sleep 2

  echo  "------------------------------------------------------"
  ls -l $DOMINO_DATA_PATH/*.tag
  ls -l $DOMINO_DATA_PATH/*.nsf
  echo "------------------------------------------------------"

  echo DOMINO-DONE > $DOMBACK_STATUS_FILE
  echo "[$(date '+%F %T')] NewStatus: DOMINO-DONE"
  echo "Return: PROCESSED - Snapshot successfully started"

  tracefile "NewStatus: DOMINO-DONE"
  tracefile "Return: PROCESSED - Snapshot successfully started"
  exit 0

else

  echo "Return: ERROR - No backup pending"
  tracefile "Return: ERROR - No backup pending"
  exit 1
fi

